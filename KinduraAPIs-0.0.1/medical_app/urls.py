"""
URL configuration for medical_app project.

The `urlpatterns` list routes URLs to views. For more information please see:
    https://docs.djangoproject.com/en/5.2/topics/http/urls/
Examples:
Function views
    1. Add an import:  from my_app import views
    2. Add a URL to urlpatterns:  path('', views.home, name='home')
Class-based views
    1. Add an import:  from other_app.views import Home
    2. Add a URL to urlpatterns:  path('', Home.as_view(), name='home')
Including another URLconf
    1. Import the include() function: from django.urls import include, path
    2. Add a URL to urlpatterns:  path('blog/', include('blog.urls'))
"""
from django.contrib import admin
from django.urls import path, include
from django.conf import settings
from django.conf.urls.static import static
from rest_framework.routers import DefaultRouter
from users.views import UserViewSet, ContactViewSet
from health_profile.views import HealthProfileViewSet, WatchVitalsView, WatchVitalsHistoryView, WatchVitalsDevView
from courses.views import CourseViewSet
from medicines.views import MedicineViewSet
from schedules.views import CourseMedicineScheduleViewSet, CourseDayTrackingViewSet
from medical_reports.views import (
    VitalSignViewSet,
    BloodTestViewSet,
    MedicalDocumentViewSet,
    MedicalReportViewSet,
    UploadedMedicalReportViewSet,
    MedicationRecommendationViewSet
)
from medical_reports.biomarker_views import (
    get_user_biomarkers,
    get_biomarker_categories,
    get_biomarker_detail,
    add_manual_observation,
    observation_detail,  # Combined update/delete handler
    get_labs_summary,
    get_health_insights,
    dismiss_insight,
    search_biomarkers,
    export_fhir,
    get_lab_documents,
    delete_lab_document,
    delete_all_lab_data,
    reload_all_reports,
    get_biomarker_ai_insights,
    # New stored insights endpoints
    get_stored_health_insights,
    mark_insight_read,
    dismiss_health_insight,
    regenerate_report_insights,
)

# Create router and register viewsets
router = DefaultRouter()
router.register(r'users', UserViewSet, basename='user')
router.register(r'health-profile', HealthProfileViewSet, basename='health-profile')
router.register(r'courses', CourseViewSet, basename='course')
router.register(r'medications', MedicineViewSet, basename='medicine')  # Changed from 'medicines' to match Flutter
router.register(r'medicines', MedicineViewSet, basename='medicines')  # Keep old route for backward compatibility
router.register(r'schedules', CourseMedicineScheduleViewSet, basename='schedule')
router.register(r'tracking', CourseDayTrackingViewSet, basename='tracking')
router.register(r'contacts', ContactViewSet, basename='contact')

# Medical reports endpoints (legacy)
router.register(r'medical-reports', MedicalReportViewSet, basename='medical-report')
router.register(r'vital-signs', VitalSignViewSet, basename='vital-sign')
router.register(r'blood-tests', BloodTestViewSet, basename='blood-test')
router.register(r'medical-documents', MedicalDocumentViewSet, basename='medical-document')

# New medical report upload system
router.register(r'uploaded-reports', UploadedMedicalReportViewSet, basename='uploaded-report')
router.register(r'medication-recommendations', MedicationRecommendationViewSet, basename='medication-recommendation')

# Missing endpoints for Flutter app compatibility (temporary stub endpoints)
from rest_framework.decorators import api_view, permission_classes
from rest_framework.permissions import IsAuthenticated
from rest_framework.response import Response
from rest_framework import status

@api_view(['GET'])
@permission_classes([IsAuthenticated])
def biomarkers_stub(request):
    """Temporary stub - returns empty data with proper structure"""
    # Different endpoints need different structures
    path = request.path

    if 'categories' in path:
        # Categories should return a dict, not a list
        return Response({"status": True, "result": {}, "count": 0})
    elif 'summary' in path:
        # Summary should return a summary object, not a list
        return Response({
            "status": True,
            "result": {
                "totalBiomarkers": 0,
                "abnormalCount": 0,
                "criticalCount": 0,
                "recentTestsCount": 0,
                "featuredBiomarkers": [],
                "activeInsights": [],
                "lastUpdated": "2025-11-15T00:00:00Z"
            }
        })
    else:
        # Default: return empty list
        return Response({"status": True, "result": [], "count": 0})

@api_view(['GET'])
@permission_classes([IsAuthenticated])
def adherence_summary_stub(request):
    """Temporary endpoint for adherence summary"""
    return Response({"status": True, "result": {"adherence_percentage": 85, "streak_days": 7}})

@api_view(['GET'])
@permission_classes([IsAuthenticated])
def medication_reminders_stub(request):
    """Temporary endpoint for medication reminders"""
    return Response({"status": True, "result": []})

@api_view(['GET'])
@permission_classes([IsAuthenticated])
def caregiver_contacts_stub(request):
    """Redirect to contacts API - for backward compatibility"""
    from users.models import Contact
    contacts = Contact.objects.filter(user=request.user, is_active=True, contact_type='caregiver')
    result = [{'id': c.id, 'name': c.name, 'phone': c.phone_number, 'is_emergency': c.is_emergency} for c in contacts]
    return Response({"status": True, "result": result})

urlpatterns = [
    path('admin/', admin.site.urls),
    path('api/', include(router.urls)),
    path('api/livekit/', include('livekit_app.urls')),
    path('api/medical-reports/parse-report/', MedicalReportViewSet.as_view({'post': 'parse_report'})),

    # Biomarker endpoints (specific routes before generic ones)
    path('api/biomarkers/user/', get_user_biomarkers, name='user-biomarkers'),
    path('api/biomarkers/summary/', get_labs_summary, name='biomarkers-summary'),
    path('api/biomarkers/categories/', get_biomarker_categories, name='biomarkers-categories'),
    path('api/biomarkers/observations/manual/', add_manual_observation, name='add-manual-observation'),
    path('api/biomarkers/observations/<str:observation_id>/', observation_detail, name='observation-detail'),
    path('api/biomarkers/insights/', get_health_insights, name='health-insights'),
    path('api/biomarkers/insights/<str:insight_id>/dismiss/', dismiss_insight, name='dismiss-insight'),
    # Stored AI-generated health insights (auto-generated when reports are uploaded)
    path('api/health-insights/', get_stored_health_insights, name='stored-health-insights'),
    path('api/health-insights/<uuid:insight_id>/read/', mark_insight_read, name='mark-insight-read'),
    path('api/health-insights/<uuid:insight_id>/dismiss/', dismiss_health_insight, name='dismiss-health-insight'),
    path('api/health-insights/report/<uuid:report_id>/regenerate/', regenerate_report_insights, name='regenerate-report-insights'),
    path('api/biomarkers/search/', search_biomarkers, name='search-biomarkers'),
    path('api/biomarkers/export/fhir/', export_fhir, name='export-fhir'),
    path('api/biomarkers/documents/', get_lab_documents, name='lab-documents'),
    path('api/biomarkers/documents/<str:document_id>/', delete_lab_document, name='delete-lab-document'),
    path('api/biomarkers/delete-all/', delete_all_lab_data, name='delete-all-lab-data'),
    path('api/biomarkers/reload-all/', reload_all_reports, name='reload-all-reports'),
    # AI insights endpoint - must be before generic detail route
    path('api/biomarkers/<str:biomarker_id>/ai-insights/', get_biomarker_ai_insights, name='biomarker-ai-insights'),
    # Generic biomarker detail route must be last
    path('api/biomarkers/<str:biomarker_id>/', get_biomarker_detail, name='biomarker-detail'),
    path('api/medication-reminders/active/', medication_reminders_stub, name='medication-reminders'),
    path('api/caregiver-contacts/', caregiver_contacts_stub, name='caregiver-contacts'),
    path('api/medications/interactions/check/', medication_reminders_stub, name='medication-interactions'),
]

# Register medication-related viewsets
from medicines.views import DoseEventViewSet, AdherenceSummaryView, SideEffectViewSet, MedicationHistoryView, AIAdherenceAnalysisView, MedicationScheduleChangesView

dose_event_list = DoseEventViewSet.as_view({'post': 'create'})
adherence_summary = AdherenceSummaryView.as_view({'get': 'list'})
side_effect_list = SideEffectViewSet.as_view({'get': 'list', 'post': 'create'})
medication_history = MedicationHistoryView.as_view({'get': 'list'})
ai_adherence_analysis = AIAdherenceAnalysisView.as_view({'get': 'list', 'post': 'create'})
medication_schedule_changes = MedicationScheduleChangesView.as_view({'get': 'list'})

urlpatterns += [
    path('api/dose-events/', dose_event_list, name='dose-events'),
    path('api/adherence/summary/', adherence_summary, name='adherence-summary'),
    path('api/adherence/analysis/', ai_adherence_analysis, name='ai-adherence-analysis'),
    path('api/side-effect-reports/', side_effect_list, name='side-effect-reports'),
    path('api/medication-history/', medication_history, name='medication-history'),
    path('api/medication-schedule-changes/', medication_schedule_changes, name='medication-schedule-changes'),
    # Watch vitals API
    path('api/watch-vitals/', WatchVitalsView.as_view(), name='watch-vitals'),
    path('api/watch-vitals/history/', WatchVitalsHistoryView.as_view(), name='watch-vitals-history'),
    # Development endpoint for Watch simulator (no auth required)
    path('api/watch-vitals/dev/', WatchVitalsDevView.as_view(), name='watch-vitals-dev'),
]

# Serve media files in development
if settings.DEBUG:
    urlpatterns += static(settings.MEDIA_URL, document_root=settings.MEDIA_ROOT)
