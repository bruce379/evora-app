import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
// ignore: avoid_web_libraries_in_flutter
import 'dart:js' as js;
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'health_service.dart';

enum PairStatus { idle, scanning, connected, disconnected, failed, unsupported }

class DevicePairResult {
  final bool success;
  final String message;
  final PairedDevice? device;

  const DevicePairResult({required this.success, required this.message, this.device});
}

class PairedDevice {
  final String id;
  final String name;
  final String type; // "band" | "scale"
  final DateTime pairedAt;
  int? batteryLevel;
  bool isConnected;

  PairedDevice({
    required this.id,
    required this.name,
    required this.type,
    required this.pairedAt,
    this.batteryLevel,
    this.isConnected = true,
  });

  factory PairedDevice.fromJson(Map<String, dynamic> j) => PairedDevice(
    id: j['id'] ?? '',
    name: j['name'] ?? 'Evora Device',
    type: j['type'] ?? 'band',
    pairedAt: DateTime.now(),
    isConnected: j['connected'] ?? false,
  );

  Map<String, dynamic> toMap() => {
    'id': id,
    'name': name,
    'type': type,
    'pairedAt': pairedAt.toIso8601String(),
    'batteryLevel': batteryLevel,
  };
}

class EvoraBluetoothService {
  static final EvoraBluetoothService _instance = EvoraBluetoothService._internal();
  factory EvoraBluetoothService() => _instance;
  EvoraBluetoothService._internal();

  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _db = FirebaseFirestore.instance;
  final HealthService _healthService = HealthService();

  String? get _uid => _auth.currentUser?.uid;

  // Connected devices in memory
  final Map<String, PairedDevice> _connected = {};
  List<PairedDevice> get connectedDevices => _connected.values.toList();

  // Stream controllers for live data
  final _heartRateController = StreamController<int>.broadcast();
  final _weightController = StreamController<double>.broadcast();
  final _statusController = StreamController<String>.broadcast();

  Stream<int> get heartRateStream => _heartRateController.stream;
  Stream<double> get weightStream => _weightController.stream;
  Stream<String> get statusStream => _statusController.stream;

  /// Check if Web Bluetooth is available (Chrome only)
  bool get isSupported {
    if (!kIsWeb) return false;
    try {
      final result = js.context['EvoraBluetooth']?.callMethod('isSupported', []);
      return result == true;
    } catch (_) {
      return false;
    }
  }

  bool get isChromeWeb {
    if (!kIsWeb) return false;
    try {
      final userAgent = js.context['navigator']?['userAgent']?.toString() ?? '';
      return userAgent.contains('Chrome') && !userAgent.contains('Edg');
    } catch (_) {
      return false;
    }
  }

  /// Pair Evora Band via Web Bluetooth
  Future<DevicePairResult> pairBand() async {
    if (!isSupported) {
      return const DevicePairResult(
        success: false,
        message: 'Web Bluetooth is only available in Chrome. Please open this app in Google Chrome.',
      );
    }

    final completer = Completer<DevicePairResult>();

    try {
      js.context['EvoraBluetooth']?.callMethod('pairBand', [
        js.allowInterop((String result) {
          final data = json.decode(result) as Map<String, dynamic>;
          final device = PairedDevice.fromJson(data);
          _connected['band'] = device;
          _saveDeviceToFirestore(device);
          _statusController.add('band_connected:${device.name}');
          completer.complete(DevicePairResult(success: true, message: '${device.name} connected', device: device));
        }),
        js.allowInterop((String error) {
          completer.complete(DevicePairResult(success: false, message: error));
        }),
      ]);
    } catch (e) {
      return DevicePairResult(success: false, message: 'Bluetooth error: $e');
    }

    return completer.future.timeout(
      const Duration(seconds: 60),
      onTimeout: () => const DevicePairResult(success: false, message: 'Pairing timed out. Try again.'),
    );
  }

  /// Pair Evora Scale via Web Bluetooth
  Future<DevicePairResult> pairScale() async {
    if (!isSupported) {
      return const DevicePairResult(
        success: false,
        message: 'Web Bluetooth is only available in Chrome. Please open this app in Google Chrome.',
      );
    }

    final completer = Completer<DevicePairResult>();

    try {
      js.context['EvoraBluetooth']?.callMethod('pairScale', [
        js.allowInterop((String result) {
          final data = json.decode(result) as Map<String, dynamic>;
          final device = PairedDevice.fromJson(data);
          _connected['scale'] = device;
          _saveDeviceToFirestore(device);
          _statusController.add('scale_connected:${device.name}');
          completer.complete(DevicePairResult(success: true, message: '${device.name} connected', device: device));
        }),
        js.allowInterop((String error) {
          completer.complete(DevicePairResult(success: false, message: error));
        }),
      ]);
    } catch (e) {
      return DevicePairResult(success: false, message: 'Bluetooth error: $e');
    }

    return completer.future.timeout(
      const Duration(seconds: 60),
      onTimeout: () => const DevicePairResult(success: false, message: 'Pairing timed out. Try again.'),
    );
  }

  /// Start live heart rate notifications from Band
  Future<void> startHeartRateMonitor() async {
    if (!_connected.containsKey('band')) return;
    try {
      js.context['EvoraBluetooth']?.callMethod('readHeartRate', [
        js.allowInterop((String data) {
          final map = json.decode(data) as Map<String, dynamic>;
          final hr = map['heartRate'] as int?;
          if (hr != null) _heartRateController.add(hr);
        }),
        js.allowInterop((String err) => debugPrint('HR error: $err')),
      ]);
    } catch (e) {
      debugPrint('startHeartRateMonitor error: $e');
    }
  }

  /// Start live weight notifications from Scale
  Future<void> startWeightMonitor() async {
    if (!_connected.containsKey('scale')) return;
    try {
      js.context['EvoraBluetooth']?.callMethod('readWeight', [
        js.allowInterop((String data) {
          final map = json.decode(data) as Map<String, dynamic>;
          final weight = (map['weightKg'] as num?)?.toDouble();
          if (weight != null) {
            _weightController.add(weight);
            // Auto-save to Firebase when we get a stable reading
            _healthService.mergeScaleData(date: DateTime.now(), weightKg: weight);
          }
        }),
        js.allowInterop((String err) => debugPrint('Weight error: $err')),
      ]);
    } catch (e) {
      debugPrint('startWeightMonitor error: $e');
    }
  }

  /// Full sync - pull all available data from Band
  Future<void> syncBand() async {
    if (!_connected.containsKey('band')) return;
    try {
      js.context['EvoraBluetooth']?.callMethod('syncBand', [
        js.allowInterop((String data) {
          final map = json.decode(data) as Map<String, dynamic>;
          final battery = map['batteryLevel'] as int?;
          if (battery != null && _connected['band'] != null) {
            _connected['band']!.batteryLevel = battery;
          }
          _statusController.add('band_synced');
        }),
        js.allowInterop((String err) => debugPrint('Band sync error: $err')),
      ]);
    } catch (e) {
      debugPrint('syncBand error: $e');
    }
  }

  /// Disconnect a device
  void disconnect(String deviceType) {
    try {
      js.context['EvoraBluetooth']?.callMethod('disconnect', [deviceType]);
    } catch (_) {}
    _connected.remove(deviceType);
    _statusController.add('${deviceType}_disconnected');
  }

  void disconnectAll() {
    disconnect('band');
    disconnect('scale');
  }

  /// Load previously paired devices from Firestore
  Future<List<PairedDevice>> loadSavedDevices() async {
    if (_uid == null) return [];
    try {
      final snap = await _db
          .collection('users')
          .doc(_uid)
          .collection('devices')
          .get();
      return snap.docs.map((d) {
        final data = d.data();
        return PairedDevice(
          id: d.id,
          name: data['name'] ?? 'Evora Device',
          type: data['type'] ?? 'band',
          pairedAt: (data['pairedAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
          isConnected: false, // not connected until re-paired this session
        );
      }).toList();
    } catch (_) {
      return [];
    }
  }

  Future<void> _saveDeviceToFirestore(PairedDevice device) async {
    if (_uid == null) return;
    await _db
        .collection('users')
        .doc(_uid)
        .collection('devices')
        .doc(device.id)
        .set({
          ...device.toMap(),
          'lastConnectedAt': FieldValue.serverTimestamp(),
        }, SetOptions(merge: true));
  }
}
