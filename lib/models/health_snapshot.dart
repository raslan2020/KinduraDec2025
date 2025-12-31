// Health data snapshot model for real-time HealthKit sync
//
// Provides type-safe representation of health vitals with support for:
// - Multiple data sources (WatchConnectivity, HealthKit, Manual)
// - Sleep tracking with stages
// - Activity metrics
// - JSON serialization for API/caching
// - 3-month data retention support with timestamps

/// Source of health data
enum HealthDataSource {
  watchConnectivity, // Real-time from Apple Watch via WCSession
  healthKit,         // From Apple Health (Oura, Whoop, Ultrahuman, etc.)
  manual,            // User-entered data
  unknown,           // Source not determined
}

/// Connection status for health data sync
enum HealthConnectionStatus {
  connected,    // Actively receiving data
  disconnected, // No active connection
  syncing,      // Currently syncing data
  error,        // Error state
}

/// Sleep stage data snapshot
class SleepSnapshot {
  final double deepSleepHours;
  final double remSleepHours;
  final double coreSleepHours;
  final double awakeHours;
  final int awakeningsCount;
  final String quality; // 'excellent', 'good', 'fair', 'poor', 'unknown'
  final double totalHours;
  final int? sleepScore;

  const SleepSnapshot({
    this.deepSleepHours = 0.0,
    this.remSleepHours = 0.0,
    this.coreSleepHours = 0.0,
    this.awakeHours = 0.0,
    this.awakeningsCount = 0,
    this.quality = 'unknown',
    this.totalHours = 0.0,
    this.sleepScore,
  });

  factory SleepSnapshot.fromJson(Map<String, dynamic> json) {
    return SleepSnapshot(
      deepSleepHours: (json['deep_sleep_hours'] ?? json['deepSleepHours'] ?? 0).toDouble(),
      remSleepHours: (json['rem_sleep_hours'] ?? json['remSleepHours'] ?? 0).toDouble(),
      coreSleepHours: (json['core_sleep_hours'] ?? json['coreSleepHours'] ?? 0).toDouble(),
      awakeHours: (json['awake_hours'] ?? json['awakeHours'] ?? json['awake_time_hours'] ?? 0).toDouble(),
      awakeningsCount: json['awakenings_count'] ?? json['awakeningsCount'] ?? json['awakenings'] ?? 0,
      quality: json['quality'] ?? json['sleep_quality'] ?? 'unknown',
      totalHours: (json['total_hours'] ?? json['totalHours'] ?? json['sleep_hours'] ?? 0).toDouble(),
      sleepScore: json['sleep_score'] ?? json['sleepScore'],
    );
  }

  Map<String, dynamic> toJson() => {
    'deep_sleep_hours': deepSleepHours,
    'rem_sleep_hours': remSleepHours,
    'core_sleep_hours': coreSleepHours,
    'awake_hours': awakeHours,
    'awakenings_count': awakeningsCount,
    'quality': quality,
    'total_hours': totalHours,
    'sleep_score': sleepScore,
  };

  SleepSnapshot copyWith({
    double? deepSleepHours,
    double? remSleepHours,
    double? coreSleepHours,
    double? awakeHours,
    int? awakeningsCount,
    String? quality,
    double? totalHours,
    int? sleepScore,
  }) {
    return SleepSnapshot(
      deepSleepHours: deepSleepHours ?? this.deepSleepHours,
      remSleepHours: remSleepHours ?? this.remSleepHours,
      coreSleepHours: coreSleepHours ?? this.coreSleepHours,
      awakeHours: awakeHours ?? this.awakeHours,
      awakeningsCount: awakeningsCount ?? this.awakeningsCount,
      quality: quality ?? this.quality,
      totalHours: totalHours ?? this.totalHours,
      sleepScore: sleepScore ?? this.sleepScore,
    );
  }

  @override
  String toString() => 'SleepSnapshot(total: ${totalHours}h, deep: ${deepSleepHours}h, rem: ${remSleepHours}h)';
}

/// Activity data snapshot
class ActivitySnapshot {
  final int steps;
  final int calories;
  final double distanceKm;
  final int floorsClimbed;
  final int exerciseMinutes;
  final int standMinutes;

  const ActivitySnapshot({
    this.steps = 0,
    this.calories = 0,
    this.distanceKm = 0.0,
    this.floorsClimbed = 0,
    this.exerciseMinutes = 0,
    this.standMinutes = 0,
  });

  factory ActivitySnapshot.fromJson(Map<String, dynamic> json) {
    return ActivitySnapshot(
      steps: json['steps'] ?? 0,
      calories: json['calories'] ?? 0,
      distanceKm: (json['distance_km'] ?? json['distanceKm'] ?? 0).toDouble(),
      floorsClimbed: json['floors_climbed'] ?? json['floorsClimbed'] ?? 0,
      exerciseMinutes: json['exercise_minutes'] ?? json['exerciseMinutes'] ?? 0,
      standMinutes: json['stand_minutes'] ?? json['standMinutes'] ?? 0,
    );
  }

  Map<String, dynamic> toJson() => {
    'steps': steps,
    'calories': calories,
    'distance_km': distanceKm,
    'floors_climbed': floorsClimbed,
    'exercise_minutes': exerciseMinutes,
    'stand_minutes': standMinutes,
  };

  ActivitySnapshot copyWith({
    int? steps,
    int? calories,
    double? distanceKm,
    int? floorsClimbed,
    int? exerciseMinutes,
    int? standMinutes,
  }) {
    return ActivitySnapshot(
      steps: steps ?? this.steps,
      calories: calories ?? this.calories,
      distanceKm: distanceKm ?? this.distanceKm,
      floorsClimbed: floorsClimbed ?? this.floorsClimbed,
      exerciseMinutes: exerciseMinutes ?? this.exerciseMinutes,
      standMinutes: standMinutes ?? this.standMinutes,
    );
  }

  @override
  String toString() => 'ActivitySnapshot(steps: $steps, cal: $calories, dist: ${distanceKm}km)';
}

/// Comprehensive health data snapshot
///
/// This is the primary model for health data sync between:
/// - Apple Watch (via WatchConnectivity)
/// - HealthKit (via native iOS bridge)
/// - Django API (via POST /api/watch-vitals/)
class HealthSnapshot {
  // Vitals
  final double? heartRate;
  final double? hrv;
  final double? spo2;
  final double? respiratoryRate;
  final int? restingHeartRate;
  final int? walkingHeartRate;

  // Blood pressure
  final int? bloodPressureSystolic;
  final int? bloodPressureDiastolic;

  // Sleep
  final SleepSnapshot sleep;

  // Activity
  final ActivitySnapshot activity;

  // Falls (Apple Watch only)
  final bool fallDetected;
  final int fallsCount;

  // Metadata
  final DateTime timestamp;
  final HealthDataSource source;
  final bool dataAvailable;
  final DateTime? lastSync;

  const HealthSnapshot({
    this.heartRate,
    this.hrv,
    this.spo2,
    this.respiratoryRate,
    this.restingHeartRate,
    this.walkingHeartRate,
    this.bloodPressureSystolic,
    this.bloodPressureDiastolic,
    this.sleep = const SleepSnapshot(),
    this.activity = const ActivitySnapshot(),
    this.fallDetected = false,
    this.fallsCount = 0,
    required this.timestamp,
    this.source = HealthDataSource.unknown,
    this.dataAvailable = false,
    this.lastSync,
  });

  /// Create from Map (compatibility with existing watchVitals Map)
  factory HealthSnapshot.fromMap(Map<String, dynamic> map) {
    return HealthSnapshot(
      heartRate: (map['heart_rate'] ?? map['heartRate'])?.toDouble(),
      hrv: (map['hrv'])?.toDouble(),
      spo2: (map['blood_oxygen'] ?? map['spo2'])?.toDouble(),
      respiratoryRate: (map['respiratory_rate'] ?? map['respiratoryRate'])?.toDouble(),
      restingHeartRate: map['resting_heart_rate'] ?? map['restingHeartRate'],
      walkingHeartRate: map['walking_heart_rate'] ?? map['walkingHeartRate'],
      bloodPressureSystolic: map['blood_pressure_systolic'] ?? map['bloodPressureSystolic'],
      bloodPressureDiastolic: map['blood_pressure_diastolic'] ?? map['bloodPressureDiastolic'],
      sleep: SleepSnapshot(
        totalHours: (map['sleep_hours'] ?? map['total_sleep_hours'] ?? 0).toDouble(),
        deepSleepHours: (map['deep_sleep_hours'] ?? 0).toDouble(),
        remSleepHours: (map['rem_sleep_hours'] ?? 0).toDouble(),
        coreSleepHours: (map['core_sleep_hours'] ?? 0).toDouble(),
        awakeHours: (map['awake_hours'] ?? map['awake_time_hours'] ?? 0).toDouble(),
        awakeningsCount: map['awakenings'] ?? map['awakenings_count'] ?? 0,
        quality: map['sleep_quality'] ?? 'unknown',
        sleepScore: map['sleep_score'],
      ),
      activity: ActivitySnapshot(
        steps: map['steps'] ?? 0,
        calories: map['calories'] ?? 0,
        distanceKm: (map['distance_km'] ?? 0).toDouble(),
        floorsClimbed: map['floors_climbed'] ?? 0,
        exerciseMinutes: map['exercise_minutes'] ?? 0,
        standMinutes: map['stand_minutes'] ?? 0,
      ),
      fallDetected: map['fall_detected'] ?? false,
      fallsCount: map['falls_count'] ?? 0,
      timestamp: map['timestamp'] != null
          ? (map['timestamp'] is DateTime
              ? map['timestamp']
              : DateTime.tryParse(map['timestamp'].toString()) ?? DateTime.now())
          : DateTime.now(),
      source: _parseSource(map['source']),
      dataAvailable: map['data_available'] ?? map['dataAvailable'] ?? false,
      lastSync: map['last_sync'] != null
          ? (map['last_sync'] is DateTime
              ? map['last_sync']
              : DateTime.tryParse(map['last_sync'].toString()))
          : null,
    );
  }

  /// Parse source string to enum
  static HealthDataSource _parseSource(dynamic source) {
    if (source == null) return HealthDataSource.unknown;
    final sourceStr = source.toString().toLowerCase();
    if (sourceStr.contains('watch')) return HealthDataSource.watchConnectivity;
    if (sourceStr.contains('health') || sourceStr.contains('apple')) return HealthDataSource.healthKit;
    if (sourceStr.contains('manual')) return HealthDataSource.manual;
    return HealthDataSource.unknown;
  }

  /// Convert to Map (compatibility with existing watchVitals Map)
  Map<String, dynamic> toMap() => {
    'heart_rate': heartRate ?? 0,
    'blood_oxygen': spo2 ?? 0,
    'hrv': hrv ?? 0,
    'respiratory_rate': respiratoryRate ?? 0,
    'resting_heart_rate': restingHeartRate ?? 0,
    'walking_heart_rate': walkingHeartRate ?? 0,
    'blood_pressure_systolic': bloodPressureSystolic ?? 0,
    'blood_pressure_diastolic': bloodPressureDiastolic ?? 0,
    'sleep_hours': sleep.totalHours,
    'sleep_score': sleep.sleepScore ?? 0,
    'deep_sleep_hours': sleep.deepSleepHours,
    'rem_sleep_hours': sleep.remSleepHours,
    'core_sleep_hours': sleep.coreSleepHours,
    'awake_hours': sleep.awakeHours,
    'awakenings': sleep.awakeningsCount,
    'sleep_quality': sleep.quality,
    'steps': activity.steps,
    'calories': activity.calories,
    'distance_km': activity.distanceKm,
    'floors_climbed': activity.floorsClimbed,
    'exercise_minutes': activity.exerciseMinutes,
    'stand_minutes': activity.standMinutes,
    'fall_detected': fallDetected,
    'falls_count': fallsCount,
    'timestamp': timestamp.toIso8601String(),
    'source': source.name,
    'data_available': dataAvailable,
    'last_sync': lastSync?.toIso8601String(),
    'is_demo': false,
  };

  /// Convert to API format for POST /api/watch-vitals/
  Map<String, dynamic> toApiJson() {
    // Valid sleep_quality values for API: excellent, good, fair, poor
    // Convert 'unknown' to null (API accepts null but not 'unknown')
    String? validSleepQuality;
    final quality = sleep.quality.toLowerCase();
    if (['excellent', 'good', 'fair', 'poor'].contains(quality)) {
      validSleepQuality = quality;
    }

    return {
      'heart_rate': heartRate ?? 0,
      'blood_oxygen': spo2 ?? 0,
      'hrv': hrv ?? 0,
      'respiratory_rate': respiratoryRate ?? 0,
      'total_sleep_hours': sleep.totalHours,
      'deep_sleep_hours': sleep.deepSleepHours,
      'rem_sleep_hours': sleep.remSleepHours,
      'core_sleep_hours': sleep.coreSleepHours,
      'awake_time_hours': sleep.awakeHours,
      'awakenings_count': sleep.awakeningsCount,
      'sleep_quality': validSleepQuality,
      'fall_detected': fallDetected,
      'recorded_at': timestamp.toIso8601String(),
      'steps': activity.steps,
      'calories': activity.calories,
      'distance_km': activity.distanceKm,
      'floors_climbed': activity.floorsClimbed,
      'exercise_minutes': activity.exerciseMinutes,
      'stand_minutes': activity.standMinutes,
      'source': source.name,
    };
  }

  HealthSnapshot copyWith({
    double? heartRate,
    double? hrv,
    double? spo2,
    double? respiratoryRate,
    int? restingHeartRate,
    int? walkingHeartRate,
    int? bloodPressureSystolic,
    int? bloodPressureDiastolic,
    SleepSnapshot? sleep,
    ActivitySnapshot? activity,
    bool? fallDetected,
    int? fallsCount,
    DateTime? timestamp,
    HealthDataSource? source,
    bool? dataAvailable,
    DateTime? lastSync,
  }) {
    return HealthSnapshot(
      heartRate: heartRate ?? this.heartRate,
      hrv: hrv ?? this.hrv,
      spo2: spo2 ?? this.spo2,
      respiratoryRate: respiratoryRate ?? this.respiratoryRate,
      restingHeartRate: restingHeartRate ?? this.restingHeartRate,
      walkingHeartRate: walkingHeartRate ?? this.walkingHeartRate,
      bloodPressureSystolic: bloodPressureSystolic ?? this.bloodPressureSystolic,
      bloodPressureDiastolic: bloodPressureDiastolic ?? this.bloodPressureDiastolic,
      sleep: sleep ?? this.sleep,
      activity: activity ?? this.activity,
      fallDetected: fallDetected ?? this.fallDetected,
      fallsCount: fallsCount ?? this.fallsCount,
      timestamp: timestamp ?? this.timestamp,
      source: source ?? this.source,
      dataAvailable: dataAvailable ?? this.dataAvailable,
      lastSync: lastSync ?? this.lastSync,
    );
  }

  /// Check if snapshot has meaningful vital data
  bool get hasVitals => (heartRate ?? 0) > 0 || (spo2 ?? 0) > 0 || (hrv ?? 0) > 0;

  /// Check if snapshot has activity data
  bool get hasActivity => activity.steps > 0 || activity.calories > 0;

  /// Check if snapshot has sleep data
  bool get hasSleep => sleep.totalHours > 0;

  @override
  String toString() => 'HealthSnapshot(HR: $heartRate, O2: $spo2, HRV: $hrv, source: ${source.name})';
}
