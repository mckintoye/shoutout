import { onCall, HttpsError } from "firebase-functions/v2/https";
import { setGlobalOptions } from "firebase-functions/v2/options";
import * as admin from "firebase-admin";

admin.initializeApp();

// Optional: keep costs predictable in beta.
setGlobalOptions({ region: "us-central1" });

type UploadDoc = {
  uploaderUid?: string;
  storagePath?: string; // strongly preferred
  downloadUrl?: string; // fallback only
};

function chunk<T>(arr: T[], size: number): T[][] {
  const out: T[][] = [];
  for (let i = 0; i < arr.length; i += size) out.push(arr.slice(i, i + size));
  return out;
}

export const deleteEventCascade = onCall(async (request) => {
  const auth = request.auth;
  if (!auth?.uid) throw new HttpsError("unauthenticated", "Not signed in.");

  const eventId = String((request.data as any)?.eventId ?? "").trim();
  if (!eventId) throw new HttpsError("invalid-argument", "eventId is required.");

  const db = admin.firestore();
  const bucket = admin.storage().bucket();

  const eventRef = db.collection("events").doc(eventId);
  const eventSnap = await eventRef.get();

  if (!eventSnap.exists) {
    // Idempotent: deleting an already-deleted event should not blow up.
    return { ok: true, alreadyMissing: true };
  }

  const eventData = eventSnap.data() || {};
  const createdByUid = String(eventData["createdByUid"] ?? "");
  if (createdByUid !== auth.uid) {
    throw new HttpsError("permission-denied", "Only the host can delete this event.");
  }

  // 1) Collect uploads under /events/{eventId}/uploads
  const uploadsSnap = await eventRef.collection("uploads").get();

  const storagePathsToDelete: string[] = [];
  const userUploadDocRefsToDelete: admin.firestore.DocumentReference[] = [];
  const userEventMarkerRefsToDelete: admin.firestore.DocumentReference[] = [];
  const eventUploadRefsToDelete: admin.firestore.DocumentReference[] = [];

  uploadsSnap.docs.forEach((d) => {
    eventUploadRefsToDelete.push(d.ref);

    const u = d.data() as UploadDoc;
    const uploaderUid = u.uploaderUid ? String(u.uploaderUid) : "";

    if (u.storagePath) storagePathsToDelete.push(String(u.storagePath));

    // Mirror doc under /users/{uid}/uploads/{uploadId} (if you store mirrors)
    if (uploaderUid) {
      userUploadDocRefsToDelete.push(
        db.collection("users").doc(uploaderUid).collection("uploads").doc(d.id)
      );

      // Joined/completed marker under /users/{uid}/events/{eventId}
      userEventMarkerRefsToDelete.push(
        db.collection("users").doc(uploaderUid).collection("events").doc(eventId)
      );
    }
  });

  // 2) Members subcollection
  const membersSnap = await eventRef.collection("members").get();
  const memberRefsToDelete = membersSnap.docs.map((d) => d.ref);

  // 3) Also delete host marker under /users/{hostUid}/events/{eventId} (if you create one)
  userEventMarkerRefsToDelete.push(
    db.collection("users").doc(createdByUid).collection("events").doc(eventId)
  );

  // 4) Delete Storage objects (best-effort; don’t fail the whole delete if a file is missing)
  // This assumes uploads store `storagePath`.
  // 4) Delete Storage objects.
  // Prefer explicit paths (newer uploads), but also delete by prefix to catch older uploads
  // that may not have storagePath stored in Firestore.
  for (const p of storagePathsToDelete) {
    try {
      await bucket.file(p).delete({ ignoreNotFound: true });
    } catch (e) {
      console.warn("Storage delete failed for", p, e);
    }
  }

  // Delete all event upload files (covers legacy docs missing storagePath).
  try {
    await bucket.deleteFiles({ prefix: `events/${eventId}/uploads/` });
  } catch (e) {
    console.warn("Storage prefix delete failed for events uploads", eventId, e);
  }

  // Optional: delete cover (if you use this path in UploadRepository.uploadEventCover)
  try {
    await bucket.file(`event_covers/${eventId}.jpg`).delete({ ignoreNotFound: true });
  } catch (e) {
    console.warn("Cover delete failed", eventId, e);
  }

  // 5) Firestore deletes in batches (limit 500 ops per batch)
  const allRefs: admin.firestore.DocumentReference[] = [
    ...eventUploadRefsToDelete,
    ...memberRefsToDelete,
    ...userUploadDocRefsToDelete,
    ...userEventMarkerRefsToDelete,
  ];

  const chunks = chunk(allRefs, 450); // safety margin under 500
  for (const group of chunks) {
    const batch = db.batch();
    group.forEach((ref) => batch.delete(ref));
    await batch.commit();
  }

  // 6) Finally delete the event doc
  await eventRef.delete();

  return {
    ok: true,
    eventId,
    deletedUploads: uploadsSnap.size,
    deletedMembers: membersSnap.size,
    deletedStorageObjects: storagePathsToDelete.length,
  };
});