import 'package:cloud_firestore/cloud_firestore.dart';

/// One complete health snapshot - aggregated from all sources for a given day
class HealthSnapshot {
  final String uid;
  final DateTime date;

  // --- Movement ---
  final int? steps;
  final double? distanceKm;
  final double? activeCalories;
  final double? totalCalories;
  final int? activeMinutes;
  final int? standHours;

  // --- Heart ---
  final double? restingHeartRate;
  final double? avgHeartRate;
  final double? maxHeartRate;
  final double? minHeartRate;
  final double? hrv; // ms - RMSSD
  final double? spo2; // %

  // --- Body (from Scale) ---
  final double? weightKg;
  final double? bmi;
  final double? bodyFatPercent;
  final double? muscleMassKg;
  final double? boneMassKg;
  final double? hydrationPercent;
  final double? visceralFatScore;

  // --- Sleep ---
  final double? sleepDurationHours;
  final double? deepSleepHours;
  final double? remSleepHours;
  final double? lightSleepHours;
  final double? sleepEfficiency; // %
  final DateTime? bedtime;
  final DateTime? wakeTime;

  // --- Workouts ---
  final List<WorkoutRecord> workouts;

  // --- Sources ---
  final List<String> dataSources; // ["evora_band", "evora_scale", "apple_health", "google_health"]

  // --- Computed scores (set by InsightsEngine) ---
  final int? recoveryScore;   // 0-100
  final int? readinessScore;  // 0-100
  final int? sleepScore;      // 0-100
  final int? fitnessScore;    // 0-100

  final DateTime syncedAt;

  const HealthSnapshot({
    required this.uid,
    required this.date,
    this.steps,
    this.distanceKm,
    this.activeCalories,
    this.totalCalories,
    this.activeMinutes,
    this.standHours,
    this.restingHeartRate,
    this.avgHeartRate,
    this.maxHeartRate,
    this.minHeartRate,
    this.hrv,
    this.spo2,
    this.weightKg,
    this.bmi,
    this.bodyFatPercent,
    this.muscleMassKg,
    this.boneMassKg,
    this.hydrationPercent,
    this.visceralFatScore,
    this.sleepDurationHours,
    this.deepSleepHours,
    this.remSleepHours,
    this.lightSleepHours,
    this.sleepEfficiency,
    this.bedtime,
    this.wakeTime,
    this.workouts = const [],
    this.dataSources = const [],
    this.recoveryScore,
    this.readinessScore,
    this.sleepScore,
    this.fitnessScore,
    required this.syncedAt,
  });

  /// Key used in Firestore - YYYY-MM-DD
  String get dateKey => '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';

  Map<String, dynamic> toFirestore() => {
    'uid': uid,
    'date': Timestamp.fromDate(date),
    'dateKey': dateKey,
    'steps': steps,
    'distanceKm': distanceKm,
    'activeCalories': activeCalories,
    'totalCalories': totalCalories,
    'activeMinutes': activeMinutes,
    'standHours': standHours,
    'restingHeartRate': restingHeartRate,
    'avgHeartRate': avgHeartRate,
    'maxHeartRate': maxHeartRate,
    'minHeartRate': minHeartRate,
    'hrv': hrv,
    'spo2': spo2,
    'weightKg': weightKg,
    'bmi': bmi,
    'bodyFatPercent': bodyFatPercent,
    'muscleMassKg': muscleMassKg,
    'boneMassKg': boneMassKg,
    'hydrationPercent': hydrationPercent,
    'visceralFatScore': visceralFatScore,
    'sleepDurationHours': sleepDurationHours,
    'deepSleepHours': deepSleepHours,
    'remSleepHours': remSleepHours,
    'lightSleepHours': lightSleepHours,
    'sleepEfficiency': sleepEfficiency,
    'bedtime': bedtime != null ? Timestamp.fromDate(bedtime!) : null,
    'wakeTime': wakeTime != null ? Timestamp.fromDate(wakeTime!) : null,
    'workouts': workouts.map((w) => w.toMap()).toList(),
    'dataSources': dataSources,
    'recoveryScore': recoveryScore,
    'readinessScore': readinessScore,
    'sleepScore': sleepScore,
    'fitnessScore': fitnessScore,
    'syncedAt': Timestamp.fromDate(syncedAt),
  };

  factory HealthSnapshot.fromFirestore(Map<String, dynamic> d, String uid) => HealthSnapshot(
    uid: uid,
    date: (d['date'] as Timestamp).toDate(),
    steps: d['steps'],
    distanceKm: (d['distanceKm'] as num?)?.toDouble(),
    activeCalories: (d['activeCalories'] as num?)?.toDouble(),
    totalCalories: (d['totalCalories'] as num?)?.toDouble(),
    activeMinutes: d['activeMinutes'],
    standHours: d['standHours'],
    restingHeartRate: (d['restingHeartRate'] as num?)?.toDouble(),
    avgHeartRate: (d['avgHeartRate'] as num?)?.toDouble(),
    maxHeartRate: (d['maxHeartRate'] as num?)?.toDouble(),
    minHeartRate: (d['minHeartRate'] as num?)?.toDouble(),
    hrv: (d['hrv'] as num?)?.toDouble(),
    spo2: (d['spo2'] as num?)?.toDouble(),
    weightKg: (d['weightKg'] as num?)?.toDouble(),
    bmi: (d['bmi'] as num?)?.toDouble(),
    bodyFatPercent: (d['bodyFatPercent'] as num?)?.toDouble(),
    muscleMassKg: (d['muscleMassKg'] as num?)?.toDouble(),
    boneMassKg: (d['boneMassKg'] as num?)?.toDouble(),
    hydrationPercent: (d['hydrationPercent'] as num?)?.toDouble(),
    visceralFatScore: (d['visceralFatScore'] as num?)?.toDouble(),
    sleepDurationHours: (d['sleepDurationHours'] as num?)?.toDouble(),
    deepSleepHours: (d['deepSleepHours'] as num?)?.toDouble(),
    remSleepHours: (d['remSleepHours'] as num?)?.toDouble(),
    lightSleepHours: (d['lightSleepHours'] as num?)?.toDouble(),
    sleepEfficiency: (d['sleepEfficiency'] as num?)?.toDouble(),
    bedtime: (d['bedtime'] as Timestamp?)?.toDate(),
    wakeTime: (d['wakeTime'] as Timestamp?)?.toDate(),
    workouts: (d['workouts'] as List<dynamic>? ?? []).map((w) => WorkoutRecord.fromMap(w)).toList(),
    dataSources: List<String>.from(d['dataSources'] ?? []),
    recoveryScore: d['recoveryScore'],
    readinessScore: d['readinessScore'],
    sleepScore: d['sleepScore'],
    fitnessScore: d['fitnessScore'],
    syncedAt: (d['syncedAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
  );
}

class WorkoutRecord {
  final String type; // "running", "cycling", "strength", etc.
  final DateTime startTime;
  final DateTime endTime;
  final double? calories;
  final double? distanceKm;
  final double? avgHeartRate;
  final double? maxHeartRate;
  final String source;

  const WorkoutRecord({
    required this.type,
    required this.startTime,
    required this.endTime,
    this.calories,
    this.distanceKm,
    this.avgHeartRate,
    this.maxHeartRate,
    required this.source,
  });

  int get durationMinutes => endTime.difference(startTime).inMinutes;

  Map<String, dynamic> toMap() => {
    'type': type,
    'startTime': startTime.toIso8601String(),
    'endTime': endTime.toIso8601String(),
    'calories': calories,
    'distanceKm': distanceKm,
    'avgHeartRate': avgHeartRate,
    'maxHeartRate': maxHeartRate,
    'source': source,
  };

  factory WorkoutRecord.fromMap(Map<String, dynamic> m) => WorkoutRecord(
    type: m['type'] ?? 'unknown',
    startTime: DateTime.parse(m['startTime']),
    endTime: DateTime.parse(m['endTime']),
    calories: (m['calories'] as num?)?.toDouble(),
    distanceKm: (m['distanceKm'] as num?)?.toDouble(),
    avgHeartRate: (m['avgHeartRate'] as num?)?.toDouble(),
    maxHeartRate: (m['maxHeartRate'] as num?)?.toDouble(),
    source: m['source'] ?? 'unknown',
  );
}
