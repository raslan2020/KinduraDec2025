import 'dart:io';
import 'package:kindura_ai/data/network/network_api_services.dart';
import 'package:kindura_ai/res/app_url/app_url.dart';

class MedicalReportsRepository {
  final NetworkApiServices _apiServices = NetworkApiServices();

  // Get all medical reports for the user
  Future<dynamic> getMedicalReports() async {
    return await _apiServices.getApi(AppUrl.medicalReportsUrl);
  }

  // Get vital signs
  Future<dynamic> getVitalSigns({String? dateFrom, String? dateTo}) async {
    String url = AppUrl.vitalSignsUrl;
    
    List<String> queryParams = [];
    if (dateFrom != null) queryParams.add('date_from=$dateFrom');
    if (dateTo != null) queryParams.add('date_to=$dateTo');
    
    if (queryParams.isNotEmpty) {
      url += '?${queryParams.join('&')}';
    }
    
    return await _apiServices.getApi(url);
  }

  // Add new vital signs
  Future<dynamic> addVitalSigns(Map<String, dynamic> data) async {
    return await _apiServices.postApi(data, AppUrl.vitalSignsUrl);
  }

  // Update vital signs
  Future<dynamic> updateVitalSigns(int id, Map<String, dynamic> data) async {
    return await _apiServices.putApi(data, "${AppUrl.vitalSignsUrl}$id/");
  }

  // Delete vital signs
  Future<dynamic> deleteVitalSigns(int id) async {
    return await _apiServices.deleteApi("${AppUrl.vitalSignsUrl}$id/");
  }

  // Get blood tests
  Future<dynamic> getBloodTests({String? dateFrom, String? dateTo}) async {
    String url = AppUrl.bloodTestsUrl;
    
    List<String> queryParams = [];
    if (dateFrom != null) queryParams.add('date_from=$dateFrom');
    if (dateTo != null) queryParams.add('date_to=$dateTo');
    
    if (queryParams.isNotEmpty) {
      url += '?${queryParams.join('&')}';
    }
    
    return await _apiServices.getApi(url);
  }

  // Add new blood test
  Future<dynamic> addBloodTest(Map<String, dynamic> data) async {
    return await _apiServices.postApi(data, AppUrl.bloodTestsUrl);
  }

  // Update blood test
  Future<dynamic> updateBloodTest(int id, Map<String, dynamic> data) async {
    return await _apiServices.putApi(data, "${AppUrl.bloodTestsUrl}$id/");
  }

  // Delete blood test
  Future<dynamic> deleteBloodTest(int id) async {
    return await _apiServices.deleteApi("${AppUrl.bloodTestsUrl}$id/");
  }

  // Upload medical document
  Future<dynamic> uploadMedicalDocument({
    required File file,
    required String title,
    required String documentType,
    String? description,
  }) async {
    Map<String, dynamic> formData = {
      'file': file,
      'title': title,
      'document_type': documentType,
      'description': description ?? '',
    };

    // Use multipart upload for file
    return await _apiServices.postApiMultipart(AppUrl.medicalDocumentsUrl, formData);
  }

  // Get medical documents
  Future<dynamic> getMedicalDocuments() async {
    return await _apiServices.getApi(AppUrl.medicalDocumentsUrl);
  }

  // Delete medical document
  Future<dynamic> deleteMedicalDocument(int id) async {
    return await _apiServices.deleteApi("${AppUrl.medicalDocumentsUrl}$id/");
  }

  // Parse and extract data from uploaded medical report
  Future<dynamic> parseUploadedReport(int documentId) async {
    Map<String, dynamic> data = {'document_id': documentId};
    return await _apiServices.postApi(data, AppUrl.parseReportUrl);
  }

  // Get health summary/dashboard data
  Future<dynamic> getHealthSummary() async {
    return await _apiServices.getApi(AppUrl.healthSummaryUrl);
  }

  // ==================== NEW MEDICAL REPORT UPLOAD SYSTEM ====================

  /// Upload a medical report file with AI processing
  Future<dynamic> uploadReport(File file, {
    String? reportDate,
    String? providerName,
    String? facilityName,
  }) async {
    Map<String, dynamic> formData = {
      'file': file,
    };

    if (reportDate != null) formData['report_date'] = reportDate;
    if (providerName != null) formData['provider_name'] = providerName;
    if (facilityName != null) formData['facility_name'] = facilityName;

    return await _apiServices.postApiMultipart(
      AppUrl.uploadedReportsUrl,
      formData,
    );
  }

  /// Get all uploaded reports for the user
  Future<dynamic> getUserReports() async {
    return await _apiServices.getApi(AppUrl.uploadedReportsUrl);
  }

  /// Get the latest uploaded report with full details
  Future<dynamic> getLatestReport() async {
    return await _apiServices.getApi(AppUrl.uploadedReportsLatestUrl);
  }

  /// Get details of a specific report
  Future<dynamic> getReportDetails(String reportId) async {
    return await _apiServices.getApi(AppUrl.uploadedReportDetailsUrl(reportId));
  }

  /// Reprocess a report with AI
  Future<dynamic> reprocessReport(String reportId) async {
    return await _apiServices.postApi(
      {},
      '${AppUrl.uploadedReportDetailsUrl(reportId)}reprocess/',
    );
  }

  /// Get all pending medication recommendations
  Future<dynamic> getPendingRecommendations() async {
    return await _apiServices.getApi(
      AppUrl.medicationRecommendationsPendingUrl,
    );
  }

  /// Get all medication recommendations (with optional filters)
  Future<dynamic> getRecommendations({
    String? status,
    String? reportId,
  }) async {
    String url = AppUrl.medicationRecommendationsUrl;

    List<String> params = [];
    if (status != null) params.add('status=$status');
    if (reportId != null) params.add('report_id=$reportId');

    if (params.isNotEmpty) {
      url += '?${params.join('&')}';
    }

    return await _apiServices.getApi(url);
  }

  /// Apply a medication recommendation
  Future<dynamic> applyRecommendation(
    String recommendationId, {
    String? medicineId,
  }) async {
    final data = medicineId != null ? {'medicine_id': medicineId} : {};
    return await _apiServices.postApi(
      data,
      AppUrl.applyRecommendationUrl(recommendationId),
    );
  }

  /// Dismiss a medication recommendation
  Future<dynamic> dismissRecommendation(
    String recommendationId, {
    String? reason,
  }) async {
    final data = reason != null ? {'reason': reason} : {};
    return await _apiServices.postApi(
      data,
      AppUrl.dismissRecommendationUrl(recommendationId),
    );
  }

  /// Get user biomarkers
  Future<dynamic> getUserBiomarkers({
    String? biomarkerName,
    String? dateFrom,
    String? dateTo,
  }) async {
    String url = AppUrl.biomarkersUserUrl;

    List<String> params = [];
    if (biomarkerName != null) params.add('name=$biomarkerName');
    if (dateFrom != null) params.add('date_from=$dateFrom');
    if (dateTo != null) params.add('date_to=$dateTo');

    if (params.isNotEmpty) {
      url += '?${params.join('&')}';
    }

    return await _apiServices.getApi(url);
  }

  /// Get biomarker trends for a specific biomarker
  Future<dynamic> getBiomarkerTrends(String biomarkerName) async {
    return await _apiServices.getApi(
      AppUrl.biomarkerTrendsUrl(biomarkerName),
    );
  }

  /// Delete an uploaded report
  Future<dynamic> deleteUploadedReport(String reportId) async {
    return await _apiServices.deleteApi(
      AppUrl.uploadedReportDetailsUrl(reportId),
    );
  }
}