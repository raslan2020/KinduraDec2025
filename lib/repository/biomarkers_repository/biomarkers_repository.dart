import 'package:kindura_ai/data/network/network_api_services.dart';
import 'package:kindura_ai/models/biomarkers/biomarker_models.dart';
import 'package:kindura_ai/data/response/api_response.dart';
import 'package:kindura_ai/res/app_url/app_url.dart';
import 'package:file_picker/file_picker.dart';

class BiomarkersRepository {
  final _apiService = NetworkApiServices();

  // Upload lab document
  Future<ApiResponse<LabDocument>> uploadLabDocument(
    PlatformFile file,
    DocumentType type,
  ) async {
    try {
      final formData = {
        'file': file,
        'type': type.name,
        'patient_id': 'current_patient', // TODO: Get from auth
      };

      final response = await _apiService.postApiMultipart(
        '${AppUrl.baseUrl}/biomarkers/documents/upload/',
        formData,
      );

      if (response['status'] == true) {
        final document = LabDocument.fromJson(response['result']);
        return ApiResponse.completed(document);
      } else {
        return ApiResponse.error(response['message'] ?? 'Upload failed');
      }
    } catch (e) {
      return ApiResponse.error(e.toString());
    }
  }

  // Process document with OCR
  Future<ApiResponse<LabProcessingResult>> processDocument(String documentId) async {
    try {
      final response = await _apiService.postApi(
        {},
        '${AppUrl.baseUrl}/biomarkers/documents/$documentId/process/',
      );

      if (response['status'] == true) {
        final result = LabProcessingResult.fromJson(response['result']);
        return ApiResponse.completed(result);
      } else {
        return ApiResponse.error(response['message'] ?? 'Processing failed');
      }
    } catch (e) {
      return ApiResponse.error(e.toString());
    }
  }

  // Get all biomarkers with latest values
  Future<ApiResponse<List<BiomarkerWithTrend>>> getBiomarkers({
    String? category,
    bool onlyWithData = false,
  }) async {
    try {
      final queryParams = <String, dynamic>{};
      if (category != null) queryParams['category'] = category;
      if (onlyWithData) queryParams['only_with_data'] = 'true';

      final response = await _apiService.getApi(
        AppUrl.biomarkersUserUrl,
        queryParameters: queryParams,
      );

      if (response['status'] == true) {
        final List<dynamic> biomarkersJson = response['result'];
        final biomarkers = biomarkersJson
            .map((json) => BiomarkerWithTrend.fromJson(json))
            .toList();
        return ApiResponse.completed(biomarkers);
      } else {
        return ApiResponse.error(response['message'] ?? 'Failed to load biomarkers');
      }
    } catch (e) {
      return ApiResponse.error(e.toString());
    }
  }

  // Get biomarker categories
  Future<ApiResponse<Map<String, int>>> getBiomarkerCategories() async {
    try {
      final response = await _apiService.getApi('${AppUrl.baseUrl}/biomarkers/categories/');

      if (response['status'] == true) {
        final Map<String, dynamic> categories = response['result'];
        final categoriesWithCount = categories.map(
          (key, value) => MapEntry(key, value as int),
        );
        return ApiResponse.completed(categoriesWithCount);
      } else {
        return ApiResponse.error(response['message'] ?? 'Failed to load categories');
      }
    } catch (e) {
      return ApiResponse.error(e.toString());
    }
  }

  // Get biomarker detail with history
  Future<ApiResponse<BiomarkerWithTrend>> getBiomarkerDetail(
    String biomarkerId, {
    int limitObservations = 50,
  }) async {
    try {
      final response = await _apiService.getApi(
        '${AppUrl.baseUrl}/biomarkers/$biomarkerId/',
        queryParameters: {'limit': limitObservations.toString()},
      );

      if (response['status'] == true) {
        final biomarker = BiomarkerWithTrend.fromJson(response['result']);
        return ApiResponse.completed(biomarker);
      } else {
        return ApiResponse.error(response['message'] ?? 'Failed to load biomarker');
      }
    } catch (e) {
      return ApiResponse.error(e.toString());
    }
  }

  // Add manual observation
  Future<ApiResponse<Observation>> addManualObservation({
    required String biomarkerId,
    required double value,
    required String unit,
    required DateTime collectedAt,
    String? notes,
  }) async {
    try {
      // Format date as YYYY-MM-DD (backend expects this format)
      final dateStr = '${collectedAt.year.toString().padLeft(4, '0')}-${collectedAt.month.toString().padLeft(2, '0')}-${collectedAt.day.toString().padLeft(2, '0')}';
      final data = {
        'biomarker_id': biomarkerId,
        'value': value,
        'unit': unit,
        'collected_at': dateStr,
        if (notes != null) 'notes': notes,
      };

      final response = await _apiService.postApi(
        data,
        '${AppUrl.baseUrl}/biomarkers/observations/manual/',
      );

      if (response['status'] == true) {
        final observation = Observation.fromJson(response['result']);
        return ApiResponse.completed(observation);
      } else {
        return ApiResponse.error(response['message'] ?? 'Failed to add observation');
      }
    } catch (e) {
      return ApiResponse.error(e.toString());
    }
  }

  // Get labs summary for dashboard
  Future<ApiResponse<LabsSummary>> getLabsSummary() async {
    try {
      final response = await _apiService.getApi('${AppUrl.baseUrl}/biomarkers/summary/');

      if (response['status'] == true) {
        final summary = LabsSummary.fromJson(response['result']);
        return ApiResponse.completed(summary);
      } else {
        return ApiResponse.error(response['message'] ?? 'Failed to load summary');
      }
    } catch (e) {
      return ApiResponse.error(e.toString());
    }
  }

  // Get health insights
  Future<ApiResponse<List<HealthInsight>>> getHealthInsights({
    bool activeOnly = true,
  }) async {
    try {
      final response = await _apiService.getApi(
        '${AppUrl.baseUrl}/biomarkers/insights/',
        queryParameters: {
          if (activeOnly) 'active_only': 'true',
        },
      );

      if (response['status'] == true) {
        final List<dynamic> insightsJson = response['result'];
        final insights = insightsJson
            .map((json) => HealthInsight.fromJson(json))
            .toList();
        return ApiResponse.completed(insights);
      } else {
        return ApiResponse.error(response['message'] ?? 'Failed to load insights');
      }
    } catch (e) {
      return ApiResponse.error(e.toString());
    }
  }

  // Dismiss insight
  Future<ApiResponse<void>> dismissInsight(String insightId) async {
    try {
      final response = await _apiService.postApi(
        {},
        '${AppUrl.baseUrl}/biomarkers/insights/$insightId/dismiss/',
      );

      if (response['status'] == true) {
        return ApiResponse.completed(null);
      } else {
        return ApiResponse.error(response['message'] ?? 'Failed to dismiss insight');
      }
    } catch (e) {
      return ApiResponse.error(e.toString());
    }
  }

  // Get lab documents
  Future<ApiResponse<List<LabDocument>>> getLabDocuments({
    DocumentType? type,
    int limit = 20,
    int offset = 0,
  }) async {
    try {
      final queryParams = <String, dynamic>{
        'limit': limit.toString(),
        'offset': offset.toString(),
      };
      if (type != null) queryParams['type'] = type.name;

      final response = await _apiService.getApi(
        '${AppUrl.baseUrl}/biomarkers/documents/',
        queryParameters: queryParams,
      );

      if (response['status'] == true) {
        final List<dynamic> documentsJson = response['result'];
        final documents = documentsJson
            .map((json) => LabDocument.fromJson(json))
            .toList();
        return ApiResponse.completed(documents);
      } else {
        return ApiResponse.error(response['message'] ?? 'Failed to load documents');
      }
    } catch (e) {
      return ApiResponse.error(e.toString());
    }
  }

  // Delete lab document
  Future<ApiResponse<void>> deleteLabDocument(String documentId) async {
    try {
      final response = await _apiService.deleteApi('${AppUrl.baseUrl}/biomarkers/documents/$documentId/');

      if (response['status'] == true) {
        return ApiResponse.completed(null);
      } else {
        return ApiResponse.error(response['message'] ?? 'Failed to delete document');
      }
    } catch (e) {
      return ApiResponse.error(e.toString());
    }
  }

  // Search biomarkers
  Future<ApiResponse<List<BiomarkerDefinition>>> searchBiomarkers(String query) async {
    try {
      final response = await _apiService.getApi(
        '${AppUrl.baseUrl}/biomarkers/search/',
        queryParameters: {'q': query},
      );

      if (response['status'] == true) {
        final List<dynamic> biomarkersJson = response['result'];
        final biomarkers = biomarkersJson
            .map((json) => BiomarkerDefinition.fromJson(json))
            .toList();
        return ApiResponse.completed(biomarkers);
      } else {
        return ApiResponse.error(response['message'] ?? 'Search failed');
      }
    } catch (e) {
      return ApiResponse.error(e.toString());
    }
  }

  // Get FHIR export
  Future<ApiResponse<Map<String, dynamic>>> exportFHIR({
    DateTime? fromDate,
    DateTime? toDate,
  }) async {
    try {
      final queryParams = <String, dynamic>{};
      if (fromDate != null) queryParams['from_date'] = fromDate.toIso8601String();
      if (toDate != null) queryParams['to_date'] = toDate.toIso8601String();

      final response = await _apiService.getApi(
        '${AppUrl.baseUrl}/biomarkers/export/fhir/',
        queryParameters: queryParams,
      );

      if (response['status'] == true) {
        return ApiResponse.completed(response['result']);
      } else {
        return ApiResponse.error(response['message'] ?? 'Export failed');
      }
    } catch (e) {
      return ApiResponse.error(e.toString());
    }
  }

  // Delete all lab data
  Future<ApiResponse<Map<String, int>>> deleteAllLabData() async {
    try {
      final response = await _apiService.deleteApi('${AppUrl.baseUrl}/biomarkers/delete-all/');

      if (response['status'] == true) {
        final deleted = {
          'biomarkers': response['deleted']['biomarkers'] as int,
          'reports': response['deleted']['reports'] as int,
        };
        return ApiResponse.completed(deleted);
      } else {
        return ApiResponse.error(response['message'] ?? 'Failed to delete lab data');
      }
    } catch (e) {
      return ApiResponse.error(e.toString());
    }
  }

  // Reload all reports - re-analyze with latest AI
  Future<ApiResponse<Map<String, dynamic>>> reloadAllReports() async {
    try {
      final response = await _apiService.postApi(
        {},
        '${AppUrl.baseUrl}/biomarkers/reload-all/',
      );

      if (response['status'] == true) {
        final results = response['results'] as Map<String, dynamic>;
        return ApiResponse.completed(results);
      } else {
        return ApiResponse.error(response['message'] ?? 'Failed to reload reports');
      }
    } catch (e) {
      return ApiResponse.error(e.toString());
    }
  }

  // Get AI-generated insights for a specific biomarker
  Future<ApiResponse<BiomarkerAiInsights>> getBiomarkerAiInsights(
    String biomarkerId,
  ) async {
    try {
      final response = await _apiService.getApi(
        '${AppUrl.baseUrl}/biomarkers/$biomarkerId/ai-insights/',
      );

      if (response['status'] == true) {
        final insights = BiomarkerAiInsights.fromJson(response['result']);
        return ApiResponse.completed(insights);
      } else {
        return ApiResponse.error(response['message'] ?? 'Failed to load AI insights');
      }
    } catch (e) {
      return ApiResponse.error(e.toString());
    }
  }

  // ============================================
  // STORED AI HEALTH INSIGHTS (Auto-generated)
  // ============================================

  /// Get stored AI-generated health insights
  /// These are automatically created when lab reports are uploaded
  Future<ApiResponse<StoredHealthInsightsResponse>> getStoredHealthInsights({
    String? severity,
    bool includeDismissed = false,
    String? biomarker,
    String? reportId,
    int limit = 50,
    bool unreadOnly = false,
  }) async {
    try {
      final queryParams = <String, dynamic>{
        'limit': limit.toString(),
      };
      if (severity != null) queryParams['severity'] = severity;
      if (includeDismissed) queryParams['include_dismissed'] = 'true';
      if (biomarker != null) queryParams['biomarker'] = biomarker;
      if (reportId != null) queryParams['report_id'] = reportId;
      if (unreadOnly) queryParams['unread_only'] = 'true';

      final response = await _apiService.getApi(
        AppUrl.storedHealthInsightsUrl,
        queryParameters: queryParams,
      );

      if (response['status'] == true) {
        final List<dynamic> insightsJson = response['result'];
        final insights = insightsJson
            .map((json) => StoredHealthInsight.fromJson(json))
            .toList();
        final summary = StoredInsightsSummary.fromJson(response['summary']);
        return ApiResponse.completed(StoredHealthInsightsResponse(
          insights: insights,
          summary: summary,
        ));
      } else {
        return ApiResponse.error(response['message'] ?? 'Failed to load stored insights');
      }
    } catch (e) {
      return ApiResponse.error(e.toString());
    }
  }

  /// Mark an insight as read
  Future<ApiResponse<void>> markInsightAsRead(String insightId) async {
    try {
      final response = await _apiService.postApi(
        {},
        AppUrl.markInsightReadUrl(insightId),
      );

      if (response['status'] == true) {
        return ApiResponse.completed(null);
      } else {
        return ApiResponse.error(response['message'] ?? 'Failed to mark insight as read');
      }
    } catch (e) {
      return ApiResponse.error(e.toString());
    }
  }

  /// Dismiss a stored health insight
  Future<ApiResponse<void>> dismissStoredInsight(String insightId) async {
    try {
      final response = await _apiService.postApi(
        {},
        AppUrl.dismissInsightUrl(insightId),
      );

      if (response['status'] == true) {
        return ApiResponse.completed(null);
      } else {
        return ApiResponse.error(response['message'] ?? 'Failed to dismiss insight');
      }
    } catch (e) {
      return ApiResponse.error(e.toString());
    }
  }

  /// Regenerate insights for a specific report
  Future<ApiResponse<int>> regenerateReportInsights(String reportId) async {
    try {
      final response = await _apiService.postApi(
        {},
        AppUrl.regenerateReportInsightsUrl(reportId),
      );

      if (response['status'] == true) {
        final insightsGenerated = response['insightsGenerated'] as int;
        return ApiResponse.completed(insightsGenerated);
      } else {
        return ApiResponse.error(response['message'] ?? 'Failed to regenerate insights');
      }
    } catch (e) {
      return ApiResponse.error(e.toString());
    }
  }

  // ======== OBSERVATION CRUD METHODS ========

  /// Update an existing observation
  Future<ApiResponse<void>> updateObservation({
    required String observationId,
    required double value,
    required DateTime collectedAt,
    String? notes,
  }) async {
    try {
      // Format date as YYYY-MM-DD (backend expects this format)
      final dateStr = '${collectedAt.year.toString().padLeft(4, '0')}-${collectedAt.month.toString().padLeft(2, '0')}-${collectedAt.day.toString().padLeft(2, '0')}';
      final data = {
        'value_num': value,
        'collected_at': dateStr,
        if (notes != null) 'notes': notes,
      };

      final response = await _apiService.patchApi(
        data,
        '${AppUrl.baseUrl}/biomarkers/observations/$observationId/',
      );

      if (response['status'] == true) {
        return ApiResponse.completed(null);
      } else {
        return ApiResponse.error(response['message'] ?? 'Failed to update observation');
      }
    } catch (e) {
      return ApiResponse.error(e.toString());
    }
  }

  /// Delete an observation
  Future<ApiResponse<void>> deleteObservation(String observationId) async {
    try {
      final response = await _apiService.deleteApi(
        '${AppUrl.baseUrl}/biomarkers/observations/$observationId/',
      );

      if (response['status'] == true) {
        return ApiResponse.completed(null);
      } else {
        return ApiResponse.error(response['message'] ?? 'Failed to delete observation');
      }
    } catch (e) {
      return ApiResponse.error(e.toString());
    }
  }
}