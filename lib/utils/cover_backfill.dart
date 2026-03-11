import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/foundation.dart';

class CoverBackfill {
  static final Set<String> _inFlight = <String>{};

  static Future<void> ensureCoverUrl({
    required String eventId,
    required String coverUrl,
    required String coverPath,
  }) async {
    final url = coverUrl.trim();
    final path = coverPath.trim();

    if (url.isNotEmpty) return;
    if (path.isEmpty) return;
    if (_inFlight.contains(eventId)) return;

    _inFlight.add(eventId);

    try {
      final dl = await FirebaseStorage.instance.ref(path).getDownloadURL();
      debugPrint('✅ backfill coverUrl for $eventId');

      await FirebaseFirestore.instance.collection('events').doc(eventId).set(
        {'coverUrl': dl},
        SetOptions(merge: true),
      );
    } catch (e) {
      debugPrint('❌ backfill failed for $eventId path=$path error=$e');
    } finally {
      _inFlight.remove(eventId);
    }
  }
}