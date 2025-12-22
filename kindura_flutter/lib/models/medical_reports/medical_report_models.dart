import 'package:json_annotation/json_annotation.dart';

part 'medical_report_models.g.dart';

/// Uploaded Medical Report Model
@JsonSerializable()
class UploadedMedicalReport {
  final String id;
  @JsonKey(name: 'user')
  final String? userId;
  @JsonKey(name: 'file_name')
  final String fileName;
  @JsonKey(name: 'file_type')
  final String? fileType;
  @JsonKey(name: 'file_url')
  final String? fileUrl;
  @JsonKey(name: 'file_size')
  final int? fileSize;

  @JsonKey(name: 'extracted_text')
  final String? extractedText;
  final Map<String, dynamic>? biomarkers;
  @JsonKey(name: 'doctor_notes')
  final String? doctorNotes;
  final List<String>? diagnoses;

  @JsonKey(name: 'medication_recommendations')
  final List<dynamic>? medicationRecommendationsRaw;

  @JsonKey(name: 'report_date')
  final String? reportDate;
  @JsonKey(name: 'provider_name')
  final String? providerName;
  @JsonKey(name: 'facility_name')
  final String? facilityName;

  final String status;
  @JsonKey(name: 'uploaded_at')
  final String uploadedAt;
  @JsonKey(name: 'reviewed_at')
  final String? reviewedAt;

  @JsonKey(name: 'is_processed')
  final bool isProcessed;
  @JsonKey(name: 'processing_error')
  final String? processingError;

  @JsonKey(name: 'recommendations_count')
  final int? recommendationsCount;
  @JsonKey(name: 'pending_recommendations_count')
  final int? pendingRecommendationsCount;

  final List<MedicationRecommendation>? recommendations;
  @JsonKey(name: 'extracted_biomarkers')
  final List<Biomarker>? extractedBiomarkers;

  UploadedMedicalReport({
    required this.id,
    this.userId,
    required this.fileName,
    this.fileType,
    this.fileUrl,
    this.fileSize,
    this.extractedText,
    this.biomarkers,
    this.doctorNotes,
    this.diagnoses,
    this.medicationRecommendationsRaw,
    this.reportDate,
    this.providerName,
    this.facilityName,
    required this.status,
    required this.uploadedAt,
    this.reviewedAt,
    required this.isProcessed,
    this.processingError,
    this.recommendationsCount,
    this.pendingRecommendationsCount,
    this.recommendations,
    this.extractedBiomarkers,
  });

  factory UploadedMedicalReport.fromJson(Map<String, dynamic> json) =>
      _$UploadedMedicalReportFromJson(json);

  Map<String, dynamic> toJson() => _$UploadedMedicalReportToJson(this);

  bool get hasPendingRecommendations =>
      (pendingRecommendationsCount ?? 0) > 0;

  DateTime? get uploadedAtDate {
    try {
      return DateTime.parse(uploadedAt);
    } catch (e) {
      return null;
    }
  }

  DateTime? get reportDateParsed {
    if (reportDate == null) return null;
    try {
      return DateTime.parse(reportDate!);
    } catch (e) {
      return null;
    }
  }
}

/// Medication Recommendation Model
@JsonSerializable()
class MedicationRecommendation {
  final String id;
  final String report;
  @JsonKey(name: 'user')
  final String? userId;

  @JsonKey(name: 'medication_name')
  final String medicationName;
  @JsonKey(name: 'brand_name')
  final String? brandName;

  @JsonKey(name: 'change_type')
  final String changeType;
  @JsonKey(name: 'old_value')
  final Map<String, dynamic>? oldValue;
  @JsonKey(name: 'new_value')
  final Map<String, dynamic> newValue;

  final String? reason;
  @JsonKey(name: 'clinical_notes')
  final String? clinicalNotes;

  final String status;
  @JsonKey(name: 'created_at')
  final String createdAt;
  @JsonKey(name: 'applied_at')
  final String? appliedAt;
  @JsonKey(name: 'dismissed_at')
  final String? dismissedAt;
  @JsonKey(name: 'dismissal_reason')
  final String? dismissalReason;

  @JsonKey(name: 'applied_medicine')
  final String? appliedMedicineId;

  @JsonKey(name: 'is_urgent')
  final bool isUrgent;
  final int priority;

  @JsonKey(name: 'is_pending')
  final bool? isPending;

  @JsonKey(name: 'report_info')
  final Map<String, dynamic>? reportInfo;

  MedicationRecommendation({
    required this.id,
    required this.report,
    this.userId,
    required this.medicationName,
    this.brandName,
    required this.changeType,
    this.oldValue,
    required this.newValue,
    this.reason,
    this.clinicalNotes,
    required this.status,
    required this.createdAt,
    this.appliedAt,
    this.dismissedAt,
    this.dismissalReason,
    this.appliedMedicineId,
    required this.isUrgent,
    required this.priority,
    this.isPending,
    this.reportInfo,
  });

  factory MedicationRecommendation.fromJson(Map<String, dynamic> json) =>
      _$MedicationRecommendationFromJson(json);

  Map<String, dynamic> toJson() => _$MedicationRecommendationToJson(this);

  String get changeTypeDisplay {
    switch (changeType) {
      case 'new':
        return 'New Medication';
      case 'dosage_change':
        return 'Dosage Change';
      case 'schedule_change':
        return 'Schedule Change';
      case 'frequency_change':
        return 'Frequency Change';
      case 'discontinue':
        return 'Discontinue';
      default:
        return changeType;
    }
  }

  String get newDosage => newValue['dosage']?.toString() ?? '';
  String get newFrequency => newValue['frequency']?.toString() ?? '';
  String get oldDosage => oldValue?['dosage']?.toString() ?? '';
  String get oldFrequency => oldValue?['frequency']?.toString() ?? '';

  DateTime? get createdAtDate {
    try {
      return DateTime.parse(createdAt);
    } catch (e) {
      return null;
    }
  }
}

/// Biomarker Model
@JsonSerializable()
class Biomarker {
  final int? id;
  @JsonKey(name: 'user')
  final String? userId;
  final String? report;

  final String name;
  final double value;
  final String unit;

  @JsonKey(name: 'reference_min')
  final double? referenceMin;
  @JsonKey(name: 'reference_max')
  final double? referenceMax;
  @JsonKey(name: 'is_normal')
  final bool? isNormal;
  final String? flag;

  @JsonKey(name: 'test_date')
  final String testDate;
  final String? notes;

  @JsonKey(name: 'created_at')
  final String? createdAt;
  @JsonKey(name: 'is_out_of_range')
  final bool? isOutOfRange;

  Biomarker({
    this.id,
    this.userId,
    this.report,
    required this.name,
    required this.value,
    required this.unit,
    this.referenceMin,
    this.referenceMax,
    this.isNormal,
    this.flag,
    required this.testDate,
    this.notes,
    this.createdAt,
    this.isOutOfRange,
  });

  factory Biomarker.fromJson(Map<String, dynamic> json) =>
      _$BiomarkerFromJson(json);

  Map<String, dynamic> toJson() => _$BiomarkerToJson(this);

  DateTime? get testDateParsed {
    try {
      return DateTime.parse(testDate);
    } catch (e) {
      return null;
    }
  }

  String get valueDisplay => '$value $unit';

  String get rangeDisplay {
    if (referenceMin != null && referenceMax != null) {
      return '$referenceMin - $referenceMax $unit';
    } else if (referenceMin != null) {
      return '≥ $referenceMin $unit';
    } else if (referenceMax != null) {
      return '≤ $referenceMax $unit';
    }
    return 'N/A';
  }

  String get statusText {
    if (flag == 'H') return 'High';
    if (flag == 'L') return 'Low';
    if (flag == 'N' || isNormal == true) return 'Normal';
    if (isOutOfRange == true) return 'Out of Range';
    return 'Unknown';
  }

  bool get isAbnormal => isOutOfRange == true || (flag != null && flag != 'N');
}

/// API Response wrapper for lists
@JsonSerializable(genericArgumentFactories: true)
class MedicalReportListResponse<T> {
  final bool status;
  final int? count;
  final List<T>? results;
  final String? message;
  final dynamic errors;

  MedicalReportListResponse({
    required this.status,
    this.count,
    this.results,
    this.message,
    this.errors,
  });

  factory MedicalReportListResponse.fromJson(
    Map<String, dynamic> json,
    T Function(Object? json) fromJsonT,
  ) =>
      _$MedicalReportListResponseFromJson(json, fromJsonT);

  Map<String, dynamic> toJson(Object Function(T value) toJsonT) =>
      _$MedicalReportListResponseToJson(this, toJsonT);
}

/// API Response wrapper for single item
@JsonSerializable(genericArgumentFactories: true)
class MedicalReportResponse<T> {
  final bool status;
  final T? result;
  final String? message;
  final dynamic errors;

  MedicalReportResponse({
    required this.status,
    this.result,
    this.message,
    this.errors,
  });

  factory MedicalReportResponse.fromJson(
    Map<String, dynamic> json,
    T Function(Object? json) fromJsonT,
  ) =>
      _$MedicalReportResponseFromJson(json, fromJsonT);

  Map<String, dynamic> toJson(Object Function(T value) toJsonT) =>
      _$MedicalReportResponseToJson(this, toJsonT);
}
