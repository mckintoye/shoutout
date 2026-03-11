import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';

/// Firestore layout:
/// - /events/{eventId}/uploads/{uploadId}
/// - /users/{uid}/uploads/{uploadId}
/// - /users/{uid}/events/{eventId}  (join doc: hasUploaded, lastUploadAt, uploadCount)
class UploadRepository {
  UploadRepository({
    FirebaseFirestore? firestore,
    FirebaseStorage? storage,
  })  : _firestore = firestore ?? FirebaseFirestore.instance,
        _storage = storage ?? FirebaseStorage.instance;

  final FirebaseFirestore _firestore;
  final FirebaseStorage _storage;

  static const int maxUploadsPerEvent = 5;
  static const int maxVideoSeconds = 60;

  Future<String> uploadEventCover({
    required String eventId,
    required File file,
  }) async {
    final ref = _storage.ref().child('event_covers/$eventId.jpg');
    await ref.putFile(file);
    return ref.getDownloadURL();
  }

  /// UI should call this.
  Future<String> createUpload({
    required String eventId,
    required String userId,
    required File file,
    required int durationSec,
    required String source, // "camera" | "library"
  }) async {
    if (durationSec <= 0) throw Exception('Invalid video duration.');
    if (durationSec > maxVideoSeconds) {
      throw Exception('Video must be $maxVideoSeconds seconds or less.');
    }

    // Join doc used for Joined Events + max-5 enforcement.
    final joinRef = _firestore
        .collection('users')
        .doc(userId)
        .collection('events')
        .doc(eventId);

    final joinSnap = await joinRef.get();
    final currentCount = (joinSnap.data()?['uploadCount'] as int?) ?? 0;
    if (currentCount >= maxUploadsPerEvent) {
      throw Exception('You can only submit up to $maxUploadsPerEvent messages for this event.');
    }

    final now = DateTime.now();
    final uploadId = _firestore.collection('_tmp').doc().id;

    final storagePath = 'events/$eventId/uploads/$userId/$uploadId.mp4';
    final storageRef = _storage.ref().child(storagePath);

    await storageRef.putFile(file);
    final downloadUrl = await storageRef.getDownloadURL();

    final data = <String, dynamic>{
      'uploadId': uploadId,
      'eventId': eventId,

      // ✅ REQUIRED by your Firestore rules
      'uploaderUid': userId,

      // keep for backward compatibility (some UI may still read this)
      'userId': userId,

      'createdAt': Timestamp.fromDate(now),
      'durationSec': durationSec,
      'source': source,
      'status': 'uploaded',
      'downloadUrl': downloadUrl,
      'storagePath': storagePath,
    };

    final batch = _firestore.batch();

    final eventUploadRef =
    _firestore.collection('events').doc(eventId).collection('uploads').doc(uploadId);
    final userUploadRef =
    _firestore.collection('users').doc(userId).collection('uploads').doc(uploadId);

    batch.set(eventUploadRef, data, SetOptions(merge: true));
    batch.set(userUploadRef, data, SetOptions(merge: true));

    batch.set(joinRef, <String, dynamic>{
      'eventId': eventId,
      'hasUploaded': true,
      'lastUploadAt': Timestamp.fromDate(now),
    }, SetOptions(merge: true));

    await batch.commit();

    // Increment count after commit (MVP-safe).
    await joinRef.set(<String, dynamic>{
      'uploadCount': FieldValue.increment(1),
      'hasUploaded': true,
      'lastUploadAt': Timestamp.fromDate(now),
    }, SetOptions(merge: true));

    return uploadId;
  }

  /// Deletes everywhere + safe storagePath handling (fixes your Null -> String crash).
  Future<void> deleteUpload({
    required String eventId,
    required String uploadId,
    required String userId,
    String? storagePath,
  }) async {
    final path = (storagePath ?? '').trim();
    if (path.isNotEmpty) {
      try {
        await _storage.ref().child(path).delete();
      } catch (_) {
        // ignore missing storage file
      }
    }

    final batch = _firestore.batch();

    final eventUploadRef =
    _firestore.collection('events').doc(eventId).collection('uploads').doc(uploadId);
    final userUploadRef =
    _firestore.collection('users').doc(userId).collection('uploads').doc(uploadId);

    batch.delete(eventUploadRef);
    batch.delete(userUploadRef);

    await batch.commit();

    final joinRef = _firestore
        .collection('users')
        .doc(userId)
        .collection('events')
        .doc(eventId);

    await _firestore.runTransaction((tx) async {
      final snap = await tx.get(joinRef);
      final count = (snap.data()?['uploadCount'] as int?) ?? 0;
      final next = count > 0 ? count - 1 : 0;

      tx.set(joinRef, <String, dynamic>{
        'uploadCount': next,
        'hasUploaded': next > 0,
        'lastUploadAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
    });
  }
}