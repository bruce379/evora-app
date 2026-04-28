import 'package:cloud_firestore/cloud_firestore.dart';

enum UserSource { app, portal, unknown }

class EvoraUser {
  final String uid;
  final String email;
  final String? displayName;
  final String? photoUrl;
  final UserSource source;
  final String platform; // ios / android / web
  final DateTime registeredAt;
  final DateTime? lastLoginAt;
  final List<String> connectedDevices; // device IDs

  const EvoraUser({
    required this.uid,
    required this.email,
    this.displayName,
    this.photoUrl,
    required this.source,
    required this.platform,
    required this.registeredAt,
    this.lastLoginAt,
    this.connectedDevices = const [],
  });

  factory EvoraUser.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return EvoraUser(
      uid: doc.id,
      email: data['email'] ?? '',
      displayName: data['displayName'],
      photoUrl: data['photoUrl'],
      source: _parseSource(data['source']),
      platform: data['platform'] ?? 'unknown',
      registeredAt: (data['registeredAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      lastLoginAt: (data['lastLoginAt'] as Timestamp?)?.toDate(),
      connectedDevices: List<String>.from(data['connectedDevices'] ?? []),
    );
  }

  Map<String, dynamic> toFirestore() => {
    'email': email,
    'displayName': displayName,
    'photoUrl': photoUrl,
    'source': source.name,         // "app" | "portal" | "unknown"
    'platform': platform,          // "ios" | "android" | "web"
    'registeredAt': Timestamp.fromDate(registeredAt),
    'lastLoginAt': lastLoginAt != null ? Timestamp.fromDate(lastLoginAt!) : null,
    'connectedDevices': connectedDevices,
  };

  static UserSource _parseSource(String? s) {
    switch (s) {
      case 'app': return UserSource.app;
      case 'portal': return UserSource.portal;
      default: return UserSource.unknown;
    }
  }

  EvoraUser copyWith({
    String? displayName,
    String? photoUrl,
    DateTime? lastLoginAt,
    List<String>? connectedDevices,
  }) => EvoraUser(
    uid: uid,
    email: email,
    displayName: displayName ?? this.displayName,
    photoUrl: photoUrl ?? this.photoUrl,
    source: source,
    platform: platform,
    registeredAt: registeredAt,
    lastLoginAt: lastLoginAt ?? this.lastLoginAt,
    connectedDevices: connectedDevices ?? this.connectedDevices,
  );
}
