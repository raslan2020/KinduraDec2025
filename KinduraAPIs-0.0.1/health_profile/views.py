import logging
from django.shortcuts import render
from django.utils import timezone
from datetime import timedelta, date
from rest_framework import viewsets, status
from rest_framework.decorators import action
from rest_framework.permissions import IsAuthenticated
from rest_framework.views import APIView
from .models import (
    HealthProfile, WatchVitals,
    PatientClinicalProfile, MotorSymptomEntry, NonMotorSymptomEntry,
    MedicationDoseEntry, SafetyEvent, SpeechMetrics, CognitiveScreening,
    ClinicalReport, AgentDataCollection
)
from .serializers import (
    HealthProfileSerializer, WatchVitalsSerializer, WatchVitalsSummarySerializer,
    PatientClinicalProfileSerializer, MotorSymptomEntrySerializer,
    NonMotorSymptomEntrySerializer, MedicationDoseEntrySerializer,
    SafetyEventSerializer, SpeechMetricsSerializer, CognitiveScreeningSerializer,
    ClinicalReportSerializer, ClinicalReportSummarySerializer,
    AgentDataCollectionSerializer, DataGapsSerializer, AgentSymptomCollectionSerializer
)
from utils.response_utils import success_response, error_response
from utils.authentication import SimpleTokenAuthentication
from channels.layers import get_channel_layer
from asgiref.sync import async_to_sync

logger = logging.getLogger(__name__)


class HealthProfileViewSet(viewsets.ViewSet):
    """
    ViewSet for health profile management
    """
    authentication_classes = [SimpleTokenAuthentication]
    permission_classes = [IsAuthenticated]
    
    def get_queryset(self):
        return HealthProfile.objects.filter(user=self.request.user)
    
    @action(detail=False, methods=['get', 'post', 'put'], permission_classes=[IsAuthenticated])
    def profile(self, request):
        """
        Get, create, or update health profile
        """
        if request.method == 'GET':
            try:
                health_profile = self.get_queryset().first()
                if health_profile:
                    serializer = HealthProfileSerializer(health_profile)
                    return success_response(serializer.data)
                else:
                    return error_response("Health profile not found", status.HTTP_404_NOT_FOUND)
            except Exception as e:
                logger.error("Error fetching health profile: %s", e)
                return error_response("Failed to fetch health profile", status.HTTP_500_INTERNAL_SERVER_ERROR)

        elif request.method == 'POST':
            try:
                # Check if profile already exists
                existing_profile = self.get_queryset().first()
                if existing_profile:
                    return error_response("Health profile already exists. Use PUT to update.", status.HTTP_400_BAD_REQUEST)

                serializer = HealthProfileSerializer(data=request.data)
                if serializer.is_valid():
                    health_profile = serializer.save(user=request.user)
                    return success_response(
                        HealthProfileSerializer(health_profile).data,
                        "Health profile created successfully",
                        status.HTTP_201_CREATED
                    )
                else:
                    return error_response(serializer.errors, status.HTTP_400_BAD_REQUEST)
            except Exception as e:
                logger.error("Error creating health profile: %s", e)
                return error_response("Failed to create health profile", status.HTTP_500_INTERNAL_SERVER_ERROR)
        
        elif request.method == 'PUT':
            try:
                health_profile = self.get_queryset().first()
                
                if health_profile:
                    # Update existing profile
                    serializer = HealthProfileSerializer(health_profile, data=request.data, partial=True)
                    if serializer.is_valid():
                        updated_profile = serializer.save()
                        return success_response(
                            HealthProfileSerializer(updated_profile).data,
                            "Health profile updated successfully"
                        )
                    else:
                        return error_response(serializer.errors, status.HTTP_400_BAD_REQUEST)
                else:
                    # Create new profile if it doesn't exist
                    serializer = HealthProfileSerializer(data=request.data)
                    if serializer.is_valid():
                        health_profile = serializer.save(user=request.user)
                        return success_response(
                            HealthProfileSerializer(health_profile).data,
                            "Health profile created successfully",
                            status.HTTP_201_CREATED
                        )
                    else:
                        return error_response(serializer.errors, status.HTTP_400_BAD_REQUEST)
            except Exception as e:
                logger.error("Error updating health profile: %s", e)
                return error_response("Failed to update health profile", status.HTTP_500_INTERNAL_SERVER_ERROR)


class WatchVitalsView(APIView):
    """
    API for Apple Watch vitals data
    GET - Get latest vitals summary for widget
    POST - Store new vitals from Watch
    """
    authentication_classes = [SimpleTokenAuthentication]
    permission_classes = [IsAuthenticated]

    def get(self, request):
        """Get latest vitals summary for iPhone Watch widget"""
        try:
            # Get most recent vitals record
            latest_vitals = WatchVitals.objects.filter(
                user=request.user
            ).order_by('-recorded_at').first()

            if not latest_vitals:
                # Return demo data if no records exist
                return success_response({
                    'heart_rate': 72,
                    'blood_oxygen': 98,
                    'sleep_hours': 5.2,
                    'awakenings': 3,
                    'sleep_quality': 'fair',
                    'falls_count': 0,
                    'last_updated': None,
                    'is_demo': True
                })

            # Count falls in last 7 days
            week_ago = timezone.now() - timedelta(days=7)
            falls_count = WatchVitals.objects.filter(
                user=request.user,
                fall_detected=True,
                recorded_at__gte=week_ago
            ).count()

            summary = {
                'heart_rate': latest_vitals.heart_rate,
                'blood_oxygen': latest_vitals.blood_oxygen,
                'hrv': latest_vitals.hrv or 0,
                'respiratory_rate': latest_vitals.respiratory_rate or 0,
                'sleep_hours': latest_vitals.total_sleep_hours or 0,
                'awakenings': latest_vitals.awakenings_count,
                'sleep_quality': latest_vitals.sleep_quality_computed or latest_vitals.sleep_quality or 'unknown',
                'falls_count': falls_count,
                'last_updated': latest_vitals.recorded_at,
                'is_demo': False
            }

            return success_response(summary)

        except Exception as e:
            logger.error("Error fetching watch vitals: %s", e)
            return error_response("Failed to fetch watch vitals", status.HTTP_500_INTERNAL_SERVER_ERROR)

    def post(self, request):
        """Store new vitals from Watch"""
        try:
            serializer = WatchVitalsSerializer(data=request.data)
            if serializer.is_valid():
                vitals = serializer.save(user=request.user)
                return success_response(
                    WatchVitalsSerializer(vitals).data,
                    "Watch vitals saved successfully",
                    status.HTTP_201_CREATED
                )
            return error_response(serializer.errors, status.HTTP_400_BAD_REQUEST)
        except Exception as e:
            logger.error("Error saving watch vitals: %s", e)
            return error_response("Failed to save watch vitals", status.HTTP_500_INTERNAL_SERVER_ERROR)


class WatchVitalsDevView(APIView):
    """
    Development endpoint for Watch vitals - NOW REQUIRES AUTHENTICATION
    Used for Watch app testing with proper token authentication
    """
    authentication_classes = [SimpleTokenAuthentication]
    permission_classes = [IsAuthenticated]

    def post(self, request):
        """Store vitals from Watch app (requires authentication)"""
        try:
            # Use authenticated user from token
            user = request.user

            serializer = WatchVitalsSerializer(data=request.data)
            if serializer.is_valid():
                vitals = serializer.save(user=user)
                logger.info("Watch vitals saved for %s: HR=%s, O2=%s", user.email, vitals.heart_rate, vitals.blood_oxygen)

                # Broadcast to user-specific WebSocket channel (security fix)
                channel_layer = get_channel_layer()
                vitals_data = WatchVitalsSerializer(vitals).data
                async_to_sync(channel_layer.group_send)(
                    f'user_{user.id}_vitals',
                    {
                        'type': 'watch_vitals_update',
                        'vitals': vitals_data
                    }
                )
                logger.debug("Broadcasted vitals via WebSocket to user %s", user.id)

                return success_response(
                    vitals_data,
                    "Watch vitals saved successfully",
                    status.HTTP_201_CREATED
                )
            return error_response(serializer.errors, status.HTTP_400_BAD_REQUEST)
        except Exception as e:
            logger.error("Error saving watch vitals: %s", e)
            return error_response("Failed to save vitals", status.HTTP_500_INTERNAL_SERVER_ERROR)


class WatchVitalsHistoryView(APIView):
    """
    Get historical Watch vitals data
    """
    authentication_classes = [SimpleTokenAuthentication]
    permission_classes = [IsAuthenticated]

    def get(self, request):
        """Get vitals history with optional date filtering"""
        try:
            days = int(request.query_params.get('days', 7))
            start_date = timezone.now() - timedelta(days=days)

            vitals = WatchVitals.objects.filter(
                user=request.user,
                recorded_at__gte=start_date
            ).order_by('-recorded_at')[:100]

            serializer = WatchVitalsSerializer(vitals, many=True)
            return success_response(serializer.data)
        except Exception as e:
            logger.error("Error fetching vitals history: %s", e)
            return error_response("Failed to fetch vitals history", status.HTTP_500_INTERNAL_SERVER_ERROR)


# ============================================================
# CLINICAL DATA VIEWS - Following Reports.md Specification
# ============================================================

class PatientClinicalProfileView(APIView):
    """
    API for patient clinical profile (context data)
    Following Reports.md Section 3.1
    """
    authentication_classes = [SimpleTokenAuthentication]
    permission_classes = [IsAuthenticated]

    def get(self, request):
        """Get patient clinical profile"""
        try:
            profile = PatientClinicalProfile.objects.filter(user=request.user).first()
            if profile:
                return success_response(PatientClinicalProfileSerializer(profile).data)
            return success_response(None, "No clinical profile found")
        except Exception as e:
            logger.error("Error fetching clinical profile: %s", e)
            return error_response("Failed to fetch clinical profile", status.HTTP_500_INTERNAL_SERVER_ERROR)

    def post(self, request):
        """Create or update clinical profile"""
        try:
            profile, created = PatientClinicalProfile.objects.get_or_create(user=request.user)
            serializer = PatientClinicalProfileSerializer(profile, data=request.data, partial=True)
            if serializer.is_valid():
                serializer.save()
                msg = "Clinical profile created" if created else "Clinical profile updated"
                return success_response(serializer.data, msg)
            return error_response(serializer.errors, status.HTTP_400_BAD_REQUEST)
        except Exception as e:
            logger.error("Error saving clinical profile: %s", e)
            return error_response("Failed to save clinical profile", status.HTTP_500_INTERNAL_SERVER_ERROR)


class MotorSymptomView(APIView):
    """
    API for daily motor symptom entries
    Following Reports.md Section 3.2
    """
    authentication_classes = [SimpleTokenAuthentication]
    permission_classes = [IsAuthenticated]

    def get(self, request):
        """Get motor symptom entries with optional date filtering"""
        try:
            days = int(request.query_params.get('days', 7))
            start_date = date.today() - timedelta(days=days)

            entries = MotorSymptomEntry.objects.filter(
                user=request.user,
                recorded_date__gte=start_date
            ).order_by('-recorded_date')

            serializer = MotorSymptomEntrySerializer(entries, many=True)
            return success_response(serializer.data)
        except Exception as e:
            logger.error("Error fetching motor symptoms: %s", e)
            return error_response("Failed to fetch motor symptoms", status.HTTP_500_INTERNAL_SERVER_ERROR)

    def post(self, request):
        """Create or update motor symptom entry for today"""
        try:
            recorded_date = request.data.get('recorded_date', date.today())
            if isinstance(recorded_date, str):
                recorded_date = date.fromisoformat(recorded_date)

            # Check for existing entry for this date
            entry = MotorSymptomEntry.objects.filter(
                user=request.user,
                recorded_date=recorded_date
            ).first()

            if entry:
                serializer = MotorSymptomEntrySerializer(entry, data=request.data, partial=True)
            else:
                serializer = MotorSymptomEntrySerializer(data=request.data)

            if serializer.is_valid():
                serializer.save(user=request.user)
                # Check for missing bradykinesia (Reports.md rule)
                if not serializer.validated_data.get('bradykinesia'):
                    logger.warning("Motor entry without bradykinesia for user %s", request.user.id)
                return success_response(serializer.data, "Motor symptoms recorded")
            return error_response(serializer.errors, status.HTTP_400_BAD_REQUEST)
        except Exception as e:
            logger.error("Error saving motor symptoms: %s", e)
            return error_response("Failed to save motor symptoms", status.HTTP_500_INTERNAL_SERVER_ERROR)


class NonMotorSymptomView(APIView):
    """
    API for non-motor symptom entries
    Following Reports.md Section 3.3
    """
    authentication_classes = [SimpleTokenAuthentication]
    permission_classes = [IsAuthenticated]

    def get(self, request):
        """Get non-motor symptom entries"""
        try:
            days = int(request.query_params.get('days', 30))
            start_date = date.today() - timedelta(days=days)

            entries = NonMotorSymptomEntry.objects.filter(
                user=request.user,
                recorded_date__gte=start_date
            ).order_by('-recorded_date')

            serializer = NonMotorSymptomEntrySerializer(entries, many=True)
            return success_response(serializer.data)
        except Exception as e:
            logger.error("Error fetching non-motor symptoms: %s", e)
            return error_response("Failed to fetch non-motor symptoms", status.HTTP_500_INTERNAL_SERVER_ERROR)

    def post(self, request):
        """Create non-motor symptom entry"""
        try:
            serializer = NonMotorSymptomEntrySerializer(data=request.data)
            if serializer.is_valid():
                serializer.save(user=request.user)
                return success_response(serializer.data, "Non-motor symptoms recorded")
            return error_response(serializer.errors, status.HTTP_400_BAD_REQUEST)
        except Exception as e:
            logger.error("Error saving non-motor symptoms: %s", e)
            return error_response("Failed to save non-motor symptoms", status.HTTP_500_INTERNAL_SERVER_ERROR)


class MedicationDoseView(APIView):
    """
    API for medication dose tracking
    Following Reports.md Section 3.4
    """
    authentication_classes = [SimpleTokenAuthentication]
    permission_classes = [IsAuthenticated]

    def get(self, request):
        """Get medication dose entries"""
        try:
            days = int(request.query_params.get('days', 7))
            start_date = timezone.now() - timedelta(days=days)

            entries = MedicationDoseEntry.objects.filter(
                user=request.user,
                scheduled_time__gte=start_date
            ).order_by('-scheduled_time')

            serializer = MedicationDoseEntrySerializer(entries, many=True)
            return success_response(serializer.data)
        except Exception as e:
            logger.error("Error fetching medication doses: %s", e)
            return error_response("Failed to fetch medication doses", status.HTTP_500_INTERNAL_SERVER_ERROR)

    def post(self, request):
        """Record a medication dose"""
        try:
            serializer = MedicationDoseEntrySerializer(data=request.data)
            if serializer.is_valid():
                serializer.save(user=request.user)
                return success_response(serializer.data, "Medication dose recorded")
            return error_response(serializer.errors, status.HTTP_400_BAD_REQUEST)
        except Exception as e:
            logger.error("Error saving medication dose: %s", e)
            return error_response("Failed to save medication dose", status.HTTP_500_INTERNAL_SERVER_ERROR)


class SafetyEventView(APIView):
    """
    API for safety events (falls, hallucinations, etc.)
    Following Reports.md Section 3.8
    """
    authentication_classes = [SimpleTokenAuthentication]
    permission_classes = [IsAuthenticated]

    def get(self, request):
        """Get safety events"""
        try:
            days = int(request.query_params.get('days', 30))
            start_date = timezone.now() - timedelta(days=days)

            events = SafetyEvent.objects.filter(
                user=request.user,
                occurred_at__gte=start_date
            ).order_by('-occurred_at')

            serializer = SafetyEventSerializer(events, many=True)
            return success_response(serializer.data)
        except Exception as e:
            logger.error("Error fetching safety events: %s", e)
            return error_response("Failed to fetch safety events", status.HTTP_500_INTERNAL_SERVER_ERROR)

    def post(self, request):
        """Record a safety event"""
        try:
            serializer = SafetyEventSerializer(data=request.data)
            if serializer.is_valid():
                event = serializer.save(user=request.user)

                # Check for critical events that need escalation
                if event.severity in ['high', 'critical']:
                    logger.warning("Critical safety event for user %s: %s", request.user.id, event.event_type)
                    # TODO: Trigger notification to caregiver/provider

                return success_response(serializer.data, "Safety event recorded")
            return error_response(serializer.errors, status.HTTP_400_BAD_REQUEST)
        except Exception as e:
            logger.error("Error saving safety event: %s", e)
            return error_response("Failed to save safety event", status.HTTP_500_INTERNAL_SERVER_ERROR)


class SpeechMetricsView(APIView):
    """
    API for speech and voice metrics
    Following Reports.md Section 3.6
    """
    authentication_classes = [SimpleTokenAuthentication]
    permission_classes = [IsAuthenticated]

    def get(self, request):
        """Get speech metrics"""
        try:
            days = int(request.query_params.get('days', 30))
            start_date = date.today() - timedelta(days=days)

            metrics = SpeechMetrics.objects.filter(
                user=request.user,
                recorded_date__gte=start_date
            ).order_by('-recorded_date')

            serializer = SpeechMetricsSerializer(metrics, many=True)
            return success_response(serializer.data)
        except Exception as e:
            logger.error("Error fetching speech metrics: %s", e)
            return error_response("Failed to fetch speech metrics", status.HTTP_500_INTERNAL_SERVER_ERROR)

    def post(self, request):
        """Record speech metrics"""
        try:
            serializer = SpeechMetricsSerializer(data=request.data)
            if serializer.is_valid():
                serializer.save(user=request.user)
                return success_response(serializer.data, "Speech metrics recorded")
            return error_response(serializer.errors, status.HTTP_400_BAD_REQUEST)
        except Exception as e:
            logger.error("Error saving speech metrics: %s", e)
            return error_response("Failed to save speech metrics", status.HTTP_500_INTERNAL_SERVER_ERROR)


class CognitiveScreeningView(APIView):
    """
    API for cognitive and mood screening
    Following Reports.md Section 3.7
    Safety: PHQ-9 Q9 >= 2 triggers escalation
    """
    authentication_classes = [SimpleTokenAuthentication]
    permission_classes = [IsAuthenticated]

    def get(self, request):
        """Get cognitive screenings"""
        try:
            days = int(request.query_params.get('days', 90))
            start_date = date.today() - timedelta(days=days)

            screenings = CognitiveScreening.objects.filter(
                user=request.user,
                recorded_date__gte=start_date
            ).order_by('-recorded_date')

            serializer = CognitiveScreeningSerializer(screenings, many=True)
            return success_response(serializer.data)
        except Exception as e:
            logger.error("Error fetching cognitive screenings: %s", e)
            return error_response("Failed to fetch cognitive screenings", status.HTTP_500_INTERNAL_SERVER_ERROR)

    def post(self, request):
        """Record cognitive screening"""
        try:
            serializer = CognitiveScreeningSerializer(data=request.data)
            if serializer.is_valid():
                screening = serializer.save(user=request.user)

                # Safety check: PHQ-9 Q9 >= 2 (suicidal ideation)
                if screening.requires_immediate_escalation:
                    logger.critical("SAFETY ALERT: PHQ-9 Q9 >= 2 for user %s - immediate escalation required", request.user.id)
                    # Create safety event
                    SafetyEvent.objects.create(
                        user=request.user,
                        event_type='suicidal_ideation',
                        severity='critical',
                        occurred_at=timezone.now(),
                        description=f"PHQ-9 Question 9 score: {screening.phq9_q9_score}",
                        data_source='patient'
                    )
                    # TODO: Send urgent notification to caregiver/provider

                return success_response(serializer.data, "Cognitive screening recorded")
            return error_response(serializer.errors, status.HTTP_400_BAD_REQUEST)
        except Exception as e:
            logger.error("Error saving cognitive screening: %s", e)
            return error_response("Failed to save cognitive screening", status.HTTP_500_INTERNAL_SERVER_ERROR)


class ClinicalReportView(APIView):
    """
    API for clinical reports (daily, weekly, monthly)
    Following Reports.md Sections 2.1-2.4
    """
    authentication_classes = [SimpleTokenAuthentication]
    permission_classes = [IsAuthenticated]

    def get(self, request):
        """Get clinical reports"""
        try:
            report_type = request.query_params.get('type')  # daily, weekly, monthly
            limit = int(request.query_params.get('limit', 10))

            reports = ClinicalReport.objects.filter(user=request.user)
            if report_type:
                reports = reports.filter(report_type=report_type)
            reports = reports.order_by('-period_end')[:limit]

            serializer = ClinicalReportSummarySerializer(reports, many=True)
            return success_response(serializer.data)
        except Exception as e:
            logger.error("Error fetching clinical reports: %s", e)
            return error_response("Failed to fetch clinical reports", status.HTTP_500_INTERNAL_SERVER_ERROR)


class ClinicalReportDetailView(APIView):
    """
    Get detailed clinical report by ID
    """
    authentication_classes = [SimpleTokenAuthentication]
    permission_classes = [IsAuthenticated]

    def get(self, request, report_id):
        """Get full clinical report"""
        try:
            report = ClinicalReport.objects.filter(
                user=request.user,
                id=report_id
            ).first()

            if not report:
                return error_response("Report not found", status.HTTP_404_NOT_FOUND)

            # Mark as viewed by patient
            if not report.viewed_by_patient:
                report.viewed_by_patient = True
                report.viewed_by_patient_at = timezone.now()
                report.save()

            serializer = ClinicalReportSerializer(report)
            return success_response(serializer.data)
        except Exception as e:
            logger.error("Error fetching clinical report: %s", e)
            return error_response("Failed to fetch clinical report", status.HTTP_500_INTERNAL_SERVER_ERROR)


class AgentDataGapsView(APIView):
    """
    API for agent to get data gaps and questions to ask
    Returns prioritized list of missing data points
    """
    authentication_classes = [SimpleTokenAuthentication]
    permission_classes = [IsAuthenticated]

    def get(self, request):
        """Get data gaps for the agent to fill"""
        try:
            # Update data collection status
            self._update_data_gaps(request.user)

            # Get overdue items
            gaps = AgentDataCollection.objects.filter(
                user=request.user,
                is_overdue=True
            ).order_by('priority', '-days_overdue')[:5]

            data_gaps = []
            for gap in gaps:
                data_gaps.append({
                    'domain': gap.domain,
                    'field_name': gap.field_name,
                    'priority': gap.priority,
                    'days_overdue': gap.days_overdue,
                    'prompt': gap.collection_prompt
                })

            return success_response(data_gaps)
        except Exception as e:
            logger.error("Error fetching data gaps: %s", e)
            return error_response("Failed to fetch data gaps", status.HTTP_500_INTERNAL_SERVER_ERROR)

    def _update_data_gaps(self, user):
        """Update data collection gap status"""
        today = date.today()

        # Define data collection requirements per Reports.md
        requirements = [
            # Daily motor symptoms
            {'domain': 'motor', 'field': 'bradykinesia', 'freq': 'daily', 'priority': 1,
             'prompt': 'How slow did your movements feel today, 1 to 5?'},
            {'domain': 'motor', 'field': 'tremor', 'freq': 'daily', 'priority': 2,
             'prompt': 'How much tremor did you have today, 1 to 5?'},
            {'domain': 'motor', 'field': 'rigidity', 'freq': 'daily', 'priority': 2,
             'prompt': 'How stiff did you feel today, 1 to 5?'},
            {'domain': 'motor', 'field': 'gait', 'freq': 'daily', 'priority': 2,
             'prompt': 'How was your walking and balance today, 1 to 5?'},
            {'domain': 'motor', 'field': 'laterality', 'freq': 'daily', 'priority': 1,
             'prompt': 'Which side was more affected: left, right, or both?'},
            # Weekly non-motor
            {'domain': 'non_motor', 'field': 'sleep', 'freq': 'weekly', 'priority': 3,
             'prompt': 'How has your sleep been this week, 1 to 5?'},
            {'domain': 'non_motor', 'field': 'constipation', 'freq': 'weekly', 'priority': 4,
             'prompt': 'Any constipation issues this week, 1 to 5?'},
            {'domain': 'non_motor', 'field': 'mood', 'freq': 'weekly', 'priority': 3,
             'prompt': 'How has your mood been this week, 1 to 5?'},
            {'domain': 'non_motor', 'field': 'fatigue', 'freq': 'weekly', 'priority': 4,
             'prompt': 'How fatigued have you felt this week, 1 to 5?'},
            # Weekly speech
            {'domain': 'speech', 'field': 'voice_volume', 'freq': 'weekly', 'priority': 5,
             'prompt': 'How has your voice volume been this week, 1 to 5?'},
        ]

        for req in requirements:
            gap, _ = AgentDataCollection.objects.get_or_create(
                user=user,
                domain=req['domain'],
                field_name=req['field'],
                defaults={
                    'collection_frequency': req['freq'],
                    'priority': req['priority'],
                    'collection_prompt': req['prompt']
                }
            )

            # Check if overdue
            if req['freq'] == 'daily':
                # Check for today's motor entry
                if req['domain'] == 'motor':
                    entry = MotorSymptomEntry.objects.filter(
                        user=user,
                        recorded_date=today
                    ).first()
                    if entry and getattr(entry, req['field'], None):
                        gap.is_overdue = False
                        gap.last_collected_at = timezone.now()
                    else:
                        gap.is_overdue = True
                        gap.days_overdue = 1 if not gap.last_collected_at else (today - gap.last_collected_at.date()).days
            elif req['freq'] == 'weekly':
                week_ago = today - timedelta(days=7)
                if gap.last_collected_at and gap.last_collected_at.date() >= week_ago:
                    gap.is_overdue = False
                else:
                    gap.is_overdue = True
                    gap.days_overdue = 7 if not gap.last_collected_at else (today - gap.last_collected_at.date()).days

            gap.save()


class AgentSymptomCollectView(APIView):
    """
    API for agent to submit collected symptom data
    Simplified endpoint for conversational data collection
    """
    authentication_classes = [SimpleTokenAuthentication]
    permission_classes = [IsAuthenticated]

    def post(self, request):
        """Submit a single symptom value collected by agent"""
        try:
            serializer = AgentSymptomCollectionSerializer(data=request.data)
            if not serializer.is_valid():
                return error_response(serializer.errors, status.HTTP_400_BAD_REQUEST)

            data = serializer.validated_data
            symptom_type = data['symptom_type']
            value = data['value']
            data_source = data.get('data_source', 'patient')
            notes = data.get('notes', '')
            today = date.today()

            # Map symptom to appropriate model
            motor_symptoms = ['bradykinesia', 'tremor', 'rigidity', 'gait', 'laterality']
            non_motor_symptoms = ['sleep', 'constipation', 'mood', 'fatigue', 'dizziness', 'smell']

            if symptom_type in motor_symptoms:
                entry, created = MotorSymptomEntry.objects.get_or_create(
                    user=request.user,
                    recorded_date=today,
                    defaults={
                        'bradykinesia': 1,  # Will be overwritten
                        'laterality': 'B',  # Default
                        'data_source': data_source
                    }
                )
                # Map symptom to field
                field_map = {
                    'bradykinesia': 'bradykinesia',
                    'tremor': 'tremor',
                    'rigidity': 'rigidity',
                    'gait': 'gait_difficulty',
                }
                if symptom_type == 'laterality':
                    entry.laterality = data.get('laterality_value', 'B')
                else:
                    setattr(entry, field_map[symptom_type], value)
                if notes:
                    entry.notes = (entry.notes or '') + f" {symptom_type}: {notes}"
                entry.save()

                # Update data collection tracking
                gap = AgentDataCollection.objects.filter(
                    user=request.user,
                    domain='motor',
                    field_name=symptom_type
                ).first()
                if gap:
                    gap.last_collected_at = timezone.now()
                    gap.is_overdue = False
                    gap.save()

            elif symptom_type in non_motor_symptoms:
                entry, created = NonMotorSymptomEntry.objects.get_or_create(
                    user=request.user,
                    recorded_date=today,
                    defaults={'data_source': data_source}
                )
                field_map = {
                    'sleep': 'sleep_disturbance',
                    'constipation': 'constipation',
                    'mood': 'mood_apathy',
                    'fatigue': 'fatigue',
                    'dizziness': 'dizziness',
                    'smell': 'smell_loss',
                }
                setattr(entry, field_map[symptom_type], value)
                if notes:
                    entry.notes = (entry.notes or '') + f" {symptom_type}: {notes}"
                entry.save()

                # Update data collection tracking
                gap = AgentDataCollection.objects.filter(
                    user=request.user,
                    domain='non_motor',
                    field_name=symptom_type
                ).first()
                if gap:
                    gap.last_collected_at = timezone.now()
                    gap.is_overdue = False
                    gap.save()

            return success_response({'recorded': symptom_type, 'value': value}, "Symptom recorded")
        except Exception as e:
            logger.error("Error recording symptom: %s", e)
            return error_response("Failed to record symptom", status.HTTP_500_INTERNAL_SERVER_ERROR)
