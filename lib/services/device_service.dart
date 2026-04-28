import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

/// Device types Evora supports
enum DeviceType { band, scale, mask }

class ConnectedDevice {
  final String id;
  final DeviceType type;
  final String name;
  final DateTime connectedAt;
  final DateTime? lastSyncAt;
  final Map<String, dynamic> metadata;

  const ConnectedDevice({
    required this.id,
    required this.type,
    required this.name,
    required this.connectedAt,
    this.lastSyncAt,
    this.metadata = const {},
  });

  factory ConnectedDevice.fromMap(Map<String, dynamic> m) => ConnectedDevice(
    id: m['id'] ?? '',
    type: DeviceType.values.firstWhere(
      (e) => e.name == m['type'],
      orElse: () => DeviceType.band,
    ),
    name: m['name'] ?? 'Evora Device',
    connectedAt: (m['connectedAt'] as dynamic)?.toDate() ?? DateTime.now(),
    lastSyncAt: (m['lastSyncAt'] as dynamic)?.toDate(),
    metadata: Map<String, dynamic>.from(m['metadata'] ?? {}),
  );

  Map<String, dynamic> toMap() => {
    'id': id,
    'type': type.name,
    'name': name,
    'connectedAt': connectedAt,
    'lastSyncAt': lastSyncAt,
    'metadata': metadata,
  };
}

class DeviceService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  String? get _uid => _auth.currentUser?.uid;

  /// Stream of connected devices for current user
  Stream<List<ConnectedDevice>> devicesStream() {
    if (_uid == null) return const Stream.empty();
    return _db
        .collection('users')
        .doc(_uid)
        .collection('devices')
        .snapshots()
        .map((snap) => snap.docs
            .map((d) => ConnectedDevice.fromMap(d.data()))
            .toList());
  }

  /// Save a newly paired device
  Future<void> saveDevice(ConnectedDevice device) async {
    if (_uid == null) return;
    await _db
        .collection('users')
        .doc(_uid)
        .collection('devices')
        .doc(device.id)
        .set(device.toMap());
  }

  /// Update last sync timestamp
  Future<void> updateLastSync(String deviceId) async {
    if (_uid == null) return;
    await _db
        .collection('users')
        .doc(_uid)
        .collection('devices')
        .doc(deviceId)
        .update({'lastSyncAt': FieldValue.serverTimestamp()});
  }

  /// Remove a device
  Future<void> removeDevice(String deviceId) async {
    if (_uid == null) return;
    await _db
        .collection('users')
        .doc(_uid)
        .collection('devices')
        .doc(deviceId)
        .delete();
  }
}
