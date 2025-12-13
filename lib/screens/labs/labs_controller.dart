import 'dart:io';
import 'package:get/get.dart';
import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:kindura_ai/repository/biomarkers_repository/biomarkers_repository.dart';
import 'package:kindura_ai/repository/medical_reports_repository/medical_reports_repository.dart';
import 'package:kindura_ai/models/biomarkers/biomarker_models.dart';
import 'package:kindura_ai/data/response/status.dart';
import 'package:kindura_ai/data/response/api_response_extensions.dart';
import 'package:kindura_ai/utils/app_toast.dart';

class LabsController extends GetxController {
  final BiomarkersRepository _repository = BiomarkersRepository();

  // Observable states
  var requestStatus = Status.COMPLETED.obs;
  var uploadStatus = Status.COMPLETED.obs;
  var aiInsightsStatus = Status.COMPLETED.obs;

  // Data
  var labsSummary = Rxn<LabsSummary>();
  var biomarkers = <BiomarkerWithTrend>[].obs;
  var categories = <String, int>{}.obs;
  var healthInsights = <HealthInsight>[].obs;
  var labDocuments = <LabDocument>[].obs;
  var biomarkerAiInsights = Rxn<BiomarkerAiInsights>();

  // Filters and UI state
  var selectedCategory = 'all'.obs;
  var showOnlyAbnormal = false.obs;
  var showLatestFirst = true.obs;  // Default to showing latest first
  var showDueForRepetition = false.obs;
  var searchQuery = ''.obs;
  var selectedBiomarker = Rxn<BiomarkerWithTrend>();

  // Computed properties
  List<BiomarkerWithTrend> get filteredBiomarkers {
    var filtered = biomarkers.where((biomarker) {
      // Category filter
      if (selectedCategory.value != 'all' && 
          biomarker.definition.category.toLowerCase() != selectedCategory.value.toLowerCase()) {
        return false;
      }
      
      // Abnormal filter
      if (showOnlyAbnormal.value) {
        final hasAbnormal = biomarker.latestObservation?.status != ResultStatus.normal;
        if (!hasAbnormal) return false;
      }

      // Due for repetition filter
      if (showDueForRepetition.value) {
        // TODO: Implement OpenAI recommendation for test repetition
        // For now, flag tests older than 6 months or marked for repeat
        final lastObservation = biomarker.latestObservation;
        if (lastObservation == null) return true; // No data = needs test

        final daysSinceTest = DateTime.now().difference(lastObservation.collectedAt).inDays;
        // Consider test due for repeat if > 180 days (6 months)
        // This should be replaced with OpenAI recommendation logic
        if (daysSinceTest < 180) return false;
      }

      // Search filter
      if (searchQuery.value.isNotEmpty) {
        final query = searchQuery.value.toLowerCase();
        final matchesName = biomarker.definition.name.toLowerCase().contains(query);
        final matchesAlternatives = biomarker.definition.alternativeNames
            .any((name) => name.toLowerCase().contains(query));
        if (!matchesName && !matchesAlternatives) return false;
      }

      return true;
    }).toList();

    // Sort based on filter selection
    if (showLatestFirst.value) {
      // Sort by latest observation date (most recent first)
      filtered.sort((a, b) {
        final aDate = a.latestObservation?.collectedAt ?? DateTime(1900);
        final bDate = b.latestObservation?.collectedAt ?? DateTime(1900);
        return bDate.compareTo(aDate); // Most recent first
      });
    } else {
      // Sort by status priority: critical > high/low > normal
      filtered.sort((a, b) {
        final aStatus = a.latestObservation?.status ?? ResultStatus.unknown;
        final bStatus = b.latestObservation?.status ?? ResultStatus.unknown;

        final aPriority = _getStatusPriority(aStatus);
        final bPriority = _getStatusPriority(bStatus);

        if (aPriority != bPriority) {
          return bPriority.compareTo(aPriority); // Higher priority first
        }

        // If same priority, sort alphabetically
        return a.definition.name.compareTo(b.definition.name);
      });
    }

    return filtered;
  }

  Map<String, List<BiomarkerWithTrend>> get biomarkersByCategory {
    final grouped = <String, List<BiomarkerWithTrend>>{};

    for (final biomarker in filteredBiomarkers) {
      final category = biomarker.categoryDisplayName;
      grouped.putIfAbsent(category, () => []).add(biomarker);
    }

    return grouped;
  }

  /// Get biomarkers that are due for repeat testing
  /// Tests older than 6 months or with abnormal results that need follow-up
  List<BiomarkerWithTrend> get biomarkersDueForRepeat {
    return biomarkers.where((biomarker) {
      final lastObservation = biomarker.latestObservation;

      // No data = needs initial test
      if (lastObservation == null) return true;

      final daysSinceTest = DateTime.now().difference(lastObservation.collectedAt).inDays;

      // Critical or abnormal results need follow-up sooner (3 months)
      if (lastObservation.status == ResultStatus.criticalLow ||
          lastObservation.status == ResultStatus.criticalHigh) {
        return daysSinceTest >= 90;
      }

      // Abnormal results need follow-up in 4-6 months
      if (lastObservation.status == ResultStatus.high ||
          lastObservation.status == ResultStatus.low) {
        return daysSinceTest >= 120;
      }

      // Normal results - standard 6-12 month interval
      return daysSinceTest >= 180;
    }).toList()
      ..sort((a, b) {
        // Sort by urgency: no data first, then by days since test (oldest first)
        final aDate = a.latestObservation?.collectedAt;
        final bDate = b.latestObservation?.collectedAt;

        if (aDate == null && bDate == null) return 0;
        if (aDate == null) return -1;
        if (bDate == null) return 1;

        return aDate.compareTo(bDate); // Oldest first
      });
  }

  int _getStatusPriority(ResultStatus status) {
    switch (status) {
      case ResultStatus.criticalLow:
      case ResultStatus.criticalHigh:
        return 4;
      case ResultStatus.high:
      case ResultStatus.low:
        return 3;
      case ResultStatus.normal:
        return 2;
      case ResultStatus.unknown:
        return 1;
    }
  }

  @override
  void onInit() {
    super.onInit();
    loadLabsData();
  }

  // Load all labs data
  Future<void> loadLabsData() async {
    requestStatus.value = Status.LOADING;
    
    try {
      // Load in parallel
      await Future.wait([
        _loadLabsSummary(),
        _loadBiomarkers(),
        _loadCategories(),
        _loadHealthInsights(),
        _loadLabDocuments(),
      ]);
      
      requestStatus.value = Status.COMPLETED;
    } catch (e) {
      requestStatus.value = Status.ERROR;
      AppToast.showToast('Failed to load labs data');
    }
  }

  Future<void> _loadLabsSummary() async {
    try {
      final response = await _repository.getLabsSummary();
      response.when(
        success: (summary) => labsSummary.value = summary,
        error: (error) {
          print('Failed to load labs summary from API: $error');
          // Build summary from loaded biomarkers as fallback
          _buildSummaryFromBiomarkers();
        },
        loading: () => print('Loading labs summary...'),
      );
    } catch (e) {
      print('Error loading labs summary: $e');
      // Build summary from loaded biomarkers as fallback
      _buildSummaryFromBiomarkers();
    }
  }

  /// Build summary from loaded biomarkers when API fails
  void _buildSummaryFromBiomarkers() {
    final allBiomarkers = biomarkers;

    // Count abnormal and critical values
    int abnormalCount = 0;
    int criticalCount = 0;
    int recentTestsCount = 0;
    final thirtyDaysAgo = DateTime.now().subtract(const Duration(days: 30));

    for (final biomarker in allBiomarkers) {
      if (biomarker.hasData) {
        final status = biomarker.latestObservation?.status;
        if (status == ResultStatus.high || status == ResultStatus.low) {
          abnormalCount++;
        }
        if (status == ResultStatus.criticalHigh || status == ResultStatus.criticalLow) {
          criticalCount++;
        }
        // Count recent tests
        if (biomarker.latestObservation!.collectedAt.isAfter(thirtyDaysAgo)) {
          recentTestsCount++;
        }
      }
    }

    // Get featured biomarkers (top 3 with data)
    final featured = allBiomarkers.where((b) => b.hasData).take(3).toList();

    labsSummary.value = LabsSummary(
      totalBiomarkers: allBiomarkers.length,
      abnormalCount: abnormalCount,
      criticalCount: criticalCount,
      recentTestsCount: recentTestsCount,
      featuredBiomarkers: featured,
      activeInsights: healthInsights.take(5).toList(),
      lastUpdated: DateTime.now(),
    );
  }

  /// Rebuild summary when biomarkers change
  void updateSummaryFromBiomarkers() {
    if (labsSummary.value?.totalBiomarkers == 0 && biomarkers.isNotEmpty) {
      _buildSummaryFromBiomarkers();
    }
  }

  Future<void> _loadBiomarkers() async {
    final response = await _repository.getBiomarkers();
    response.when(
      success: (biomarkersList) {
        biomarkers.value = biomarkersList;
        // Rebuild summary from biomarkers if it was empty
        updateSummaryFromBiomarkers();
      },
      error: (error) => print('Failed to load biomarkers: $error'),
      loading: () => print('Loading biomarkers...'),
    );
  }

  Future<void> _loadCategories() async {
    final response = await _repository.getBiomarkerCategories();
    response.when(
      success: (categoriesList) => categories.value = categoriesList,
      error: (error) => print('Failed to load categories: $error'),
      loading: () => print('Loading categories...'),
    );
  }

  Future<void> _loadHealthInsights() async {
    final response = await _repository.getHealthInsights();
    response.when(
      success: (insights) => healthInsights.value = insights,
      error: (error) => print('Failed to load insights: $error'),
      loading: () => print('Loading insights...'),
    );
  }

  Future<void> _loadLabDocuments() async {
    // Use medical reports repository to fetch uploaded reports
    // Lab reports and medical documents use the same backend endpoint
    try {
      final response = await MedicalReportsRepository().getUserReports();

      if (response != null && response['status'] == true) {
        final List<dynamic> reportsJson = response['result'] ?? [];
        // Convert to LabDocument format for compatibility
        final documents = reportsJson.map((json) => LabDocument(
          id: json['id']?.toString() ?? '',
          patientId: json['patient_id']?.toString() ?? '',
          storagePath: json['file_path'] ?? '',
          uploadedAt: json['uploaded_at'] != null ? DateTime.parse(json['uploaded_at']) : DateTime.now(),
          status: ProcessingStatus.parsed,
          type: DocumentType.lab,
          originalFileName: json['file_name'] ?? '',
          mimeType: json['file_type'] ?? '',
        )).toList();

        labDocuments.value = documents;
      }
    } catch (e) {
      print('Failed to load lab documents: $e');
    }
  }

  // Upload lab document (supports multiple files)
  Future<void> uploadLabDocument() async {
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['pdf', 'jpg', 'jpeg', 'png'],
        allowMultiple: true,  // Allow multiple file selection
      );

      if (result != null && result.files.isNotEmpty) {
        // If only one file, process it directly
        if (result.files.length == 1) {
          await _processUploadedFile(result.files.first);
        } else {
          // Process multiple files
          await _processMultipleFiles(result.files);
        }
      }
    } catch (e) {
      AppToast.showToast('Failed to pick file');
    }
  }

  Future<void> _processMultipleFiles(List<PlatformFile> files) async {
    uploadStatus.value = Status.LOADING;

    int successCount = 0;
    int failedCount = 0;

    AppToast.showToast('Uploading ${files.length} lab document(s)...');

    for (int i = 0; i < files.length; i++) {
      final file = files[i];

      if (file.path == null) {
        failedCount++;
        continue;
      }

      try {
        print('📄 Uploading file ${i + 1}/${files.length}: ${file.name}');

        final fileToUpload = File(file.path!);
        final response = await MedicalReportsRepository().uploadReport(fileToUpload);

        if (response != null && response['status'] == true) {
          successCount++;
          print('✅ Successfully uploaded: ${file.name}');
        } else {
          failedCount++;
          print('❌ Failed to upload: ${file.name}');
        }
      } catch (e) {
        failedCount++;
        print('❌ Exception uploading ${file.name}: $e');
      }

      // Small delay between uploads
      if (i < files.length - 1) {
        await Future.delayed(const Duration(milliseconds: 500));
      }
    }

    // Show result
    if (failedCount == 0) {
      AppToast.showToast('All $successCount document(s) uploaded successfully!');
    } else if (successCount == 0) {
      AppToast.showToast('All uploads failed');
    } else {
      AppToast.showToast('$successCount uploaded, $failedCount failed');
    }

    // Reload data
    if (successCount > 0) {
      await loadLabsData();
    }

    uploadStatus.value = Status.COMPLETED;
  }

  Future<void> _processUploadedFile(PlatformFile file) async {
    if (file.path == null) {
      AppToast.showToast('File path not available');
      return;
    }

    uploadStatus.value = Status.LOADING;
    AppToast.showToast('Uploading and processing lab document with AI...');

    try {
      final fileToUpload = File(file.path!);

      // Use the medical reports repository for unified upload
      // This uploads to /api/uploaded-reports/ which handles lab reports
      final response = await MedicalReportsRepository().uploadReport(fileToUpload);

      if (response != null && response['status'] == true) {
        AppToast.showToast('Lab document uploaded and processed successfully');

        // Reload labs data to show extracted biomarkers
        await loadLabsData();
      } else {
        final errorMsg = response?['error'] ?? response?['message'] ?? 'Upload failed';
        AppToast.showToast('Upload failed: $errorMsg');
      }
    } catch (e) {
      AppToast.showToast('Upload error: ${e.toString()}');
      print('❌ [LAB_UPLOAD] Error: $e');
    } finally {
      uploadStatus.value = Status.COMPLETED;
    }
  }

  // Add manual observation
  Future<void> addManualObservation({
    required String biomarkerId,
    required double value,
    required String unit,
    DateTime? collectedAt,
    String? notes,
  }) async {
    try {
      final response = await _repository.addManualObservation(
        biomarkerId: biomarkerId,
        value: value,
        unit: unit,
        collectedAt: collectedAt ?? DateTime.now(),
        notes: notes,
      );

      response.when(
        success: (observation) {
          AppToast.showToast('Observation added successfully');
          loadLabsData(); // Reload to show new data
        },
        error: (error) {
          AppToast.showToast('Failed to add observation: $error');
        },
        loading: () => print('Adding observation...'),
      );
    } catch (e) {
      AppToast.showToast('Failed to add observation');
    }
  }

  // Load biomarker detail
  Future<void> loadBiomarkerDetail(String biomarkerId) async {
    try {
      final response = await _repository.getBiomarkerDetail(biomarkerId);
      response.when(
        success: (biomarker) => selectedBiomarker.value = biomarker,
        error: (error) => AppToast.showToast('Failed to load biomarker details'),
        loading: () => print('Loading biomarker details...'),
      );
    } catch (e) {
      AppToast.showToast('Failed to load biomarker details');
    }
  }

  // Load AI-generated insights for a biomarker
  Future<void> loadBiomarkerAiInsights(String biomarkerId) async {
    aiInsightsStatus.value = Status.LOADING;
    biomarkerAiInsights.value = null;

    try {
      final response = await _repository.getBiomarkerAiInsights(biomarkerId);
      response.when(
        success: (insights) {
          biomarkerAiInsights.value = insights;
          aiInsightsStatus.value = Status.COMPLETED;
        },
        error: (error) {
          print('Failed to load AI insights: $error');
          aiInsightsStatus.value = Status.ERROR;
        },
        loading: () => print('Loading AI insights...'),
      );
    } catch (e) {
      print('Error loading AI insights: $e');
      aiInsightsStatus.value = Status.ERROR;
    }
  }

  // Clear AI insights when leaving detail screen
  void clearBiomarkerAiInsights() {
    biomarkerAiInsights.value = null;
    aiInsightsStatus.value = Status.COMPLETED;
  }

  // Dismiss insight
  Future<void> dismissInsight(String insightId) async {
    try {
      final response = await _repository.dismissInsight(insightId);
      response.when(
        success: (_) {
          // Remove from local list
          healthInsights.removeWhere((insight) => insight.id == insightId);
          AppToast.showToast('Insight dismissed');
        },
        error: (error) {
          AppToast.showToast('Failed to dismiss insight');
        },
        loading: () => print('Dismissing insight...'),
      );
    } catch (e) {
      AppToast.showToast('Failed to dismiss insight');
    }
  }

  // Update filters
  void setCategory(String category) {
    selectedCategory.value = category;
  }

  void toggleAbnormalFilter() {
    showOnlyAbnormal.value = !showOnlyAbnormal.value;
  }

  void toggleLatestFilter() {
    showLatestFirst.value = !showLatestFirst.value;
  }

  void toggleDueForRepetitionFilter() {
    showDueForRepetition.value = !showDueForRepetition.value;
    // TODO: When enabled, this should fetch OpenAI recommendations for which tests
    // are due for repetition based on:
    // - Test type and standard retest intervals
    // - Patient's medical history and conditions
    // - Previous abnormal results that need follow-up
    // - Age and risk factors
    if (showDueForRepetition.value) {
      print('📋 Due for Repetition filter enabled - placeholder for OpenAI recommendations');
    }
  }

  void updateSearchQuery(String query) {
    searchQuery.value = query;
  }

  // Get status color for biomarker
  Color getStatusColor(ResultStatus status) {
    switch (status) {
      case ResultStatus.criticalLow:
      case ResultStatus.criticalHigh:
        return Colors.red.shade700;
      case ResultStatus.high:
      case ResultStatus.low:
        return Colors.orange.shade600;
      case ResultStatus.normal:
        return Colors.green.shade600;
      case ResultStatus.unknown:
        return Colors.grey.shade500;
    }
  }

  // Get status display text
  String getStatusText(ResultStatus status) {
    switch (status) {
      case ResultStatus.criticalLow:
        return 'Critical Low';
      case ResultStatus.criticalHigh:
        return 'Critical High';
      case ResultStatus.high:
        return 'High';
      case ResultStatus.low:
        return 'Low';
      case ResultStatus.normal:
        return 'Normal';
      case ResultStatus.unknown:
        return 'Unknown';
    }
  }

  // Get insight severity color
  Color getInsightSeverityColor(InsightSeverity severity) {
    switch (severity) {
      case InsightSeverity.info:
        return Colors.blue;
      case InsightSeverity.warning:
        return Colors.orange;
      case InsightSeverity.urgent:
        return Colors.red.shade400;
      case InsightSeverity.critical:
        return Colors.red.shade700;
    }
  }

  // Export data
  Future<void> exportFHIR({DateTime? fromDate, DateTime? toDate}) async {
    try {
      final response = await _repository.exportFHIR(
        fromDate: fromDate,
        toDate: toDate,
      );

      response.when(
        success: (data) {
          AppToast.showToast('Data exported successfully');
          // TODO: Handle FHIR export (save file, share, etc.)
        },
        error: (error) {
          AppToast.showToast('Export failed: $error');
        },
        loading: () => print('Exporting data...'),
      );
    } catch (e) {
      AppToast.showToast('Export failed');
    }
  }

  // AI Agent Tool Functions for Lab Results Integration
  
  /// Get labs summary for AI agent queries
  /// Returns: {"status": "success|error", "data": {...}, "message": "..."}
  Future<Map<String, dynamic>> getLabsSummaryForAgent() async {
    try {
      final summary = labsSummary.value;
      if (summary == null) {
        await _loadLabsSummary();
      }
      
      final currentSummary = labsSummary.value;
      if (currentSummary == null) {
        return {
          'status': 'error',
          'message': 'No lab data available',
          'data': null,
        };
      }

      return {
        'status': 'success',
        'message': 'Lab summary retrieved successfully',
        'data': {
          'totalBiomarkers': currentSummary.totalBiomarkers,
          'abnormalCount': currentSummary.abnormalCount,
          'criticalCount': currentSummary.criticalCount,
          'recentTestsCount': currentSummary.recentTestsCount,
          'lastUpdated': currentSummary.lastUpdated.toIso8601String(),
          'activeInsights': currentSummary.activeInsights.map((insight) => {
            'id': insight.id,
            'title': insight.title,
            'severity': insight.severity.name,
            'description': insight.description,
            'actionRecommendation': insight.actionRecommendation,
          }).toList(),
          'featuredBiomarkers': currentSummary.featuredBiomarkers.map((biomarker) => {
            'name': biomarker.definition.name,
            'category': biomarker.categoryDisplayName,
            'latestValue': biomarker.latestObservation?.displayValue,
            'status': biomarker.latestObservation?.status.name,
            'trend': biomarker.trendDirection.name,
            'lastMeasured': biomarker.latestObservation?.collectedAt.toIso8601String(),
          }).toList(),
        },
      };
    } catch (e) {
      return {
        'status': 'error',
        'message': 'Failed to get lab summary: ${e.toString()}',
        'data': null,
      };
    }
  }

  /// Get specific biomarker status and recent values
  /// Returns: {"status": "success|error", "data": {...}, "message": "..."}
  Future<Map<String, dynamic>> getBiomarkerStatus({
    required String biomarkerName,
    int? limit = 5,
  }) async {
    try {
      // Search for the biomarker by name
      final matchingBiomarkers = biomarkers.where((b) => 
        b.definition.name.toLowerCase().contains(biomarkerName.toLowerCase()) ||
        b.definition.alternativeNames.any((name) => 
          name.toLowerCase().contains(biomarkerName.toLowerCase())
        )
      ).toList();

      if (matchingBiomarkers.isEmpty) {
        // Try searching via repository
        final searchResponse = await _repository.searchBiomarkers(biomarkerName);
        return await searchResponse.when(
          success: (searchResults) async {
            if (searchResults.isEmpty) {
              return {
                'status': 'error',
                'message': 'No biomarker found matching "$biomarkerName"',
                'data': null,
              };
            }
            
            // Get the first match and its details
            final biomarker = searchResults.first;
            final detailResponse = await _repository.getBiomarkerDetail(biomarker.id);
            return detailResponse.when(
              success: (biomarkerWithTrend) => {
                'status': 'success',
                'message': 'Biomarker found',
                'data': _formatBiomarkerData(biomarkerWithTrend, limit),
              },
              error: (error) => {
                'status': 'error',
                'message': 'Failed to get biomarker details: $error',
                'data': null,
              },
              loading: () => {
                'status': 'loading',
                'message': 'Loading biomarker details...',
                'data': null,
              },
            );
          },
          error: (error) => {
            'status': 'error',
            'message': 'Search failed: $error',
            'data': null,
          },
          loading: () => {
            'status': 'loading',
            'message': 'Searching biomarkers...',
            'data': null,
          },
        );
      }

      // Use the first matching biomarker
      final biomarker = matchingBiomarkers.first;
      return {
        'status': 'success',
        'message': 'Biomarker status retrieved successfully',
        'data': _formatBiomarkerData(biomarker, limit),
      };
    } catch (e) {
      return {
        'status': 'error',
        'message': 'Failed to get biomarker status: ${e.toString()}',
        'data': null,
      };
    }
  }

  /// Add a lab measurement via voice command
  /// Returns: {"status": "success|error", "data": {...}, "message": "..."}
  Future<Map<String, dynamic>> addLabMeasurementFromAgent({
    required String biomarkerName,
    required double value,
    required String unit,
    DateTime? measuredAt,
    String? notes,
  }) async {
    try {
      // Find biomarker
      final matchingBiomarkers = biomarkers.where((b) => 
        b.definition.name.toLowerCase().contains(biomarkerName.toLowerCase()) ||
        b.definition.alternativeNames.any((name) => 
          name.toLowerCase().contains(biomarkerName.toLowerCase())
        )
      ).toList();

      String? biomarkerId;
      if (matchingBiomarkers.isNotEmpty) {
        biomarkerId = matchingBiomarkers.first.definition.id;
      } else {
        // Search via repository
        final searchResponse = await _repository.searchBiomarkers(biomarkerName);
        searchResponse.when(
          success: (searchResults) {
            if (searchResults.isNotEmpty) {
              biomarkerId = searchResults.first.id;
            }
          },
          error: (_) {},
          loading: () => print('Searching for biomarker...'),
        );
      }

      if (biomarkerId == null) {
        return {
          'status': 'error',
          'message': 'Could not find biomarker "$biomarkerName". Please check the name and try again.',
          'data': null,
        };
      }

      // Add the measurement
      final response = await _repository.addManualObservation(
        biomarkerId: biomarkerId!,
        value: value,
        unit: unit,
        collectedAt: measuredAt ?? DateTime.now(),
        notes: notes,
      );

      return await response.when(
        success: (observation) async {
          // Reload data to get updated trends
          await loadLabsData();
          
          return {
            'status': 'success',
            'message': 'Lab measurement added successfully',
            'data': {
              'biomarkerName': biomarkerName,
              'value': observation.displayValue,
              'measuredAt': observation.collectedAt.toIso8601String(),
              'status': observation.status.name,
              'notes': observation.notes,
            },
          };
        },
        error: (error) => {
          'status': 'error',
          'message': 'Failed to add measurement: $error',
          'data': null,
        },
        loading: () => {
          'status': 'loading',
          'message': 'Adding lab measurement...',
          'data': null,
        },
      );
    } catch (e) {
      return {
        'status': 'error',
        'message': 'Failed to add lab measurement: ${e.toString()}',
        'data': null,
      };
    }
  }

  /// Get critical or abnormal lab results that need attention
  /// Returns: {"status": "success|error", "data": [...], "message": "..."}
  Future<Map<String, dynamic>> getCriticalLabResults() async {
    try {
      final criticalResults = biomarkers.where((biomarker) {
        if (!biomarker.hasData) return false;
        final status = biomarker.latestObservation!.status;
        return status == ResultStatus.criticalLow || 
               status == ResultStatus.criticalHigh ||
               status == ResultStatus.high ||
               status == ResultStatus.low;
      }).toList();

      // Sort by severity: critical first, then abnormal
      criticalResults.sort((a, b) {
        final aPriority = _getStatusPriority(a.latestObservation!.status);
        final bPriority = _getStatusPriority(b.latestObservation!.status);
        return bPriority.compareTo(aPriority);
      });

      return {
        'status': 'success',
        'message': 'Found ${criticalResults.length} results needing attention',
        'data': criticalResults.map((biomarker) => {
          'name': biomarker.definition.name,
          'category': biomarker.categoryDisplayName,
          'value': biomarker.latestObservation!.displayValue,
          'status': biomarker.latestObservation!.status.name,
          'statusText': getStatusText(biomarker.latestObservation!.status),
          'lastMeasured': biomarker.latestObservation!.collectedAt.toIso8601String(),
          'referenceRange': biomarker.latestObservation!.refRange,
          'laboratoryName': biomarker.latestObservation!.laboratoryName,
        }).toList(),
      };
    } catch (e) {
      return {
        'status': 'error',
        'message': 'Failed to get critical lab results: ${e.toString()}',
        'data': null,
      };
    }
  }

  /// Get lab insights and recommendations
  /// Returns: {"status": "success|error", "data": [...], "message": "..."}
  Future<Map<String, dynamic>> getLabInsights({bool activeOnly = true}) async {
    try {
      final insights = activeOnly 
        ? healthInsights.where((insight) => insight.isActive).toList()
        : healthInsights.toList();

      return {
        'status': 'success',
        'message': 'Retrieved ${insights.length} lab insights',
        'data': insights.map((insight) => {
          'id': insight.id,
          'type': insight.type,
          'severity': insight.severity.name,
          'title': insight.title,
          'description': insight.description,
          'actionRecommendation': insight.actionRecommendation,
          'relatedBiomarkers': insight.relatedBiomarkers,
          'createdAt': insight.createdAt.toIso8601String(),
        }).toList(),
      };
    } catch (e) {
      return {
        'status': 'error',
        'message': 'Failed to get lab insights: ${e.toString()}',
        'data': null,
      };
    }
  }

  // Delete all lab data
  Future<void> deleteAllLabData() async {
    try {
      requestStatus.value = Status.LOADING;

      final response = await _repository.deleteAllLabData();

      response.when(
        success: (deleted) {
          // Clear local data
          biomarkers.clear();
          labDocuments.clear();
          labsSummary.value = null;
          healthInsights.clear();
          selectedBiomarker.value = null;

          AppToast.showToast(
            'Deleted ${deleted['biomarkers']} biomarkers and ${deleted['reports']} reports'
          );
          requestStatus.value = Status.COMPLETED;
        },
        error: (error) {
          AppToast.showToast('Failed to delete lab data: $error');
          requestStatus.value = Status.ERROR;
        },
        loading: () {
          print('Deleting all lab data...');
        },
      );
    } catch (e) {
      AppToast.showToast('Failed to delete lab data');
      requestStatus.value = Status.ERROR;
    }
  }

  // Reload all reports - re-analyze with latest AI
  Future<void> reloadAllReports() async {
    try {
      requestStatus.value = Status.LOADING;
      AppToast.showToast('Re-analyzing reports... This may take a few minutes');

      final response = await _repository.reloadAllReports();

      response.when(
        success: (results) {
          final reportsProcessed = results['reports_processed'] ?? 0;
          final totalReports = results['total_reports'] ?? 0;
          final biomarkersCreated = results['biomarkers_created'] ?? 0;

          AppToast.showToast(
            'Reloaded $reportsProcessed of $totalReports reports. Created $biomarkersCreated biomarkers'
          );

          // Reload lab data to show updated biomarkers
          loadLabsData();
        },
        error: (error) {
          AppToast.showToast('Failed to reload reports: $error');
          requestStatus.value = Status.ERROR;
        },
        loading: () {
          print('Reloading all reports...');
        },
      );
    } catch (e) {
      AppToast.showToast('Failed to reload reports');
      requestStatus.value = Status.ERROR;
    }
  }

  Map<String, dynamic> _formatBiomarkerData(BiomarkerWithTrend biomarker, int? limit) {
    final recentObs = limit != null && biomarker.recentObservations.length > limit
        ? biomarker.recentObservations.take(limit).toList()
        : biomarker.recentObservations;

    return {
      'name': biomarker.definition.name,
      'category': biomarker.categoryDisplayName,
      'loincCode': biomarker.definition.loincCode,
      'hasData': biomarker.hasData,
      'totalObservations': biomarker.totalObservations,
      'latestObservation': biomarker.latestObservation != null ? {
        'value': biomarker.latestObservation!.displayValue,
        'status': biomarker.latestObservation!.status.name,
        'statusText': getStatusText(biomarker.latestObservation!.status),
        'collectedAt': biomarker.latestObservation!.collectedAt.toIso8601String(),
        'referenceRange': biomarker.latestObservation!.refRange,
        'laboratoryName': biomarker.latestObservation!.laboratoryName,
        'notes': biomarker.latestObservation!.notes,
      } : null,
      'trend': {
        'direction': biomarker.trendDirection.name,
        'percentage': biomarker.trendPercentage,
      },
      'recentObservations': recentObs.map((obs) => {
        'value': obs.displayValue,
        'status': obs.status.name,
        'collectedAt': obs.collectedAt.toIso8601String(),
        'notes': obs.notes,
      }).toList(),
      'referenceRanges': biomarker.definition.referenceRanges.map((range) => {
        'low': range.low,
        'high': range.high,
        'unit': range.unit,
        'ageGroup': range.ageGroup,
        'gender': range.gender,
      }).toList(),
    };
  }
}