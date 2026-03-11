import 'package:cloud_firestore/cloud_firestore.dart';

class UserStats {
  final int eventsCreated;
  final int eventsJoined;
  final int messagesSent;
  final int messagesReceived;

  const UserStats({
    this.eventsCreated = 0,
    this.eventsJoined = 0,
    this.messagesSent = 0,
    this.messagesReceived = 0,
  });

  factory UserStats.fromMap(Map<String, dynamic>? map) {
    final m = map ?? const <String, dynamic>{};
    int _i(dynamic v) => (v is num) ? v.toInt() : 0;

    return UserStats(
      eventsCreated: _i(m['eventsCreated']),
      eventsJoined: _i(m['eventsJoined']),
      messagesSent: _i(m['messagesSent']),
      messagesReceived: _i(m['messagesReceived']),
    );
  }

  Map<String, dynamic> toMap() => {
    'eventsCreated': eventsCreated,
    'eventsJoined': eventsJoined,
    'messagesSent': messagesSent,
    'messagesReceived': messagesReceived,
  };

  UserStats copyWith({
    int? eventsCreated,
    int? eventsJoined,
    int? messagesSent,
    int? messagesReceived,
  }) {
    return UserStats(
      eventsCreated: eventsCreated ?? this.eventsCreated,
      eventsJoined: eventsJoined ?? this.eventsJoined,
      messagesSent: messagesSent ?? this.messagesSent,
      messagesReceived: messagesReceived ?? this.messagesReceived,
    );
  }
}

class UserModel {
  final String uid;
  final String email;
  final String displayName;
  final String firstName;
  final String lastName;
  final String photoUrl;
  final bool notificationsEnabled;
  final List<String> providerIds;
  final Timestamp? createdAt;
  final Timestamp? lastActiveAt;
  final UserStats stats;

  const UserModel({
    required this.uid,
    required this.email,
    this.displayName = '',
    this.firstName = '',
    this.lastName = '',
    this.photoUrl = '',
    this.notificationsEnabled = true,
    this.providerIds = const [],
    this.createdAt,
    this.lastActiveAt,
    this.stats = const UserStats(),
  });

  factory UserModel.fromDoc(
      String uid,
      Map<String, dynamic>? data,
      ) {
    final d = data ?? const <String, dynamic>{};

    String _s(dynamic v) => (v is String) ? v : '';
    bool _b(dynamic v) => (v is bool) ? v : true;

    final providers = (d['providerIds'] is List)
        ? (d['providerIds'] as List).whereType<String>().toList()
        : <String>[];

    return UserModel(
      uid: uid,
      email: _s(d['email']),
      displayName: _s(d['displayName']),
      firstName: _s(d['firstName']),
      lastName: _s(d['lastName']),
      photoUrl: _s(d['photoUrl']),
      notificationsEnabled: _b(d['notificationsEnabled']),
      providerIds: providers,
      createdAt: d['createdAt'] is Timestamp ? d['createdAt'] as Timestamp : null,
      lastActiveAt: d['lastActiveAt'] is Timestamp ? d['lastActiveAt'] as Timestamp : null,
      stats: UserStats.fromMap(d['stats'] is Map<String, dynamic> ? d['stats'] as Map<String, dynamic> : null),
    );
  }

  Map<String, dynamic> toMap() => {
    'email': email,
    'displayName': displayName,
    'firstName': firstName,
    'lastName': lastName,
    'photoUrl': photoUrl,
    'notificationsEnabled': notificationsEnabled,
    'providerIds': providerIds,
    'createdAt': createdAt,
    'lastActiveAt': lastActiveAt,
    'stats': stats.toMap(),
  };
}