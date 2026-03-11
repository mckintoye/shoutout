import 'dart:typed_data';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';

import 'user_repository.dart';

class EventRepository {
  EventRepository({
    FirebaseFirestore? firestore,
    FirebaseAuth? auth,
    FirebaseStorage? storage,
    FirebaseFunctions? functions,
    UserRepository? userRepo,
  })  : _db = firestore ?? FirebaseFirestore.instance,
        _auth = auth ?? FirebaseAuth.instance,
        _storage = storage ?? FirebaseStorage.instance,
        _functions = functions ?? FirebaseFunctions.instance,
        _userRepo = userRepo ?? UserRepository(firestore: firestore);

  final FirebaseFirestore _db;
  final FirebaseAuth _auth;
  final FirebaseStorage _storage;
  final FirebaseFunctions _functions;
  final UserRepository _userRepo;

  // ---------------------------------------------------------------------------
  // CREATE EVENT (host) — SIMPLE ARCH (NO MIRROR)
  // Writes:
  // 1) /events/{eventId}
  // 2) /events/{eventId}/members/{uid}  (role=host + uid field + cached summary)
  // Also:
  // - increments user stats.eventsCreated
  // ---------------------------------------------------------------------------
  Future<String> createEvent({
    required String title,
    required String type,
    String? typeOtherLabel,
    String? description,
    required DateTime eventDate,
    required String privacy, // signed_in_only | public
    required Uint8List coverBytes,
    required String coverContentType, // image/jpeg | image/png | image/webp
  }) async {
    final user = _auth.currentUser;
    if (user == null) throw Exception('Not signed in');

    final eventRef = _db.collection('events').doc();
    final eventId = eventRef.id;

    final now = FieldValue.serverTimestamp();
    final shareCode = _makeShareCode(title: title, date: eventDate);

    // Upload cover FIRST so canonical always gets coverUrl if create succeeds.
    final ext = _extFromContentType(coverContentType);
    final coverPath = 'events/$eventId/cover/cover.$ext';

    final snap = await _storage.ref(coverPath).putData(
      coverBytes,
      SettableMetadata(contentType: coverContentType),
    );

    final coverUrl = (await snap.ref.getDownloadURL()).trim();
    if (coverUrl.isEmpty) throw Exception('Cover download URL is empty');

    final batch = _db.batch();

    // Canonical event doc
    batch.set(eventRef, {
      'title': title,
      'type': type,
      'typeOtherLabel': typeOtherLabel,
      'description': description,
      'eventDate': Timestamp.fromDate(eventDate),
      'privacy': privacy,
      'status': 'open',
      'createdByUid': user.uid,
      'createdAt': now,
      'shareCode': shareCode,
      'coverUrl': coverUrl,
      'coverPath': coverPath,
      'coverContentType': coverContentType,
      'deletedAt': null,
      'deletedByUid': null,
    });

    // Membership doc (HOST)
    final memberRef = eventRef.collection('members').doc(user.uid);
    batch.set(
      memberRef,
      {
        'uid': user.uid,
        'role': 'host',
        'joinedAt': now,
        'hidden': false,

        // Cached summary for joined list (no mirrors)
        'eventId': eventId,
        'eventTitle': title,
        'eventDate': Timestamp.fromDate(eventDate),
        'eventCoverUrl': coverUrl,
        'eventCoverPath': coverPath,
        'eventCoverContentType': coverContentType,
        'eventStatus': 'open',
        'eventPrivacy': privacy,
        'eventShareCode': shareCode,
        'eventCreatedAt': now,
      },
      SetOptions(merge: true),
    );

    await batch.commit();

    // ✅ Stats: event created
    await _userRepo.incrementEventsCreated(user.uid);

    return eventId;
  }

  // ---------------------------------------------------------------------------
  // JOIN EVENT (member)
  // Writes /events/{eventId}/members/{uid} with uid field + cached summary
  // NOTE: This is "membership", NOT "contributed". Joined stats are incremented
  // only when they upload a message (handled in UploadRepository).
  // ---------------------------------------------------------------------------
  Future<void> joinEventById(String eventId) async {
    final user = _auth.currentUser;
    if (user == null) throw Exception('Not signed in');

    final eventRef = _db.collection('events').doc(eventId);
    final eventSnap = await eventRef.get();
    if (!eventSnap.exists) throw Exception('Event not found');

    final e = eventSnap.data() ?? {};
    if ((e['status'] ?? '') == 'deleted') throw Exception('Event deleted');

    final now = FieldValue.serverTimestamp();

    final memberRef = eventRef.collection('members').doc(user.uid);
    await memberRef.set(
      {
        'uid': user.uid,
        'role': 'member',
        'joinedAt': now,
        'hidden': false,

        // Cached summary
        'eventId': eventId,
        'eventTitle': (e['title'] ?? 'Untitled').toString(),
        'eventDate': e['eventDate'],
        'eventCoverUrl': (e['coverUrl'] ?? '').toString(),
        'eventCoverPath': (e['coverPath'] ?? '').toString(),
        'eventCoverContentType': (e['coverContentType'] ?? '').toString(),
        'eventStatus': (e['status'] ?? 'open').toString(),
        'eventPrivacy': (e['privacy'] ?? 'signed_in_only').toString(),
        'eventShareCode': (e['shareCode'] ?? '').toString(),
        'eventCreatedAt': e['createdAt'] ?? now,
      },
      SetOptions(merge: true),
    );
  }

  Future<void> hideEventForMe(String eventId) async {
    final user = _auth.currentUser;
    if (user == null) throw Exception('Not signed in');
    final ref = _db.collection('events').doc(eventId).collection('members').doc(user.uid);
    await ref.set({'hidden': true}, SetOptions(merge: true));
  }

  Future<void> unhideEventForMe(String eventId) async {
    final user = _auth.currentUser;
    if (user == null) throw Exception('Not signed in');
    final ref = _db.collection('events').doc(eventId).collection('members').doc(user.uid);
    await ref.set({'hidden': false}, SetOptions(merge: true));
  }

  Future<void> deleteEventAsHost(String eventId) async {
    final user = _auth.currentUser;
    if (user == null) throw Exception('Not signed in');

    // Cloud Function performs:
    // - host verification (createdByUid == auth.uid)
    // - delete /events/{eventId}/uploads + storage objects
    // - delete /events/{eventId}/members
    // - delete /users/{uid}/uploads/{uploadId} mirrors
    // - delete /users/{uid}/events/{eventId} join markers
    // - delete /events/{eventId} doc
    final callable = _functions.httpsCallable('deleteEventCascade');
    await callable.call(<String, dynamic>{'eventId': eventId});
  }

  Future<String?> resolveEventIdFromShareCode(String code) async {
    final cleaned = code.trim();
    if (cleaned.isEmpty) return null;

    final snap = await _db
        .collection('events')
        .where('shareCode', isEqualTo: cleaned)
        .limit(1)
        .get();

    if (snap.docs.isEmpty) return null;

    final doc = snap.docs.first;
    final data = doc.data();
    if ((data['status'] ?? '') == 'deleted') return null;
    return doc.id;
  }

  String _extFromContentType(String ct) {
    final c = ct.toLowerCase().trim();
    if (c.contains('png')) return 'png';
    if (c.contains('webp')) return 'webp';
    return 'jpg';
  }

  String _makeShareCode({required String title, required DateTime date}) {
    String slug(String s) {
      final x = s.trim().toLowerCase();
      final cleaned = x.replaceAll(RegExp(r'[^a-z0-9\s-]'), '');
      final dashed = cleaned.replaceAll(RegExp(r'\s+'), '-');
      return dashed.replaceAll(RegExp(r'-+'), '-');
    }

    const months = [
      'Jan','Feb','Mar','Apr','May','Jun','Jul','Aug','Sep','Oct','Nov','Dec'
    ];
    final m = months[date.month - 1];
    final d = date.day.toString().padLeft(2, '0');
    final y = date.year.toString();

    return 'shoutout/${slug(title)}-$m-$d-$y';
  }
}