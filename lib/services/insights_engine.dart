import '../models/health_snapshot.dart';

enum InsightPriority { high, medium, low }
enum InsightCategory { recovery, fitness, body, sleep, nutrition, heart }

class Insight {
  final String id;
  final InsightCategory category;
  final InsightPriority priority;
  final String headline;    // Short - shown on card
  final String detail;      // Expanded explanation
  final String action;      // What to do about it
  final String? metric;     // The number driving this
  final String? trend;      // "up", "down", "stable"
  final IconType icon;

  const Insight({
    required this.id,
    required this.category,
    required this.priority,
    required this.headline,
    required this.detail,
    required this.action,
    this.metric,
    this.trend,
    required this.icon,
  });
}

enum IconType { heart, sleep, steps, weight, fire, warning, check, trend }

class DayInsights {
  final HealthSnapshot snapshot;
  final int recoveryScore;    // 0-100
  final int readinessScore;   // 0-100
  final int sleepScore;       // 0-100
  final int fitnessScore;     // 0-100
  final String readinessLabel; // "Ready", "Take it easy", "Rest day"
  final List<Insight> insights;
  final List<String> todaysPriorities; // Top 3 things to do today

  const DayInsights({
    required this.snapshot,
    required this.recoveryScore,
    required this.readinessScore,
    required this.sleepScore,
    required this.fitnessScore,
    required this.readinessLabel,
    required this.insights,
    required this.todaysPriorities,
  });
}

/// InsightsEngine turns raw HealthSnapshot data into DayInsights with
/// actionable recommendations. All logic is deterministic and explainable.
class InsightsEngine {
  /// Enrich a snapshot with computed scores (saves back to Firestore via HealthService)
  static HealthSnapshot enrich(HealthSnapshot s) {
    final recovery = _recoveryScore(s);
    final sleep = _sleepScore(s);
    final fitness = _fitnessScore(s);
    final readiness = ((recovery * 0.5) + (sleep * 0.3) + (fitness * 0.2)).round();

    return HealthSnapshot(
      uid: s.uid,
      date: s.date,
      steps: s.steps,
      distanceKm: s.distanceKm,
      activeCalories: s.activeCalories,
      totalCalories: s.totalCalories,
      activeMinutes: s.activeMinutes,
      standHours: s.standHours,
      restingHeartRate: s.restingHeartRate,
      avgHeartRate: s.avgHeartRate,
      maxHeartRate: s.maxHeartRate,
      minHeartRate: s.minHeartRate,
      hrv: s.hrv,
      spo2: s.spo2,
      weightKg: s.weightKg,
      bmi: s.bmi,
      bodyFatPercent: s.bodyFatPercent,
      muscleMassKg: s.muscleMassKg,
      boneMassKg: s.boneMassKg,
      hydrationPercent: s.hydrationPercent,
      visceralFatScore: s.visceralFatScore,
      sleepDurationHours: s.sleepDurationHours,
      deepSleepHours: s.deepSleepHours,
      remSleepHours: s.remSleepHours,
      lightSleepHours: s.lightSleepHours,
      sleepEfficiency: s.sleepEfficiency,
      bedtime: s.bedtime,
      wakeTime: s.wakeTime,
      workouts: s.workouts,
      dataSources: s.dataSources,
      recoveryScore: recovery,
      readinessScore: readiness,
      sleepScore: sleep,
      fitnessScore: fitness,
      syncedAt: s.syncedAt,
    );
  }

  /// Generate full DayInsights from a snapshot + optional history for trends
  static DayInsights analyze(
    HealthSnapshot today, {
    List<HealthSnapshot> history = const [],
  }) {
    final recovery = today.recoveryScore ?? _recoveryScore(today);
    final sleep = today.sleepScore ?? _sleepScore(today);
    final fitness = today.fitnessScore ?? _fitnessScore(today);
    final readiness = today.readinessScore ?? ((recovery * 0.5) + (sleep * 0.3) + (fitness * 0.2)).round();

    final insights = <Insight>[
      ..._recoveryInsights(today, history),
      ..._sleepInsights(today, history),
      ..._fitnessInsights(today, history),
      ..._bodyInsights(today, history),
      ..._heartInsights(today, history),
    ];

    // Sort by priority
    insights.sort((a, b) => a.priority.index.compareTo(b.priority.index));

    return DayInsights(
      snapshot: today,
      recoveryScore: recovery,
      readinessScore: readiness,
      sleepScore: sleep,
      fitnessScore: fitness,
      readinessLabel: _readinessLabel(readiness),
      insights: insights,
      todaysPriorities: _buildPriorities(readiness, insights, today),
    );
  }

  // ---------------------------------------------------------------------------
  // SCORE ALGORITHMS
  // ---------------------------------------------------------------------------

  static int _recoveryScore(HealthSnapshot s) {
    int score = 50; // baseline

    // HRV is the #1 recovery indicator
    if (s.hrv != null) {
      if (s.hrv! >= 60) score += 25;
      else if (s.hrv! >= 45) score += 15;
      else if (s.hrv! >= 30) score += 5;
      else score -= 10; // Low HRV = poor recovery
    }

    // Resting HR - lower is better (relative to normal)
    if (s.restingHeartRate != null) {
      final hr = s.restingHeartRate!;
      if (hr <= 55) score += 15;
      else if (hr <= 65) score += 8;
      else if (hr <= 75) score += 0;
      else score -= 10; // Elevated resting HR = stress/fatigue
    }

    // SpO2
    if (s.spo2 != null) {
      if (s.spo2! >= 98) score += 10;
      else if (s.spo2! >= 95) score += 5;
      else score -= 15; // Low SpO2 is a concern
    }

    return score.clamp(0, 100);
  }

  static int _sleepScore(HealthSnapshot s) {
    int score = 0;

    // Duration - 7-9 hours is optimal
    if (s.sleepDurationHours != null) {
      final h = s.sleepDurationHours!;
      if (h >= 7 && h <= 9) score += 40;
      else if (h >= 6 && h < 7) score += 25;
      else if (h > 9) score += 30;
      else score += 10; // Under 6 hours
    } else {
      score += 20; // No data, neutral
    }

    // Deep sleep - should be 15-20% of total
    if (s.deepSleepHours != null && s.sleepDurationHours != null && s.sleepDurationHours! > 0) {
      final deepPercent = (s.deepSleepHours! / s.sleepDurationHours!) * 100;
      if (deepPercent >= 15) score += 30;
      else if (deepPercent >= 10) score += 15;
      else score += 5;
    } else {
      score += 20;
    }

    // REM sleep - should be 20-25% of total
    if (s.remSleepHours != null && s.sleepDurationHours != null && s.sleepDurationHours! > 0) {
      final remPercent = (s.remSleepHours! / s.sleepDurationHours!) * 100;
      if (remPercent >= 20) score += 30;
      else if (remPercent >= 15) score += 15;
      else score += 5;
    } else {
      score += 20;
    }

    return score.clamp(0, 100);
  }

  static int _fitnessScore(HealthSnapshot s) {
    int score = 0;

    // Steps - WHO recommends 7,500-10,000
    if (s.steps != null) {
      if (s.steps! >= 10000) score += 35;
      else if (s.steps! >= 7500) score += 25;
      else if (s.steps! >= 5000) score += 15;
      else score += 5;
    } else {
      score += 15;
    }

    // Active minutes - 30+ mins/day
    if (s.activeMinutes != null) {
      if (s.activeMinutes! >= 60) score += 35;
      else if (s.activeMinutes! >= 30) score += 25;
      else if (s.activeMinutes! >= 15) score += 10;
      else score += 0;
    } else {
      score += 15;
    }

    // Workouts
    if (s.workouts.isNotEmpty) score += 30;
    else score += 10;

    return score.clamp(0, 100);
  }

  // ---------------------------------------------------------------------------
  // INSIGHT GENERATORS
  // ---------------------------------------------------------------------------

  static List<Insight> _recoveryInsights(HealthSnapshot s, List<HealthSnapshot> h) {
    final insights = <Insight>[];

    if (s.hrv != null) {
      if (s.hrv! < 30) {
        insights.add(const Insight(
          id: 'hrv_low',
          category: InsightCategory.recovery,
          priority: InsightPriority.high,
          headline: 'Your body needs rest today',
          detail: 'Your HRV is low, which means your nervous system is under stress. This is not the day for hard training.',
          action: 'Prioritise walking, stretching or a light yoga session. Aim for 8+ hours of sleep tonight.',
          metric: null,
          icon: IconType.warning,
        ));
      } else if (s.hrv! >= 60) {
        insights.add(const Insight(
          id: 'hrv_high',
          category: InsightCategory.recovery,
          priority: InsightPriority.low,
          headline: 'You are well recovered',
          detail: 'High HRV indicates your nervous system is recovered and ready for a challenging session.',
          action: 'Great day for a hard workout or a new personal best attempt.',
          icon: IconType.check,
        ));
      }
    }

    if (s.restingHeartRate != null && s.restingHeartRate! > 75) {
      insights.add(Insight(
        id: 'rhr_elevated',
        category: InsightCategory.recovery,
        priority: InsightPriority.medium,
        headline: 'Resting heart rate is elevated',
        detail: 'Your resting HR of ${s.restingHeartRate!.round()} bpm is above the ideal range. This often indicates stress, dehydration or the start of illness.',
        action: 'Drink more water, reduce caffeine today, and consider a lighter training load.',
        metric: '${s.restingHeartRate!.round()} bpm',
        icon: IconType.heart,
      ));
    }

    return insights;
  }

  static List<Insight> _sleepInsights(HealthSnapshot s, List<HealthSnapshot> h) {
    final insights = <Insight>[];
    if (s.sleepDurationHours == null) return insights;

    final hours = s.sleepDurationHours!;

    if (hours < 6) {
      insights.add(Insight(
        id: 'sleep_short',
        category: InsightCategory.sleep,
        priority: InsightPriority.high,
        headline: 'Critical sleep debt building up',
        detail: 'You only slept ${hours.toStringAsFixed(1)} hours. Under 6 hours severely impairs recovery, cognitive function and fat loss.',
        action: 'Tonight: no screens after 9pm, keep your bedroom cool, aim to be in bed by 10pm.',
        metric: '${hours.toStringAsFixed(1)}h',
        trend: 'down',
        icon: IconType.sleep,
      ));
    } else if (hours >= 6 && hours < 7) {
      insights.add(Insight(
        id: 'sleep_below_optimal',
        category: InsightCategory.sleep,
        priority: InsightPriority.medium,
        headline: 'Slightly under your sleep target',
        detail: 'You got ${hours.toStringAsFixed(1)} hours. Aim for 7-9 hours for optimal recovery and performance.',
        action: 'Try going to bed 45 minutes earlier tonight.',
        metric: '${hours.toStringAsFixed(1)}h',
        icon: IconType.sleep,
      ));
    } else if (hours >= 7 && hours <= 9) {
      insights.add(Insight(
        id: 'sleep_good',
        category: InsightCategory.sleep,
        priority: InsightPriority.low,
        headline: 'Great sleep last night',
        detail: 'You hit the sweet spot with ${hours.toStringAsFixed(1)} hours of sleep.',
        action: 'Keep this sleep schedule. Consistency is as important as duration.',
        metric: '${hours.toStringAsFixed(1)}h',
        icon: IconType.sleep,
      ));
    }

    // Deep sleep check
    if (s.deepSleepHours != null && s.sleepDurationHours! > 0) {
      final deepPct = (s.deepSleepHours! / s.sleepDurationHours!) * 100;
      if (deepPct < 10) {
        insights.add(Insight(
          id: 'deep_sleep_low',
          category: InsightCategory.sleep,
          priority: InsightPriority.medium,
          headline: 'Low deep sleep detected',
          detail: 'Deep sleep (${deepPct.round()}% of your night) is where your body physically repairs itself. Low deep sleep means slower muscle recovery.',
          action: 'Avoid alcohol, keep bedroom below 19C, and try magnesium glycinate before bed.',
          metric: '${deepPct.round()}% deep',
          icon: IconType.sleep,
        ));
      }
    }

    return insights;
  }

  static List<Insight> _fitnessInsights(HealthSnapshot s, List<HealthSnapshot> h) {
    final insights = <Insight>[];

    if (s.steps != null) {
      if (s.steps! < 5000) {
        insights.add(Insight(
          id: 'steps_low',
          category: InsightCategory.fitness,
          priority: InsightPriority.medium,
          headline: 'Movement is low today',
          detail: 'You have hit ${s.steps} steps. Low daily movement reduces calorie burn and cardiovascular health even with dedicated workouts.',
          action: 'Take a 20-minute walk before or after dinner. Every 1,000 steps counts.',
          metric: '${s.steps} steps',
          trend: 'down',
          icon: IconType.steps,
        ));
      } else if (s.steps! >= 10000) {
        insights.add(Insight(
          id: 'steps_goal',
          category: InsightCategory.fitness,
          priority: InsightPriority.low,
          headline: 'Step goal achieved',
          detail: 'You have hit ${s.steps} steps today. Consistent high daily movement is one of the strongest predictors of longevity.',
          action: 'Maintain this momentum. Tomorrow aim for the same.',
          metric: '${s.steps} steps',
          icon: IconType.check,
        ));
      }
    }

    if (s.workouts.isNotEmpty) {
      final w = s.workouts.first;
      insights.add(Insight(
        id: 'workout_logged',
        category: InsightCategory.fitness,
        priority: InsightPriority.low,
        headline: '${w.type.capitalize()} session logged',
        detail: '${w.durationMinutes} minutes of ${w.type}${w.calories != null ? " - ${w.calories!.round()} kcal burned" : ""}.',
        action: 'Log your next session to keep the streak going.',
        metric: '${w.durationMinutes} min',
        icon: IconType.fire,
      ));
    }

    return insights;
  }

  static List<Insight> _bodyInsights(HealthSnapshot s, List<HealthSnapshot> h) {
    final insights = <Insight>[];

    if (s.bodyFatPercent != null) {
      final bf = s.bodyFatPercent!;
      // General ranges (not gender-adjusted here - add user profile later)
      if (bf > 30) {
        insights.add(Insight(
          id: 'body_fat_high',
          category: InsightCategory.body,
          priority: InsightPriority.medium,
          headline: 'Body fat above healthy range',
          detail: 'Your body fat is ${bf.toStringAsFixed(1)}%. Sustained reduction requires a caloric deficit of 300-500kcal/day combined with resistance training.',
          action: 'Focus on protein at every meal (30g+) and add 2 resistance sessions per week.',
          metric: '${bf.toStringAsFixed(1)}%',
          icon: IconType.weight,
        ));
      }
    }

    // Weight trend from history
    if (h.length >= 7 && s.weightKg != null) {
      final withWeight = h.where((e) => e.weightKg != null).take(7).toList();
      if (withWeight.length >= 3) {
        final oldest = withWeight.last.weightKg!;
        final newest = withWeight.first.weightKg!;
        final diff = newest - oldest;
        if (diff.abs() > 0.3) {
          final direction = diff < 0 ? 'down' : 'up';
          final isGood = diff < 0; // Simplified - depends on user goal
          insights.add(Insight(
            id: 'weight_trend',
            category: InsightCategory.body,
            priority: InsightPriority.low,
            headline: 'Weight trending ${diff < 0 ? "down" : "up"} ${diff.abs().toStringAsFixed(1)}kg this week',
            detail: diff < 0
                ? 'You are losing weight at a healthy rate. Make sure you are maintaining muscle mass with adequate protein.'
                : 'Weight is creeping up. Check your caloric intake and ensure it aligns with your goals.',
            action: diff < 0
                ? 'Keep going. Hit your protein target daily (body weight in kg x 2 = grams of protein).'
                : 'Track meals for 3 days to understand where the extra calories are coming from.',
            metric: '${diff > 0 ? '+' : ''}${diff.toStringAsFixed(1)} kg',
            trend: direction,
            icon: IconType.trend,
          ));
        }
      }
    }

    return insights;
  }

  static List<Insight> _heartInsights(HealthSnapshot s, List<HealthSnapshot> h) {
    final insights = <Insight>[];

    if (s.spo2 != null && s.spo2! < 95) {
      insights.add(Insight(
        id: 'spo2_low',
        category: InsightCategory.heart,
        priority: InsightPriority.high,
        headline: 'Blood oxygen is low',
        detail: 'SpO2 of ${s.spo2!.round()}% is below the normal range of 95-100%. This can impact energy levels, sleep quality and recovery.',
        action: 'Check the reading with a medical oximeter. If consistently low, consult a doctor.',
        metric: '${s.spo2!.round()}%',
        icon: IconType.warning,
      ));
    }

    return insights;
  }

  // ---------------------------------------------------------------------------
  // HELPERS
  // ---------------------------------------------------------------------------

  static String _readinessLabel(int score) {
    if (score >= 80) return 'Ready to perform';
    if (score >= 60) return 'Good to train';
    if (score >= 40) return 'Train light today';
    return 'Rest day recommended';
  }

  static List<String> _buildPriorities(int readiness, List<Insight> insights, HealthSnapshot s) {
    final priorities = <String>[];

    // Priority 1: based on readiness
    if (readiness >= 80) {
      priorities.add('Push hard in training today - your body is ready');
    } else if (readiness >= 60) {
      priorities.add('Moderate training session is ideal today');
    } else {
      priorities.add('Focus on recovery: walk, stretch, sleep early');
    }

    // Priority 2: most urgent insight action
    final urgent = insights.where((i) => i.priority == InsightPriority.high).firstOrNull;
    if (urgent != null) {
      priorities.add(urgent.action);
    } else {
      final steps = s.steps ?? 0;
      if (steps < 7500) {
        priorities.add('Hit 7,500 steps - you have ${(7500 - steps).clamp(0, 99999)} to go');
      } else {
        priorities.add('Step goal on track - keep moving');
      }
    }

    // Priority 3: hydration / nutrition always relevant
    priorities.add('Drink ${_waterTarget(s.weightKg)}L of water today');

    return priorities;
  }

  static String _waterTarget(double? weight) {
    if (weight == null) return '2.5';
    return (weight * 0.033).toStringAsFixed(1);
  }
}

extension StringCapitalize on String {
  String capitalize() => isEmpty ? this : '${this[0].toUpperCase()}${substring(1)}';
}
