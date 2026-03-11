import 'package:cloud_firestore/cloud_firestore.dart';

class UploadModel {
  final String id;
  final String eventId;
  final String uploaderUid;
  final String storagePath;
  final String downloadUrl;
  final int durationSec;
  final String status; // uploaded | processing | failed
  final Timestamp createdAt;

  UploadModel({
    required this.id,
    required this.eventId,
    required this.uploaderUid,
    required this.storagePath,
    required this.downloadUrl,
    required this.durationSec,
    required this.status,
    required this.createdAt,
  });

  factory UploadModel.fromMap(String id, Map<String, dynamic> map) {
    return UploadModel(
      id: id,
      eventId: (map['eventId'] ?? '') as String,
      uploaderUid: (map['uploaderUid'] ?? '') as String,
      storagePath: (map['storagePath'] ?? '') as String,
      downloadUrl: (map['downloadUrl'] ?? '') as String,
      durationSec: (map['durationSec'] ?? 0) as int,
      status: (map['status'] ?? 'uploaded') as String,
      createdAt: (map['createdAt'] as Timestamp?) ?? Timestamp.now(),
    );
  }
}
