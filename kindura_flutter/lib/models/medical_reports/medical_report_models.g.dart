// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'medical_report_models.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

UploadedMedicalReport _$UploadedMedicalReportFromJson(
        Map<String, dynamic> json) =>
    UploadedMedicalReport(
      id: json['id'] as String,
      userId: json['user'] as String?,
      fileName: json['file_name'] as String,
      fileType: json['file_type'] as String?,
      fileUrl: json['file_url'] as String?,
      fileSize: (json['file_size'] as num?)?.toInt(),
      extractedText: json['extracted_text'] as String?,
      biomarkers: json['biomarkers'] as Map<String, dynamic>?,
      doctorNotes: json['doctor_notes'] as String?,
      diagnoses: (json['diagnoses'] as List<dynamic>?)
          ?.map((e) => e as String)
          .toList(),
      medicationRecommendationsRaw:
          json['medication_recommendations'] as List<dynamic>?,
      reportDate: json['report_date'] as String?,
      providerName: json['provider_name'] as String?,
      facilityName: json['facility_name'] as String?,
      status: json['status'] as String,
      uploadedAt: json['uploaded_at'] as String,
      reviewedAt: json['reviewed_at'] as String?,
      isProcessed: json['is_processed'] as bool,
      processingError: json['processing_error'] as String?,
      recommendationsCount: (json['recommendations_count'] as num?)?.toInt(),
      pendingRecommendationsCount:
          (json['pending_recommendations_count'] as num?)?.toInt(),
      recommendations: (json['recommendations'] as List<dynamic>?)
          ?.map((e) =>
              MedicationRecommendation.fromJson(e as Map<String, dynamic>))
          .toList(),
      extractedBiomarkers: (json['extracted_biomarkers'] as List<dynamic>?)
          ?.map((e) => Biomarker.fromJson(e as Map<String, dynamic>))
          .toList(),
    );

Map<String, dynamic> _$UploadedMedicalReportToJson(
        UploadedMedicalReport instance) =>
    <String, dynamic>{
      'id': instance.id,
      'user': instance.userId,
      'file_name': instance.fileName,
      'file_type': instance.fileType,
      'file_url': instance.fileUrl,
      'file_size': instance.fileSize,
      'extracted_text': instance.extractedText,
      'biomarkers': instance.biomarkers,
      'doctor_notes': instance.doctorNotes,
      'diagnoses': instance.diagnoses,
      'medication_recommendations': instance.medicationRecommendationsRaw,
      'report_date': instance.reportDate,
      'provider_name': instance.providerName,
      'facility_name': instance.facilityName,
      'status': instance.status,
      'uploaded_at': instance.uploadedAt,
      'reviewed_at': instance.reviewedAt,
      'is_processed': instance.isProcessed,
      'processing_error': instance.processingError,
      'recommendations_count': instance.recommendationsCount,
      'pending_recommendations_count': instance.pendingRecommendationsCount,
      'recommendations': instance.recommendations,
      'extracted_biomarkers': instance.extractedBiomarkers,
    };

MedicationRecommendation _$MedicationRecommendationFromJson(
        Map<String, dynamic> json) =>
    MedicationRecommendation(
      id: json['id'] as String,
      report: json['report'] as String,
      userId: json['user'] as String?,
      medicationName: json['medication_name'] as String,
      brandName: json['brand_name'] as String?,
      changeType: json['change_type'] as String,
      oldValue: json['old_value'] as Map<String, dynamic>?,
      newValue: json['new_value'] as Map<String, dynamic>,
      reason: json['reason'] as String?,
      clinicalNotes: json['clinical_notes'] as String?,
      status: json['status'] as String,
      createdAt: json['created_at'] as String,
      appliedAt: json['applied_at'] as String?,
      dismissedAt: json['dismissed_at'] as String?,
      dismissalReason: json['dismissal_reason'] as String?,
      appliedMedicineId: json['applied_medicine'] as String?,
      isUrgent: json['is_urgent'] as bool,
      priority: (json['priority'] as num).toInt(),
      isPending: json['is_pending'] as bool?,
      reportInfo: json['report_info'] as Map<String, dynamic>?,
    );

Map<String, dynamic> _$MedicationRecommendationToJson(
        MedicationRecommendation instance) =>
    <String, dynamic>{
      'id': instance.id,
      'report': instance.report,
      'user': instance.userId,
      'medication_name': instance.medicationName,
      'brand_name': instance.brandName,
      'change_type': instance.changeType,
      'old_value': instance.oldValue,
      'new_value': instance.newValue,
      'reason': instance.reason,
      'clinical_notes': instance.clinicalNotes,
      'status': instance.status,
      'created_at': instance.createdAt,
      'applied_at': instance.appliedAt,
      'dismissed_at': instance.dismissedAt,
      'dismissal_reason': instance.dismissalReason,
      'applied_medicine': instance.appliedMedicineId,
      'is_urgent': instance.isUrgent,
      'priority': instance.priority,
      'is_pending': instance.isPending,
      'report_info': instance.reportInfo,
    };

Biomarker _$BiomarkerFromJson(Map<String, dynamic> json) => Biomarker(
      id: (json['id'] as num?)?.toInt(),
      userId: json['user'] as String?,
      report: json['report'] as String?,
      name: json['name'] as String,
      value: (json['value'] as num).toDouble(),
      unit: json['unit'] as String,
      referenceMin: (json['reference_min'] as num?)?.toDouble(),
      referenceMax: (json['reference_max'] as num?)?.toDouble(),
      isNormal: json['is_normal'] as bool?,
      flag: json['flag'] as String?,
      testDate: json['test_date'] as String,
      notes: json['notes'] as String?,
      createdAt: json['created_at'] as String?,
      isOutOfRange: json['is_out_of_range'] as bool?,
    );

Map<String, dynamic> _$BiomarkerToJson(Biomarker instance) => <String, dynamic>{
      'id': instance.id,
      'user': instance.userId,
      'report': instance.report,
      'name': instance.name,
      'value': instance.value,
      'unit': instance.unit,
      'reference_min': instance.referenceMin,
      'reference_max': instance.referenceMax,
      'is_normal': instance.isNormal,
      'flag': instance.flag,
      'test_date': instance.testDate,
      'notes': instance.notes,
      'created_at': instance.createdAt,
      'is_out_of_range': instance.isOutOfRange,
    };

MedicalReportListResponse<T> _$MedicalReportListResponseFromJson<T>(
  Map<String, dynamic> json,
  T Function(Object? json) fromJsonT,
) =>
    MedicalReportListResponse<T>(
      status: json['status'] as bool,
      count: (json['count'] as num?)?.toInt(),
      results: (json['results'] as List<dynamic>?)?.map(fromJsonT).toList(),
      message: json['message'] as String?,
      errors: json['errors'],
    );

Map<String, dynamic> _$MedicalReportListResponseToJson<T>(
  MedicalReportListResponse<T> instance,
  Object? Function(T value) toJsonT,
) =>
    <String, dynamic>{
      'status': instance.status,
      'count': instance.count,
      'results': instance.results?.map(toJsonT).toList(),
      'message': instance.message,
      'errors': instance.errors,
    };

MedicalReportResponse<T> _$MedicalReportResponseFromJson<T>(
  Map<String, dynamic> json,
  T Function(Object? json) fromJsonT,
) =>
    MedicalReportResponse<T>(
      status: json['status'] as bool,
      result: _$nullableGenericFromJson(json['result'], fromJsonT),
      message: json['message'] as String?,
      errors: json['errors'],
    );

Map<String, dynamic> _$MedicalReportResponseToJson<T>(
  MedicalReportResponse<T> instance,
  Object? Function(T value) toJsonT,
) =>
    <String, dynamic>{
      'status': instance.status,
      'result': _$nullableGenericToJson(instance.result, toJsonT),
      'message': instance.message,
      'errors': instance.errors,
    };

T? _$nullableGenericFromJson<T>(
  Object? input,
  T Function(Object? json) fromJson,
) =>
    input == null ? null : fromJson(input);

Object? _$nullableGenericToJson<T>(
  T? input,
  Object? Function(T value) toJson,
) =>
    input == null ? null : toJson(input);
