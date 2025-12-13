class CoursesList {
  bool? status;
  List<Result>? result;

  CoursesList({this.status, this.result});

  CoursesList.fromJson(Map<String, dynamic> json) {
    status = json['status'];
    if (json['result'] != null) {
      result = <Result>[];
      json['result'].forEach((v) {
        result!.add(new Result.fromJson(v));
      });
    }
  }

  Map<String, dynamic> toJson() {
    final Map<String, dynamic> data = new Map<String, dynamic>();
    data['status'] = this.status;
    if (this.result != null) {
      data['result'] = this.result!.map((v) => v.toJson()).toList();
    }
    return data;
  }
}

class Result {
  Course? course;
  List<Medicines>? medicines;
  List<Schedules>? schedules;

  Result({this.course, this.medicines, this.schedules});

  Result.fromJson(Map<String, dynamic> json) {
    course =
        json['course'] != null ? new Course.fromJson(json['course']) : null;
    if (json['medicines'] != null) {
      medicines = <Medicines>[];
      json['medicines'].forEach((v) {
        medicines!.add(new Medicines.fromJson(v));
      });
    }
    if (json['schedules'] != null) {
      schedules = <Schedules>[];
      json['schedules'].forEach((v) {
        schedules!.add(new Schedules.fromJson(v));
      });
    }
  }

  Map<String, dynamic> toJson() {
    final Map<String, dynamic> data = new Map<String, dynamic>();
    if (this.course != null) {
      data['course'] = this.course!.toJson();
    }
    if (this.medicines != null) {
      data['medicines'] = this.medicines!.map((v) => v.toJson()).toList();
    }
    if (this.schedules != null) {
      data['schedules'] = this.schedules!.map((v) => v.toJson()).toList();
    }
    return data;
  }
}

class Course {
  int? id;
  String? name;
  String? startDate;
  int? duration;
  String? patientHistory;
  String? currentSituation;
  String? doctorInstructions;
  String? createdAt;
  bool? isActive;

  Course(
      {this.id,
      this.name,
      this.startDate,
      this.duration,
      this.patientHistory,
      this.currentSituation,
      this.doctorInstructions,
      this.createdAt,
      this.isActive});

  Course.fromJson(Map<String, dynamic> json) {
    id = json['id'];
    name = json['name'];
    startDate = json['start_date'];
    duration = json['duration'];
    patientHistory = json['patient_history'];
    currentSituation = json['current_situation'];
    doctorInstructions = json['doctor_instructions'];
    createdAt = json['created_at'];
    isActive = json['is_active'];
  }

  Map<String, dynamic> toJson() {
    final Map<String, dynamic> data = new Map<String, dynamic>();
    data['id'] = this.id;
    data['name'] = this.name;
    data['start_date'] = this.startDate;
    data['duration'] = this.duration;
    data['patient_history'] = this.patientHistory;
    data['current_situation'] = this.currentSituation;
    data['doctor_instructions'] = this.doctorInstructions;
    data['created_at'] = this.createdAt;
    data['is_active'] = this.isActive;
    return data;
  }
}

class Medicines {
  int? id;
  String? name;
  String? description;
  bool? isActive;

  Medicines({this.id, this.name, this.description, this.isActive});

  Medicines.fromJson(Map<String, dynamic> json) {
    id = json['id'];
    name = json['name'];
    description = json['description'];
    isActive = json['is_active'];
  }

  Map<String, dynamic> toJson() {
    final Map<String, dynamic> data = new Map<String, dynamic>();
    data['id'] = this.id;
    data['name'] = this.name;
    data['description'] = this.description;
    data['is_active'] = this.isActive;
    return data;
  }
}

class Schedules {
  int? id;
  int? medicineId;
  String? medicineName;
  String? time;
  String? dosage;
  bool? isActive;

  Schedules(
      {this.id,
      this.medicineId,
      this.medicineName,
      this.time,
      this.dosage,
      this.isActive});

  Schedules.fromJson(Map<String, dynamic> json) {
    id = json['id'];
    medicineId = json['medicine_id'];
    medicineName = json['medicine_name'];
    time = json['time'];
    dosage = json['dosage'];
    isActive = json['is_active'];
  }

  Map<String, dynamic> toJson() {
    final Map<String, dynamic> data = new Map<String, dynamic>();
    data['id'] = this.id;
    data['medicine_id'] = this.medicineId;
    data['medicine_name'] = this.medicineName;
    data['time'] = this.time;
    data['dosage'] = this.dosage;
    data['is_active'] = this.isActive;
    return data;
  }
}
