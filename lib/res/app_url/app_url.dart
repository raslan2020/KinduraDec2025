class AppUrl {
  // Environment configuration
  static const bool isLocalEnvironment = true; // Change to false for production

  // Base URLs for different environments
  // Note: Use your Mac's local IP for physical device testing
  // To find IP: run `ipconfig getifaddr en0` in terminal
  static const String localBaseUrl = "http://10.120.22.163:8000/api";
  static const String productionBaseUrl = "http://65.109.75.25:8000/api";

  // Dynamic base URL based on environment
  static String get baseUrl => isLocalEnvironment ? localBaseUrl : productionBaseUrl;

  // API Endpoints - dynamically constructed
  static String get loginUrl => "${baseUrl}/users/login/";
  static String get signupUrl => "${baseUrl}/users/signup/";
  static String get profileUrl => "${baseUrl}/users/profile/";
  static String get forgotPasswordUrl => "${baseUrl}/users/forgot_password/";
  static String get verifyResetCodeUrl => "${baseUrl}/users/verify_reset_code/";
  static String get resetPasswordUrl => "${baseUrl}/users/reset_password/";
  static String get patientReportsUrl => "${baseUrl}/users/patient_reports/";
  static String get healthProfileUrl => "${baseUrl}/health-profile/profile/";
  static String get pdfUploadUrl => "${baseUrl}/courses/with_medicines_and_schedules/";
  static String get courseListUrl => "${baseUrl}/courses/get_current_course/";
  static String get livekitTokenUrl => "${baseUrl}/livekit/get-token/";
  static String get deleteLivekitRoomUrl => "${baseUrl}/livekit/delete-room/";
  static String get conservationUrl => "${baseUrl}/users/json_uploads/";
  static String get coursesList => "${baseUrl}/courses/";

  // Medical Reports URLs (Legacy)
  static String get medicalReportsUrl => "${baseUrl}/medical-reports/";
  static String get vitalSignsUrl => "${baseUrl}/vital-signs/";
  static String get bloodTestsUrl => "${baseUrl}/blood-tests/";
  static String get medicalDocumentsUrl => "${baseUrl}/medical-documents/";
  static String get parseReportUrl => "${baseUrl}/medical-reports/parse-report/";
  static String get healthSummaryUrl => "${baseUrl}/medical-reports/health-summary/";

  // New Medical Report Upload System
  static String get uploadedReportsUrl => "${baseUrl}/uploaded-reports/";
  static String get uploadedReportsLatestUrl => "${baseUrl}/uploaded-reports/latest/";
  static String get uploadedReportsPendingRecommendationsUrl => "${baseUrl}/uploaded-reports/pending_recommendations/";
  static String get medicationRecommendationsUrl => "${baseUrl}/medication-recommendations/";
  static String get medicationRecommendationsPendingUrl => "${baseUrl}/medication-recommendations/pending/";
  static String get biomarkersUserUrl => "${baseUrl}/biomarkers/user/";

  // Helper method to get report details by ID
  static String uploadedReportDetailsUrl(String reportId) => "${baseUrl}/uploaded-reports/$reportId/";

  // Helper method to apply/dismiss recommendation
  static String applyRecommendationUrl(String recommendationId) => "${baseUrl}/medication-recommendations/$recommendationId/apply/";
  static String dismissRecommendationUrl(String recommendationId) => "${baseUrl}/medication-recommendations/$recommendationId/dismiss/";

  // Helper method to get biomarker trends
  static String biomarkerTrendsUrl(String biomarkerName) => "${baseUrl}/biomarkers/trends/$biomarkerName/";

  // Watch Vitals URLs
  static String get watchVitalsUrl => "${baseUrl}/watch-vitals/";
  static String get watchVitalsHistoryUrl => "${baseUrl}/watch-vitals/history/";

  // Medication Adherence URLs
  static String get medicationHistoryUrl => "${baseUrl}/medication-history/";
  static String get adherenceAnalysisUrl => "${baseUrl}/adherence/analysis/";
  static String get scheduleChangesUrl => "${baseUrl}/medication-schedule-changes/";

  // Stored AI Health Insights URLs
  static String get storedHealthInsightsUrl => "${baseUrl}/health-insights/";
  static String markInsightReadUrl(String insightId) => "${baseUrl}/health-insights/$insightId/read/";
  static String dismissInsightUrl(String insightId) => "${baseUrl}/health-insights/$insightId/dismiss/";
  static String regenerateReportInsightsUrl(String reportId) => "${baseUrl}/health-insights/report/$reportId/regenerate/";
}
