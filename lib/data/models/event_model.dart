import 'package:cloud_firestore/cloud_firestore.dart';

class EventModel {
  const EventModel({
    required this.id,
    required this.title,
    required this.type,
    required this.eventDate,
    required this.privacy,
    required this.status,
    required this.createdByUid,
    required this.shareCode,
    this.typeOtherLabel,
    this.description,
    this.coverUrl,
    this.coverPath,
    this.coverContentType,
    this.createdAt,
    this.deletedAt,
    this.deletedByUid,
  });

  final String id;

  final String title;
  final String type;
  final String? typeOtherLabel;
  final String? description;

  final DateTime eventDate;

  /// signed_in_only | public
  final String privacy;

  /// open | closed | deleted
  final String status;

  final String createdByUid;
  final String shareCode;

  /// Stored in Firestore so UI can use it everywhere (thumbnail, header, etc.)
  final String? coverUrl;

  /// Storage path so you can replace/delete later.
  final String? coverPath;

  final String? coverContentType;

  final DateTime? createdAt;
  final DateTime? deletedAt;
  final String? deletedByUid;

  factory EventModel.fromMap(String id, Map<String, dynamic> data) {
    final ts = data['eventDate'];
    DateTime eventDate = DateTime.now();
    if (ts is Timestamp) eventDate = ts.toDate();

    DateTime? createdAt;
    final c = data['createdAt'];
    if (c is Timestamp) createdAt = c.toDate();

    DateTime? deletedAt;
    final d = data['deletedAt'];
    if (d is Timestamp) deletedAt = d.toDate();

    return EventModel(
      id: id,
      title: (data['title'] ?? '') as String,
      type: (data['type'] ?? '') as String,
      typeOtherLabel: data['typeOtherLabel'] as String?,
      description: data['description'] as String?,
      eventDate: eventDate,
      privacy: (data['privacy'] ?? 'signed_in_only') as String,
      status: (data['status'] ?? 'open') as String,
      createdByUid: (data['createdByUid'] ?? '') as String,
      shareCode: (data['shareCode'] ?? '') as String,
      coverUrl: data['coverUrl'] as String?,
      coverPath: data['coverPath'] as String?,
      coverContentType: data['coverContentType'] as String?,
      createdAt: createdAt,
      deletedAt: deletedAt,
      deletedByUid: data['deletedByUid'] as String?,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'title': title,
      'type': type,
      'typeOtherLabel': typeOtherLabel,
      'description': description,
      'eventDate': Timestamp.fromDate(eventDate),
      'privacy': privacy,
      'status': status,
      'createdByUid': createdByUid,
      'shareCode': shareCode,
      'coverUrl': coverUrl,
      'coverPath': coverPath,
      'coverContentType': coverContentType,
      'createdAt': createdAt == null ? null : Timestamp.fromDate(createdAt!),
      'deletedAt': deletedAt == null ? null : Timestamp.fromDate(deletedAt!),
      'deletedByUid': deletedByUid,
    };
  }
}
