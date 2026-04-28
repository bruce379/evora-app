import 'package:flutter/foundation.dart';
import 'package:health/health.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../models/health_snapshot.dart';
import 'insights_engine.dart';

enum SyncStatus { idle, syncing, success, failed, unsupported }

class SyncResult {
  final SyncStatus status;
  final String message;
  final HealthSnapshot? snapshot;
  final DateTime timestamp;

  const SyncResult({
    required this.status,
    required this.message,
    this.snapshot,
    required this.timestamp,
  });
}

class HealthService {
  static final HealthService _instance = HealthService._internal();
  factory HealthService() => _instance;
  HealthService._internal();

  final Health _health = Health();
  final FirebaseFirestore _db = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  String? get _uid => _auth.currentUser?.uid;

  // All data types we request
  static const List<HealthDataType> _readTypes = [
    HealthDataType.STEPS,
    HealthDataType.DISTANCE_WALKING_RUNNING,
    HealthDataType.ACTIVE_ENERGY_BURNED,
    HealthDataType.TOTAL_CALORIES_BURNED,
    HealthDataType.EXERCISE_TIME,
    HealthDataType.HEART_RATE,
    HealthDataType.RESTING_HEART_RATE,
    HealthDataType.HEART_RATE_VARIABILITY_SDNN,
    HealthDataType.BLOOD_OXYGEN,
    HealthDataType.WEIGHT,
    HealthDataType.BODY_MASS_INDEX,
    HealthDataType.BODY_FAT_PERCENTAGE,
    HealthDataType.SLEEP_ASLEEP,
    HealthDataType.SLEEP_DEEP,
    HealthDataType.SLEEP_REM,
    HealthDataType.SLEEP_LIGHT,
    HealthDataType.SLEEP_IN_BED,
    HealthDataType.WORKOUT,
  ];

  static const List<HealthDataType> _writeTypes = [
    HealthDataType.STEPS,
    HealthDataType.HEART_RATE,
    HealthDataType.WEIGHT,
    HealthDataType.WORKOUT,
    HealthDataType.SLEEP_ASLEEP,
  ];

  bool _permissionsGranted = false;

  /// Request permissions from user - call once on first launch
  Future<bool> requestPermissions() async {
    if (kIsWeb) return false; // HealthKit/Health Connect not available on web

    try {
      final requested = await _health.requestAuthorization(
        _readTypes,
        permissions: _readTypes.map((_) => HealthDataAccess.READ).toList(),
      );
      _permissionsGranted = requested;
      return requested;
    } catch (e) {
      debugPrint('Health permissions error: $e');
      return false;
    }
  }

  /// Check if permissions already granted
  Future<bool> hasPermissions() async {
    if (kIsWeb) return false;
    try {
      final has = await _health.hasPermissions(_readTypes);
      _permissionsGranted = has ?? false;
      return _permissionsGranted;
    } catch (_) {
      return false;
    }
  }

  /// AUTO SYNC - call on app open. Syncs today + yesterday (catches overnight sleep data)
  Future<SyncResult> autoSync() async {
    return _sync(daysBack: 2, source: 'auto');
  }

  /// MANUAL SYNC - user taps Sync button. Syncs last 7 days for full picture
  Future<SyncResult> manualSync() async {
    return _sync(daysBack: 7, source: 'manual');
  }

  Future<SyncResult> _sync({required int daysBack, required String source}) async {
    if (_uid == null) {
      return SyncResult(status: SyncStatus.failed, message: 'Not logged in', timestamp: DateTime.now());
    }

    if (kIsWeb) {
      // Web: load from Firestore only (data was synced from native app)
      return SyncResult(
        status: SyncStatus.unsupported,
        message: 'Health sync requires the mobile app. Showing your stored data.',
        timestamp: DateTime.now(),
      );
    }

    if (!_permissionsGranted) {
      final granted = await requestPermissions();
      if (!granted) {
        return SyncResult(
          status: SyncStatus.failed,
          message: 'Health permissions not granted.',
          timestamp: DateTime.now(),
        );
      }
    }

    try {
      final now = DateTime.now();
      final start = DateTime(now.year, now.month, now.day - daysBack);
      final end = now;

      final dataPoints = await _health.getHealthDataFromTypes(
        startTime: start,
        endTime: end,
        types: _readTypes,
      );

      // Deduplicate
      final unique = Health.removeDuplicates(dataPoints);

      // Group by day and build snapshots
      final snapshots = _groupByDay(unique, start, end);

      // Run insights engine on each
      int saved = 0;
      HealthSnapshot? latestSnapshot;
      for (final snapshot in snapshots.values) {
        final enriched = InsightsEngine.enrich(snapshot);
        await _saveSnapshot(enriched);
        saved++;
        if (latestSnapshot == null || enriched.date.isAfter(latestSnapshot.date)) {
          latestSnapshot = enriched;
        }
      }

      return SyncResult(
        status: SyncStatus.success,
        message: '$source sync complete. $saved days updated.',
        snapshot: latestSnapshot,
        timestamp: DateTime.now(),
      );
    } catch (e) {
      debugPrint('Health sync error: $e');
      return SyncResult(
        status: SyncStatus.failed,
        message: 'Sync failed: ${e.toString().substring(0, 80)}',
        timestamp: DateTime.now(),
      );
    }
  }

  /// Group raw HealthDataPoints into daily HealthSnapshots
  Map<String, HealthSnapshot> _groupByDay(
    List<HealthDataPoint> points,
    DateTime start,
    DateTime end,
  ) {
    final Map<String, Map<HealthDataType, List<HealthDataPoint>>> byDay = {};

    for (final p in points) {
      final key = _dateKey(p.dateFrom);
      byDay.putIfAbsent(key, () => {});
      byDay[key]!.putIfAbsent(p.type, () => []);
      byDay[key]![p.type]!.add(p);
    }

    final Map<String, HealthSnapshot> snapshots = {};
    final sources = <String>{'apple_health'};

    byDay.forEach((dateKey, typeMap) {
      final date = _parseKey(dateKey);

      // Helper: avg of numeric values
      double? avg(HealthDataType t) {
        final pts = typeMap[t];
        if (pts == null || pts.isEmpty) return null;
        final vals = pts.map((p) => (p.value as NumericHealthValue).numericValue.toDouble()).toList();
        return vals.reduce((a, b) => a + b) / vals.length;
      }

      double? max(HealthDataType t) {
        final pts = typeMap[t];
        if (pts == null || pts.isEmpty) return null;
        return pts.map((p) => (p.value as NumericHealthValue).numericValue.toDouble()).reduce((a, b) => a > b ? a : b);
      }

      double? min(HealthDataType t) {
        final pts = typeMap[t];
        if (pts == null || pts.isEmpty) return null;
        return pts.map((p) => (p.value as NumericHealthValue).numericValue.toDouble()).reduce((a, b) => a < b ? a : b);
      }

      double? sum(HealthDataType t) {
        final pts = typeMap[t];
        if (pts == null || pts.isEmpty) return null;
        return pts.map((p) => (p.value as NumericHealthValue).numericValue.toDouble()).reduce((a, b) => a + b);
      }

      double? latest(HealthDataType t) {
        final pts = typeMap[t];
        if (pts == null || pts.isEmpty) return null;
        pts.sort((a, b) => b.dateFrom.compareTo(a.dateFrom));
        return (pts.first.value as NumericHealthValue).numericValue.toDouble();
      }

      // Sleep duration calculation
      double? sleepHours(HealthDataType t) {
        final pts = typeMap[t];
        if (pts == null || pts.isEmpty) return null;
        double totalMins = 0;
        for (final p in pts) {
          totalMins += p.dateTo.difference(p.dateFrom).inMinutes;
        }
        return totalMins / 60.0;
      }

      // Workouts
      final workoutPts = typeMap[HealthDataType.WORKOUT] ?? [];
      final workouts = workoutPts.map((p) {
        final wv = p.value as WorkoutHealthValue;
        return WorkoutRecord(
          type: wv.workoutActivityType.name.toLowerCase(),
          startTime: p.dateFrom,
          endTime: p.dateTo,
          calories: null,
          source: 'apple_health',
        );
      }).toList();

      snapshots[dateKey] = HealthSnapshot(
        uid: _uid!,
        date: date,
        steps: sum(HealthDataType.STEPS)?.toInt(),
        distanceKm: sum(HealthDataType.DISTANCE_WALKING_RUNNING) != null
            ? sum(HealthDataType.DISTANCE_WALKING_RUNNING)! / 1000
            : null,
        activeCalories: sum(HealthDataType.ACTIVE_ENERGY_BURNED),
        totalCalories: sum(HealthDataType.TOTAL_CALORIES_BURNED),
        activeMinutes: sum(HealthDataType.EXERCISE_TIME)?.toInt(),
        restingHeartRate: latest(HealthDataType.RESTING_HEART_RATE),
        avgHeartRate: avg(HealthDataType.HEART_RATE),
        maxHeartRate: max(HealthDataType.HEART_RATE),
        minHeartRate: min(HealthDataType.HEART_RATE),
        hrv: avg(HealthDataType.HEART_RATE_VARIABILITY_SDNN),
        spo2: avg(HealthDataType.BLOOD_OXYGEN),
        weightKg: latest(HealthDataType.WEIGHT),
        bmi: latest(HealthDataType.BODY_MASS_INDEX),
        bodyFatPercent: latest(HealthDataType.BODY_FAT_PERCENTAGE),
        sleepDurationHours: sleepHours(HealthDataType.SLEEP_ASLEEP),
        deepSleepHours: sleepHours(HealthDataType.SLEEP_DEEP),
        remSleepHours: sleepHours(HealthDataType.SLEEP_REM),
        lightSleepHours: sleepHours(HealthDataType.SLEEP_LIGHT),
        workouts: workouts,
        dataSources: sources.toList(),
        syncedAt: DateTime.now(),
      );
    });

    return snapshots;
  }

  /// Save snapshot to Firestore under users/{uid}/health/{dateKey}
  Future<void> _saveSnapshot(HealthSnapshot snapshot) async {
    if (_uid == null) return;
    await _db
        .collection('users')
        .doc(_uid)
        .collection('health')
        .doc(snapshot.dateKey)
        .set(snapshot.toFirestore(), SetOptions(merge: true));
  }

  /// Merge data from Evora Band (called by DeviceService when band syncs)
  Future<void> mergeBandData({
    required DateTime date,
    int? steps,
    double? restingHR,
    double? avgHR,
    double? maxHR,
    double? hrv,
    double? spo2,
    double? activeCalories,
    int? activeMinutes,
    double? sleepHours,
    double? deepSleepHours,
    double? remSleepHours,
  }) async {
    if (_uid == null) return;
    final key = _dateKey(date);
    final update = <String, dynamic>{
      'dataSources': FieldValue.arrayUnion(['evora_band']),
      'syncedAt': FieldValue.serverTimestamp(),
    };
    if (steps != null) update['steps'] = steps;
    if (restingHR != null) update['restingHeartRate'] = restingHR;
    if (avgHR != null) update['avgHeartRate'] = avgHR;
    if (maxHR != null) update['maxHeartRate'] = maxHR;
    if (hrv != null) update['hrv'] = hrv;
    if (spo2 != null) update['spo2'] = spo2;
    if (activeCalories != null) update['activeCalories'] = activeCalories;
    if (activeMinutes != null) update['activeMinutes'] = activeMinutes;
    if (sleepHours != null) update['sleepDurationHours'] = sleepHours;
    if (deepSleepHours != null) update['deepSleepHours'] = deepSleepHours;
    if (remSleepHours != null) update['remSleepHours'] = remSleepHours;

    await _db.collection('users').doc(_uid).collection('health').doc(key).set(update, SetOptions(merge: true));
  }

  /// Merge data from Evora Scale (called by DeviceService when scale syncs)
  Future<void> mergeScaleData({
    required DateTime date,
    double? weightKg,
    double? bmi,
    double? bodyFatPercent,
    double? muscleMassKg,
    double? boneMassKg,
    double? hydrationPercent,
    double? visceralFatScore,
  }) async {
    if (_uid == null) return;
    final key = _dateKey(date);
    final update = <String, dynamic>{
      'dataSources': FieldValue.arrayUnion(['evora_scale']),
      'syncedAt': FieldValue.serverTimestamp(),
    };
    if (weightKg != null) update['weightKg'] = weightKg;
    if (bmi != null) update['bmi'] = bmi;
    if (bodyFatPercent != null) update['bodyFatPercent'] = bodyFatPercent;
    if (muscleMassKg != null) update['muscleMassKg'] = muscleMassKg;
    if (boneMassKg != null) update['boneMassKg'] = boneMassKg;
    if (hydrationPercent != null) update['hydrationPercent'] = hydrationPercent;
    if (visceralFatScore != null) update['visceralFatScore'] = visceralFatScore;

    await _db.collection('users').doc(_uid).collection('health').doc(key).set(update, SetOptions(merge: true));
  }

  /// Load last N days of snapshots from Firestore (works on web too)
  Future<List<HealthSnapshot>> loadHistory({int days = 30}) async {
    if (_uid == null) return [];
    final since = DateTime.now().subtract(Duration(days: days));
    final snap = await _db
        .collection('users')
        .doc(_uid)
        .collection('health')
        .where('date', isGreaterThanOrEqualTo: Timestamp.fromDate(since))
        .orderBy('date', descending: true)
        .get();
    return snap.docs.map((d) => HealthSnapshot.fromFirestore(d.data(), _uid!)).toList();
  }

  /// Stream today's snapshot
  Stream<HealthSnapshot?> todayStream() {
    if (_uid == null) return const Stream.empty();
    final key = _dateKey(DateTime.now());
    return _db
        .collection('users')
        .doc(_uid)
        .collection('health')
        .doc(key)
        .snapshots()
        .map((d) => d.exists ? HealthSnapshot.fromFirestore(d.data()!, _uid!) : null);
  }

  String _dateKey(DateTime d) =>
      '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

  DateTime _parseKey(String key) {
    final parts = key.split('-');
    return DateTime(int.parse(parts[0]), int.parse(parts[1]), int.parse(parts[2]));
  }
}
