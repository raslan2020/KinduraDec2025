class UserProfile {
  bool? status;
  Result? result;

  UserProfile({this.status, this.result});

  UserProfile.fromJson(Map<String, dynamic> json) {
    status = json['status'];
    result =
        json['result'] != null ? new Result.fromJson(json['result']) : null;
  }

  Map<String, dynamic> toJson() {
    final Map<String, dynamic> data = new Map<String, dynamic>();
    data['status'] = this.status;
    if (this.result != null) {
      data['result'] = this.result!.toJson();
    }
    return data;
  }
}

class Result {
  String? firstName;
  String? lastName;
  String? email;
  String? phoneNumber;
  int? age;
  String? language;
  String? gender;
  String? address;
  String? agentConservationChoice;
  bool? termsAndConditions;
  String? unitSystem; // 'US' or 'SI'
  String? unitSystemDisplay; // Human-readable display label
  bool? allowAgentMedicationUpdates; // Allow Kindura AI to mark medications
  bool? extendedVitalsEnabled; // Enable collection of extended HealthKit vitals
  int? vitalsRetentionDays; // Vitals data retention period (30 or 60 days)
  Map<String, bool>? extendedVitalsPreferences; // Individual toggle for each extended vital

  Result(
      {this.firstName,
      this.lastName,
      this.email,
      this.phoneNumber,
      this.age,
      this.language,
      this.gender,
      this.address,
      this.agentConservationChoice,
      this.termsAndConditions,
      this.unitSystem,
      this.unitSystemDisplay,
      this.allowAgentMedicationUpdates,
      this.extendedVitalsEnabled,
      this.vitalsRetentionDays,
      this.extendedVitalsPreferences});

  Result.fromJson(Map<String, dynamic> json) {
    firstName = json['first_name'];
    lastName = json['last_name'];
    email = json['email'];
    phoneNumber = json['phone_number'];
    age = json['age'];
    language = json['language'];
    gender = json['gender'];
    address = json['address'];
    agentConservationChoice = json['agent_conservation_choice'];
    termsAndConditions = json['terms_and_conditions'];
    unitSystem = json['unit_system'] ?? 'US';
    unitSystemDisplay = json['unit_system_display'];
    allowAgentMedicationUpdates = json['allow_agent_medication_updates'] ?? false;
    extendedVitalsEnabled = json['extended_vitals_enabled'] ?? false;
    vitalsRetentionDays = json['vitals_retention_days'] ?? 60;
    // Parse extended vitals preferences from JSON
    if (json['extended_vitals_preferences'] != null) {
      extendedVitalsPreferences = Map<String, bool>.from(
        (json['extended_vitals_preferences'] as Map).map(
          (key, value) => MapEntry(key.toString(), value == true),
        ),
      );
    }
  }

  Map<String, dynamic> toJson() {
    final Map<String, dynamic> data = new Map<String, dynamic>();
    data['first_name'] = this.firstName;
    data['last_name'] = this.lastName;
    data['email'] = this.email;
    data['phone_number'] = this.phoneNumber;
    data['age'] = this.age;
    data['language'] = this.language;
    data['gender'] = this.gender;
    data['address'] = this.address;
    data['agent_conservation_choice'] = this.agentConservationChoice;
    data['terms_and_conditions'] = this.termsAndConditions;
    data['unit_system'] = this.unitSystem;
    data['allow_agent_medication_updates'] = this.allowAgentMedicationUpdates;
    data['extended_vitals_enabled'] = this.extendedVitalsEnabled;
    data['vitals_retention_days'] = this.vitalsRetentionDays;
    data['extended_vitals_preferences'] = this.extendedVitalsPreferences;
    return data;
  }
}

/// Default extended vitals preferences - all enabled by default
class ExtendedVitalsPreferences {
  static const Map<String, bool> defaults = {
    'walking_steadiness': true,
    'blood_pressure': true,
    'blood_glucose': true,
    'body_temperature': true,
    'wrist_temperature': true,
    'vo2_max': true,
    'afib_detection': true,
    'six_min_walk': true,
    'walking_asymmetry': true,
    'walking_speed': true,
    'double_support_time': true,
    'stair_ascent': true,
    'stair_descent': true,
    'peripheral_perfusion': true,
  };

  /// Display names for each vital
  static const Map<String, String> displayNames = {
    'walking_steadiness': 'Walking Steadiness',
    'blood_pressure': 'Blood Pressure',
    'blood_glucose': 'Blood Glucose',
    'body_temperature': 'Body Temperature',
    'wrist_temperature': 'Wrist Temperature',
    'vo2_max': 'VO2 Max',
    'afib_detection': 'AFib Detection',
    'six_min_walk': '6-Minute Walk',
    'walking_asymmetry': 'Walking Asymmetry',
    'walking_speed': 'Walking Speed',
    'double_support_time': 'Balance (Double Support)',
    'stair_ascent': 'Stair Ascent Speed',
    'stair_descent': 'Stair Descent Speed',
    'peripheral_perfusion': 'Perfusion Index',
  };

  /// Group vitals by category for settings UI
  static const Map<String, List<String>> categories = {
    'Cardiovascular': ['blood_pressure', 'afib_detection'],
    'Metabolic': ['blood_glucose', 'body_temperature', 'wrist_temperature'],
    'Fitness': ['vo2_max', 'peripheral_perfusion'],
    'Mobility': ['walking_steadiness', 'walking_speed', 'walking_asymmetry', 'six_min_walk', 'double_support_time', 'stair_ascent', 'stair_descent'],
  };
}
