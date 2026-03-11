import 'package:cloud_firestore/cloud_firestore.dart';

class UserRepository {
  UserRepository({FirebaseFirestore? firestore})
      : _db = firestore ?? FirebaseFirestore.instance;

  final FirebaseFirestore _db;

  DocumentReference<Map<String, dynamic>> userRef(String uid) =>
      _db.collection('users').doc(uid);

  CollectionReference<Map<String, dynamic>> joinedEventsRef(String uid) =>
      _db.collection('users').doc(uid).collection('joinedEvents');

  /// Event created → stats.eventsCreated += 1
  Future<void> incrementEventsCreated(String uid) async {
    await userRef(uid).set(
      {'stats.eventsCreated': FieldValue.increment(1)},
      SetOptions(merge: true),
    );
  }

  /// User submits any message → stats.messagesSent += 1
  Future<void> incrementMessagesSent(String uid) async {
    await userRef(uid).set(
      {'stats.messagesSent': FieldValue.increment(1)},
      SetOptions(merge: true),
    );
  }

  /// Host receives a message → stats.messagesReceived += 1
  Future<void> incrementMessagesReceived(String hostUid) async {
    await userRef(hostUid).set(
      {'stats.messagesReceived': FieldValue.increment(1)},
      SetOptions(merge: true),
    );
  }

  /// User contributes to event → stats.eventsJoined += 1 (only first time per event)
  ///
  /// Creates marker doc: users/{uid}/joinedEvents/{eventId}
  Future<void> markJoinedEventOnce({
    required String uid,
    required String eventId,
  }) async {
    final marker = joinedEventsRef(uid).doc(eventId);

    await _db.runTransaction((tx) async {
      final snap = await tx.get(marker);
      if (snap.exists) return;

      tx.set(marker, {
        'eventId': eventId,
        'createdAt': FieldValue.serverTimestamp(),
      });

      tx.set(
        userRef(uid),
        {'stats.eventsJoined': FieldValue.increment(1)},
        SetOptions(merge: true),
      );
    });
  }
}