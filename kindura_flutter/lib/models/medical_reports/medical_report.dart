import 'package:flutter/material.dart';

class MedicalReport {
  bool? status;
  Result? result;

  MedicalReport({this.status, this.result});

  MedicalReport.fromJson(Map<String, dynamic> json) {
    status = json['status'];
    result = json['result'] != null ? Result.fromJson(json['result']) : null;
  }

  Map<String, dynamic> toJson() {
    final Map<String, dynamic> data = <String, dynamic>{};
    data['status'] = status;
    if (result != null) {
      data['result'] = result!.toJson();
    }
    return data;
  }
}

class Result {
  List<VitalSigns>? vitalSigns;
  List<BloodTest>? bloodTests;
  List<MedicalDocument>? documents;

  Result({this.vitalSigns, this.bloodTests, this.documents});

  Result.fromJson(Map<String, dynamic> json) {
    if (json['vital_signs'] != null) {
      vitalSigns = <VitalSigns>[];
      json['vital_signs'].forEach((v) {
        vitalSigns!.add(VitalSigns.fromJson(v));
      });
    }
    if (json['blood_tests'] != null) {
      bloodTests = <BloodTest>[];
      json['blood_tests'].forEach((v) {
        bloodTests!.add(BloodTest.fromJson(v));
      });
    }
    if (json['documents'] != null) {
      documents = <MedicalDocument>[];
      json['documents'].forEach((v) {
        documents!.add(MedicalDocument.fromJson(v));
      });
    }
  }

  Map<String, dynamic> toJson() {
    final Map<String, dynamic> data = <String, dynamic>{};
    if (vitalSigns != null) {
      data['vital_signs'] = vitalSigns!.map((v) => v.toJson()).toList();
    }
    if (bloodTests != null) {
      data['blood_tests'] = bloodTests!.map((v) => v.toJson()).toList();
    }
    if (documents != null) {
      data['documents'] = documents!.map((v) => v.toJson()).toList();
    }
    return data;
  }
}

class VitalSigns {
  int? id;
  String? type; // 'blood_pressure', 'heart_rate', 'temperature', 'weight', 'blood_sugar'
  double? value;
  double? systolic; // For blood pressure
  double? diastolic; // For blood pressure
  String? unit;
  String? status; // 'normal', 'high', 'low', 'critical'
  DateTime? recordedAt;
  String? notes;
  bool? isActive;

  VitalSigns({
    this.id,
    this.type,
    this.value,
    this.systolic,
    this.diastolic,
    this.unit,
    this.status,
    this.recordedAt,
    this.notes,
    this.isActive,
  });

  VitalSigns.fromJson(Map<String, dynamic> json) {
    id = json['id'];
    type = json['type'];
    value = json['value']?.toDouble();
    systolic = json['systolic']?.toDouble();
    diastolic = json['diastolic']?.toDouble();
    unit = json['unit'];
    status = json['status'];
    recordedAt = json['recorded_at'] != null 
        ? DateTime.parse(json['recorded_at']) 
        : null;
    notes = json['notes'];
    isActive = json['is_active'];
  }

  Map<String, dynamic> toJson() {
    final Map<String, dynamic> data = <String, dynamic>{};
    data['id'] = id;
    data['type'] = type;
    data['value'] = value;
    data['systolic'] = systolic;
    data['diastolic'] = diastolic;
    data['unit'] = unit;
    data['status'] = status;
    data['recorded_at'] = recordedAt?.toIso8601String();
    data['notes'] = notes;
    data['is_active'] = isActive;
    return data;
  }

  String get displayValue {
    switch (type) {
      case 'blood_pressure':
        return '${systolic?.toInt()}/${diastolic?.toInt()}';
      case 'heart_rate':
        return '${value?.toInt()} bpm';
      case 'temperature':
        return '${value?.toStringAsFixed(1)}°C';
      case 'weight':
        return '${value?.toStringAsFixed(1)} kg';
      case 'blood_sugar':
        return '${value?.toInt()} mg/dL';
      default:
        return '${value?.toStringAsFixed(1)} ${unit ?? ''}';
    }
  }

  Color get statusColor {
    switch (status) {
      case 'normal':
        return Colors.green;
      case 'high':
        return Colors.orange;
      case 'low':
        return Colors.blue;
      case 'critical':
        return Colors.red;
      default:
        return Colors.grey;
    }
  }
}

class BloodTest {
  int? id;
  String? testName;
  String? testType; // 'cbc', 'lipid_panel', 'glucose', 'hba1c', etc.
  double? value;
  double? minNormal;
  double? maxNormal;
  String? unit;
  String? status; // 'normal', 'high', 'low', 'critical'
  DateTime? testDate;
  String? labName;
  String? notes;
  bool? isActive;

  BloodTest({
    this.id,
    this.testName,
    this.testType,
    this.value,
    this.minNormal,
    this.maxNormal,
    this.unit,
    this.status,
    this.testDate,
    this.labName,
    this.notes,
    this.isActive,
  });

  BloodTest.fromJson(Map<String, dynamic> json) {
    id = json['id'];
    testName = json['test_name'];
    testType = json['test_type'];
    value = json['value']?.toDouble();
    minNormal = json['min_normal']?.toDouble();
    maxNormal = json['max_normal']?.toDouble();
    unit = json['unit'];
    status = json['status'];
    testDate = json['test_date'] != null 
        ? DateTime.parse(json['test_date']) 
        : null;
    labName = json['lab_name'];
    notes = json['notes'];
    isActive = json['is_active'];
  }

  Map<String, dynamic> toJson() {
    final Map<String, dynamic> data = <String, dynamic>{};
    data['id'] = id;
    data['test_name'] = testName;
    data['test_type'] = testType;
    data['value'] = value;
    data['min_normal'] = minNormal;
    data['max_normal'] = maxNormal;
    data['unit'] = unit;
    data['status'] = status;
    data['test_date'] = testDate?.toIso8601String();
    data['lab_name'] = labName;
    data['notes'] = notes;
    data['is_active'] = isActive;
    return data;
  }

  String get displayValue {
    return '${value?.toStringAsFixed(2)} ${unit ?? ''}';
  }

  String get normalRange {
    if (minNormal != null && maxNormal != null) {
      return '${minNormal!.toStringAsFixed(1)}-${maxNormal!.toStringAsFixed(1)} ${unit ?? ''}';
    }
    return 'Range not specified';
  }

  Color get statusColor {
    switch (status) {
      case 'normal':
        return Colors.green;
      case 'high':
        return Colors.orange;
      case 'low':
        return Colors.blue;
      case 'critical':
        return Colors.red;
      default:
        return Colors.grey;
    }
  }
}

class MedicalDocument {
  int? id;
  String? title;
  String? documentType; // 'lab_report', 'prescription', 'scan', 'x_ray', etc.
  String? filePath;
  String? fileName;
  DateTime? uploadedAt;
  String? description;
  bool? isActive;

  MedicalDocument({
    this.id,
    this.title,
    this.documentType,
    this.filePath,
    this.fileName,
    this.uploadedAt,
    this.description,
    this.isActive,
  });

  MedicalDocument.fromJson(Map<String, dynamic> json) {
    id = json['id'];
    title = json['title'];
    documentType = json['document_type'];
    filePath = json['file_path'];
    fileName = json['file_name'];
    uploadedAt = json['uploaded_at'] != null 
        ? DateTime.parse(json['uploaded_at']) 
        : null;
    description = json['description'];
    isActive = json['is_active'];
  }

  Map<String, dynamic> toJson() {
    final Map<String, dynamic> data = <String, dynamic>{};
    data['id'] = id;
    data['title'] = title;
    data['document_type'] = documentType;
    data['file_path'] = filePath;
    data['file_name'] = fileName;
    data['uploaded_at'] = uploadedAt?.toIso8601String();
    data['description'] = description;
    data['is_active'] = isActive;
    return data;
  }
}