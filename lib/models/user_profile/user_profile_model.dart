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
      this.allowAgentMedicationUpdates});

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
    return data;
  }
}
