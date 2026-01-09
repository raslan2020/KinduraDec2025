import logging
from django.shortcuts import render
from rest_framework import viewsets, status
from rest_framework.decorators import action
from rest_framework.response import Response
from rest_framework.permissions import AllowAny, IsAuthenticated
from django.contrib.auth import authenticate
from .models import User
from .serializers import (
    UserSignupSerializer, UserLoginSerializer,
    UserProfileSerializer, UserTokenSerializer, UserJSONUploadSerializer,
    ContactSerializer, ContactListSerializer
)
from utils.response_utils import success_response, error_response
from utils.authentication import create_user_token, SimpleTokenAuthentication
from rest_framework.parsers import MultiPartParser, FormParser
from .tasks import start_background_processing

logger = logging.getLogger(__name__)


class UserViewSet(viewsets.ViewSet):
    """
    ViewSet for user authentication and profile management
    """
    authentication_classes = [SimpleTokenAuthentication]
    
    @action(detail=False, methods=['post'], permission_classes=[AllowAny])
    def signup(self, request):
        """
        User signup endpoint
        """
        serializer = UserSignupSerializer(data=request.data)
        if serializer.is_valid():
            user = serializer.save()
            user_token = create_user_token(user)
            token_serializer = UserTokenSerializer(user_token)
            
            return success_response({
                'user': {
                    'id': user.id,
                    'email': user.email,
                    'username': user.username
                },
                'token': token_serializer.data['token']
            }, "User registered successfully", status.HTTP_201_CREATED)
        else:
            return error_response(serializer.errors, status.HTTP_400_BAD_REQUEST)
    
    @action(detail=False, methods=['post'], permission_classes=[AllowAny])
    def login(self, request):
        """
        User login endpoint
        """
        serializer = UserLoginSerializer(data=request.data)
        if serializer.is_valid():
            user = serializer.validated_data['user']
            user_token = create_user_token(user)
            token_serializer = UserTokenSerializer(user_token)
            
            return success_response({
                'user': {
                    'id': user.id,
                    'email': user.email,
                    'username': user.username
                },
                'token': token_serializer.data['token']
            }, "Login successful")
        else:
            return error_response(serializer.errors, status.HTTP_400_BAD_REQUEST)
    
    @action(detail=False, methods=['get', 'put'], permission_classes=[IsAuthenticated])
    def profile(self, request):
        """
        Get and update user profile
        """
        if request.method == 'GET':
            serializer = UserProfileSerializer(request.user)
            return success_response(serializer.data)
        
        elif request.method == 'PUT':
            serializer = UserProfileSerializer(request.user, data=request.data, partial=True)
            if serializer.is_valid():
                serializer.save()
                return success_response(serializer.data, "Profile updated successfully")
            else:
                return error_response(serializer.errors, status.HTTP_400_BAD_REQUEST)
    
    @action(detail=False, methods=['post'], permission_classes=[IsAuthenticated])
    def logout(self, request):
        """
        User logout endpoint
        """
        # Deactivate current token
        token = request.auth
        if token:
            from .models import UserToken
            UserToken.objects.filter(token=token).update(is_active=False)
        
        return success_response(message="Logout successful")

    @action(detail=False, methods=['post'], permission_classes=[IsAuthenticated], parser_classes=[MultiPartParser, FormParser])
    def upload_json(self, request):
        """
        Upload a JSON file and store its content for the authenticated user
        Processing happens asynchronously in the background
        """
        serializer = UserJSONUploadSerializer(data=request.data, context={'request': request})
        if serializer.is_valid():
            json_upload = serializer.save()
            
            # Start background processing
            start_background_processing(json_upload.id)
            
            return success_response({
                'id': json_upload.id,
                'status': json_upload.status,
                'uploaded_at': json_upload.uploaded_at,
                'message': 'JSON uploaded successfully. Processing started in background.'
            }, "JSON uploaded successfully", status.HTTP_201_CREATED)
        return error_response(serializer.errors, status.HTTP_400_BAD_REQUEST)

    @action(detail=True, methods=['get'], permission_classes=[IsAuthenticated])
    def json_status(self, request, pk=None):
        """
        Check the processing status of a JSON upload
        """
        try:
            from .models import UserJSON
            json_upload = UserJSON.objects.get(id=pk, user=request.user)
            
            response_data = {
                'id': json_upload.id,
                'status': json_upload.status,
                'uploaded_at': json_upload.uploaded_at,
                'summarize_patient_report': json_upload.summarize_patient_report,
            }
            
            if json_upload.status == 'completed':
                response_data['summarize_patient_report'] = json_upload.summarize_patient_report
            elif json_upload.status == 'failed':
                response_data['error_message'] = json_upload.error_message
            
            return success_response(response_data)
            
        except UserJSON.DoesNotExist:
            return error_response("JSON upload not found", status.HTTP_404_NOT_FOUND)

    @action(detail=False, methods=['get'], permission_classes=[IsAuthenticated])
    def json_uploads(self, request):
        """
        Get all JSON uploads for the authenticated user or a specific upload by ID
        """
        from .models import UserJSON
        upload_id = request.query_params.get('id')

        if upload_id:
            try:
                upload = UserJSON.objects.get(id=upload_id, user=request.user)
                upload_data = {
                    'id': upload.id,
                    'status': upload.status,
                    'uploaded_at': upload.uploaded_at,
                    'summarize_patient_report': upload.summarize_patient_report,
                    'conservation': upload.data
                }

                if upload.status == 'completed':
                    upload_data['summarize_patient_report'] = upload.summarize_patient_report
                elif upload.status == 'failed':
                    upload_data['error_message'] = upload.error_message

                return success_response(upload_data)
            except UserJSON.DoesNotExist:
                return error_response("Upload with given ID not found.", status=404)

        json_uploads = UserJSON.objects.filter(user=request.user).order_by('-uploaded_at')

        uploads_data = []
        for upload in json_uploads:
            upload_data = {
                'id': upload.id,
                'status': upload.status,
                'uploaded_at': upload.uploaded_at,
                'summarize_patient_report': upload.summarize_patient_report,
                'conservation': upload.data
            }

            if upload.status == 'completed':
                upload_data['summarize_patient_report'] = upload.summarize_patient_report
            elif upload.status == 'failed':
                upload_data['error_message'] = upload.error_message

            uploads_data.append(upload_data)

        return success_response(uploads_data)

    @action(detail=False, methods=['post'], permission_classes=[AllowAny])
    def forgot_password(self, request):
        """
        Request password reset - sends OTP code to user's email
        """
        email = request.data.get('email', '').strip().lower()

        if not email:
            return error_response({'email': ['Email is required']}, status.HTTP_400_BAD_REQUEST)

        try:
            user = User.objects.get(email=email)
        except User.DoesNotExist:
            # Return success even if user doesn't exist (security)
            return success_response(message="If an account exists with this email, a reset code has been sent")

        # Invalidate any existing tokens
        from .models import PasswordResetToken
        PasswordResetToken.objects.filter(user=user, is_used=False).update(is_used=True)

        # Create new reset token
        reset_token = PasswordResetToken.objects.create(user=user)

        # TODO: Send email with reset code
        # For now, log the code (in production, send via email service)
        logger.info("Password reset code for %s: %s", email, reset_token.token)

        return success_response({
            'message': 'Reset code sent to your email',
            # Remove this in production - only for testing
            'debug_code': reset_token.token
        }, "If an account exists with this email, a reset code has been sent")

    @action(detail=False, methods=['post'], permission_classes=[AllowAny])
    def verify_reset_code(self, request):
        """
        Verify the OTP code sent to user's email
        """
        email = request.data.get('email', '').strip().lower()
        code = request.data.get('code', '').strip()

        if not email or not code:
            return error_response({'error': ['Email and code are required']}, status.HTTP_400_BAD_REQUEST)

        try:
            user = User.objects.get(email=email)
        except User.DoesNotExist:
            return error_response({'error': ['Invalid email or code']}, status.HTTP_400_BAD_REQUEST)

        from .models import PasswordResetToken
        try:
            reset_token = PasswordResetToken.objects.get(
                user=user,
                token=code,
                is_used=False
            )
        except PasswordResetToken.DoesNotExist:
            return error_response({'error': ['Invalid or expired code']}, status.HTTP_400_BAD_REQUEST)

        if not reset_token.is_valid():
            return error_response({'error': ['Code has expired']}, status.HTTP_400_BAD_REQUEST)

        return success_response({
            'valid': True,
            'message': 'Code verified successfully'
        })

    @action(detail=False, methods=['post'], permission_classes=[AllowAny])
    def reset_password(self, request):
        """
        Reset password using the verified OTP code
        """
        email = request.data.get('email', '').strip().lower()
        code = request.data.get('code', '').strip()
        new_password = request.data.get('new_password', '')
        confirm_password = request.data.get('confirm_password', '')

        if not all([email, code, new_password, confirm_password]):
            return error_response({'error': ['All fields are required']}, status.HTTP_400_BAD_REQUEST)

        if new_password != confirm_password:
            return error_response({'error': ['Passwords do not match']}, status.HTTP_400_BAD_REQUEST)

        if len(new_password) < 8:
            return error_response({'error': ['Password must be at least 8 characters']}, status.HTTP_400_BAD_REQUEST)

        try:
            user = User.objects.get(email=email)
        except User.DoesNotExist:
            return error_response({'error': ['Invalid email or code']}, status.HTTP_400_BAD_REQUEST)

        from .models import PasswordResetToken
        try:
            reset_token = PasswordResetToken.objects.get(
                user=user,
                token=code,
                is_used=False
            )
        except PasswordResetToken.DoesNotExist:
            return error_response({'error': ['Invalid or expired code']}, status.HTTP_400_BAD_REQUEST)

        if not reset_token.is_valid():
            return error_response({'error': ['Code has expired']}, status.HTTP_400_BAD_REQUEST)

        # Reset password
        user.set_password(new_password)
        user.save()

        # Mark token as used
        reset_token.is_used = True
        reset_token.save()

        # Invalidate all existing auth tokens
        from .models import UserToken
        UserToken.objects.filter(user=user).update(is_active=False)

        return success_response(message="Password reset successfully. Please login with your new password")

    @action(detail=False, methods=['get'], permission_classes=[IsAuthenticated])
    def patient_reports(self, request):
        """
        Get patient reports (daily, weekly, monthly)
        """
        from .models import PatientReport
        from datetime import datetime

        report_type = request.query_params.get('type')  # daily, weekly, monthly
        limit = int(request.query_params.get('limit', 10))

        queryset = PatientReport.objects.filter(user=request.user)

        if report_type:
            queryset = queryset.filter(report_type=report_type)

        reports = queryset[:limit]

        reports_data = []
        for report in reports:
            # Fetch clinical data for this report's period
            clinical_data = self._get_clinical_data_for_period(
                request.user, report.period_start, report.period_end
            )

            reports_data.append({
                'id': report.id,
                'report_type': report.report_type,
                'report_date': report.report_date.isoformat(),
                'period_start': report.period_start.isoformat(),
                'period_end': report.period_end.isoformat(),
                # Health Scores
                'overall_health_score': report.overall_health_score,
                'adherence_score': report.adherence_score,
                'sleep_score': report.sleep_score,
                'vitals_score': report.vitals_score,
                # Medication stats
                'adherence_percentage': report.adherence_percentage,
                'adherence_grade': report.adherence_grade,
                'doses_taken': report.doses_taken,
                'doses_missed': report.doses_missed,
                'doses_late': report.doses_late,
                'total_doses': report.total_doses_scheduled,
                'side_effects_count': report.side_effects_count,
                'side_effects_reported': report.side_effects_reported,
                # Analytics data for graphs
                'vitals_analytics': report.vitals_analytics,
                'sleep_analytics': report.sleep_analytics,
                'medication_analytics': report.medication_analytics,
                'biomarker_trends': report.biomarker_trends,
                # Fall events
                'fall_count': report.fall_count,
                'fall_events': report.fall_events,
                # Clinical data (per Reports.md)
                'clinical_data': clinical_data,
                # AI analysis
                'ai_summary': report.ai_summary,
                'ai_observations': report.ai_observations,
                'ai_recommendations': report.ai_recommendations,
                'ai_concerns': report.ai_concerns,
                'ai_doctor_summary': report.ai_doctor_summary,
                'ai_patient_summary': report.ai_patient_summary,
                'ai_medication_insights': report.ai_medication_insights,
                'ai_sleep_analysis': report.ai_sleep_analysis,
                'ai_vitals_analysis': report.ai_vitals_analysis,
                'ai_side_effect_correlations': report.ai_side_effect_correlations,
                'ai_clinical_insights': clinical_data.get('ai_insights'),
                # Meta
                'conversation_count': report.conversation_count,
                'is_finalized': report.is_finalized,
                'pdf_available': bool(report.pdf_file),
                'created_at': report.created_at.isoformat(),
            })

        return success_response(reports_data)

    def _get_clinical_data_for_period(self, user, start_date, end_date):
        """
        Fetch clinical data (motor symptoms, non-motor symptoms, safety events)
        for a given period. Per Reports.md specification.
        """
        try:
            from health_profile.models import MotorSymptomEntry, NonMotorSymptomEntry, SafetyEvent

            # Fetch motor symptoms for period
            motor_symptoms = MotorSymptomEntry.objects.filter(
                user=user,
                recorded_date__gte=start_date,
                recorded_date__lte=end_date
            ).order_by('recorded_date').values(
                'recorded_date', 'bradykinesia', 'tremor', 'rigidity',
                'gait_difficulty', 'laterality', 'data_source'
            )

            # Fetch non-motor symptoms for period
            non_motor_symptoms = NonMotorSymptomEntry.objects.filter(
                user=user,
                recorded_date__gte=start_date,
                recorded_date__lte=end_date
            ).order_by('recorded_date').values(
                'recorded_date', 'sleep_quality', 'constipation', 'mood',
                'fatigue', 'dizziness', 'smell_loss', 'rem_behavior', 'data_source'
            )

            # Fetch safety events for period
            safety_events = SafetyEvent.objects.filter(
                user=user,
                occurred_at__date__gte=start_date,
                occurred_at__date__lte=end_date
            ).order_by('-occurred_at').values(
                'event_type', 'severity', 'description', 'occurred_at',
                'injury_sustained', 'data_source'
            )

            # Calculate motor symptom averages
            motor_score = {}
            if motor_symptoms:
                motor_list = list(motor_symptoms)
                motor_score = {
                    'bradykinesia_avg': sum(m['bradykinesia'] or 0 for m in motor_list) / len(motor_list),
                    'tremor_avg': sum(m['tremor'] or 0 for m in motor_list) / len(motor_list),
                    'rigidity_avg': sum(m['rigidity'] or 0 for m in motor_list) / len(motor_list),
                    'gait_avg': sum(m['gait_difficulty'] or 0 for m in motor_list) / len(motor_list),
                    'laterality': motor_list[-1]['laterality'] if motor_list else None,
                }

            # Calculate non-motor symptom averages
            non_motor_score = {}
            if non_motor_symptoms:
                non_motor_list = list(non_motor_symptoms)
                non_motor_score = {
                    'sleep_avg': sum(m['sleep_quality'] or 0 for m in non_motor_list) / len(non_motor_list),
                    'constipation_avg': sum(m['constipation'] or 0 for m in non_motor_list) / len(non_motor_list),
                    'mood_avg': sum(m['mood'] or 0 for m in non_motor_list) / len(non_motor_list),
                    'fatigue_avg': sum(m['fatigue'] or 0 for m in non_motor_list) / len(non_motor_list),
                }

            # Calculate data completeness per Reports.md Section 6
            days_in_period = (end_date - start_date).days + 1
            motor_days = motor_symptoms.count()
            completeness = min(100, (motor_days / days_in_period) * 100) if days_in_period > 0 else 0

            return {
                'motor_symptoms': list(motor_symptoms),
                'non_motor_symptoms': list(non_motor_symptoms),
                'safety_events': list(safety_events),
                'motor_score': motor_score,
                'non_motor_score': non_motor_score,
                'data_completeness': round(completeness, 1),
                'ai_insights': None,  # Populated during report generation
            }
        except Exception as e:
            print(f"Error fetching clinical data: {e}")
            return {
                'motor_symptoms': [],
                'non_motor_symptoms': [],
                'safety_events': [],
                'motor_score': {},
                'non_motor_score': {},
                'data_completeness': 0,
                'ai_insights': None,
            }

    @action(detail=False, methods=['get'], permission_classes=[IsAuthenticated], url_path='patient_reports/(?P<report_id>[^/.]+)')
    def patient_report_detail(self, request, report_id=None):
        """
        Get detailed patient report
        """
        from .models import PatientReport

        try:
            report = PatientReport.objects.get(id=report_id, user=request.user)

            return success_response({
                'id': report.id,
                'report_type': report.report_type,
                'report_date': report.report_date.isoformat(),
                'period_start': report.period_start.isoformat(),
                'period_end': report.period_end.isoformat(),
                # Health Scores
                'overall_health_score': report.overall_health_score,
                'adherence_score': report.adherence_score,
                'sleep_score': report.sleep_score,
                'vitals_score': report.vitals_score,
                # Medication stats
                'adherence_percentage': report.adherence_percentage,
                'adherence_grade': report.adherence_grade,
                'total_doses_scheduled': report.total_doses_scheduled,
                'doses_taken': report.doses_taken,
                'doses_missed': report.doses_missed,
                'doses_late': report.doses_late,
                'side_effects_reported': report.side_effects_reported,
                'side_effects_count': report.side_effects_count,
                # Analytics data for graphs
                'vitals_analytics': report.vitals_analytics,
                'sleep_analytics': report.sleep_analytics,
                'medication_analytics': report.medication_analytics,
                'biomarker_trends': report.biomarker_trends,
                # Fall events
                'fall_count': report.fall_count,
                'fall_events': report.fall_events,
                # Legacy fields
                'sleep_quality_avg': report.sleep_quality_avg,
                'energy_level_avg': report.energy_level_avg,
                'mood_observations': report.mood_observations,
                'symptom_observations': report.symptom_observations,
                # AI analysis
                'ai_summary': report.ai_summary,
                'ai_observations': report.ai_observations,
                'ai_recommendations': report.ai_recommendations,
                'ai_concerns': report.ai_concerns,
                'ai_doctor_summary': report.ai_doctor_summary,
                'ai_patient_summary': report.ai_patient_summary,
                'ai_medication_insights': report.ai_medication_insights,
                'ai_sleep_analysis': report.ai_sleep_analysis,
                'ai_vitals_analysis': report.ai_vitals_analysis,
                'ai_side_effect_correlations': report.ai_side_effect_correlations,
                # Meta
                'conversation_count': report.conversation_count,
                'conversations_data': report.conversations_data,
                'is_finalized': report.is_finalized,
                'pdf_available': bool(report.pdf_file),
                'pdf_url': report.pdf_file.url if report.pdf_file else None,
                'created_at': report.created_at.isoformat(),
                'updated_at': report.updated_at.isoformat(),
            })
        except PatientReport.DoesNotExist:
            return error_response("Report not found", status.HTTP_404_NOT_FOUND)

    @action(detail=False, methods=['post'], permission_classes=[IsAuthenticated])
    def update_patient_report(self, request):
        """
        Update or create patient report (called by LiveKit agent)
        """
        from .models import PatientReport
        from datetime import date, timedelta

        data = request.data
        report_type = data.get('report_type', 'daily')

        # Determine report date and period
        today = date.today()
        if report_type == 'daily':
            report_date = today
            period_start = today
            period_end = today
        elif report_type == 'weekly':
            # Week starts on Monday
            period_start = today - timedelta(days=today.weekday())
            period_end = period_start + timedelta(days=6)
            report_date = period_end
        else:  # monthly
            period_start = today.replace(day=1)
            # Last day of month
            next_month = today.replace(day=28) + timedelta(days=4)
            period_end = next_month - timedelta(days=next_month.day)
            report_date = period_end

        # Get or create report
        report, created = PatientReport.objects.get_or_create(
            user=request.user,
            report_type=report_type,
            report_date=report_date,
            defaults={
                'period_start': period_start,
                'period_end': period_end,
            }
        )

        # Update fields from agent data
        if 'adherence_percentage' in data:
            report.adherence_percentage = data['adherence_percentage']
        if 'doses_taken' in data:
            report.doses_taken = data['doses_taken']
        if 'doses_missed' in data:
            report.doses_missed = data['doses_missed']
        if 'doses_late' in data:
            report.doses_late = data['doses_late']
        if 'total_doses' in data:
            report.total_doses_scheduled = data['total_doses']
        if 'side_effects' in data:
            report.side_effects_reported = data['side_effects']
            report.side_effects_count = len(data['side_effects'])
        if 'sleep_quality' in data:
            report.sleep_quality_avg = data['sleep_quality']
        if 'energy_level' in data:
            report.energy_level_avg = data['energy_level']
        if 'mood_observations' in data:
            report.mood_observations = data['mood_observations']
        if 'symptom_observations' in data:
            report.symptom_observations = data['symptom_observations']
        if 'ai_summary' in data:
            report.ai_summary = data['ai_summary']
        if 'ai_observations' in data:
            report.ai_observations = data['ai_observations']
        if 'ai_recommendations' in data:
            report.ai_recommendations = data['ai_recommendations']
        if 'ai_concerns' in data:
            report.ai_concerns = data['ai_concerns']
        if 'conversation_summary' in data:
            report.conversations_data.append(data['conversation_summary'])
            report.conversation_count = len(report.conversations_data)

        report.save()

        return success_response({
            'id': report.id,
            'report_type': report.report_type,
            'report_date': report.report_date.isoformat(),
            'created': created,
        }, "Report updated successfully")

    @action(detail=False, methods=['post'], permission_classes=[IsAuthenticated])
    def save_observation(self, request):
        """
        Save patient observation from agent conversation.
        Called by LiveKit agent after each conversation.
        """
        from .models import PatientObservation
        from django.utils import timezone

        data = request.data

        observation = PatientObservation.objects.create(
            user=request.user,
            observation_type=data.get('type', 'general'),
            severity=data.get('severity', 'normal'),
            title=data.get('title', ''),
            description=data.get('description', ''),
            value=data.get('value'),
            medication_id=data.get('medication_id'),
            conversation_id=data.get('conversation_id'),
            ai_insight=data.get('ai_insight'),
            ai_concern_level=data.get('concern_level', 0),
            requires_attention=data.get('requires_attention', False),
            observed_at=timezone.now(),
            source=data.get('source', 'voice')
        )

        return success_response({
            'id': observation.id,
            'type': observation.observation_type,
            'created_at': observation.created_at.isoformat(),
        }, "Observation saved successfully", status.HTTP_201_CREATED)

    @action(detail=False, methods=['post'], permission_classes=[IsAuthenticated], url_path='patient_reports/generate')
    def generate_report(self, request):
        """
        Generate comprehensive AI-analyzed report with enhanced analytics.
        Uses ReportService to collect all health data and generate insights.
        """
        from .report_service import ReportService

        report_type = request.data.get('type') or request.data.get('report_type', 'daily')

        try:
            # Use the enhanced ReportService
            service = ReportService(request.user)
            report_data = service.generate_comprehensive_report(report_type)
            report = service.save_report(report_data)

            # Prepare rich response with analytics data
            response_data = {
                'id': report.id,
                'report_type': report.report_type,
                'report_date': report.report_date.isoformat(),
                'period_start': report.period_start.isoformat(),
                'period_end': report.period_end.isoformat(),
                # Scores
                'overall_health_score': report.overall_health_score,
                'adherence_score': report.adherence_score,
                'sleep_score': report.sleep_score,
                'vitals_score': report.vitals_score,
                # Medication stats
                'adherence_percentage': report.adherence_percentage,
                'total_doses_scheduled': report.total_doses_scheduled,
                'doses_taken': report.doses_taken,
                'doses_missed': report.doses_missed,
                'doses_late': report.doses_late,
                'side_effects_count': report.side_effects_count,
                # Analytics data for graphs
                'vitals_analytics': report.vitals_analytics,
                'sleep_analytics': report.sleep_analytics,
                'medication_analytics': report.medication_analytics,
                'biomarker_trends': report.biomarker_trends,
                # Fall events
                'fall_count': report.fall_count,
                'fall_events': report.fall_events,
                # AI analysis
                'ai_doctor_summary': report.ai_doctor_summary,
                'ai_patient_summary': report.ai_patient_summary,
                'ai_medication_insights': report.ai_medication_insights,
                'ai_sleep_analysis': report.ai_sleep_analysis,
                'ai_vitals_analysis': report.ai_vitals_analysis,
                'ai_side_effect_correlations': report.ai_side_effect_correlations,
                'ai_summary': report.ai_summary,
                'ai_observations': report.ai_observations,
                'ai_recommendations': report.ai_recommendations,
                'ai_concerns': report.ai_concerns,
            }

            return success_response(response_data, "Report generated successfully")

        except Exception as e:
            logger.exception("Error generating report: %s", e)
            return error_response(f"Failed to generate report: {str(e)}", status.HTTP_500_INTERNAL_SERVER_ERROR)

    @action(detail=False, methods=['post'], permission_classes=[IsAuthenticated], url_path='patient_reports/generate_async')
    def generate_report_async(self, request):
        """
        Start background report generation and return immediately.
        Returns report ID for status polling.
        """
        from .models import PatientReport
        from datetime import date, timedelta
        import threading

        report_type = request.data.get('type') or request.data.get('report_type', 'daily')

        # Determine date range for report
        today = date.today()
        if report_type == 'daily':
            period_start = today
            period_end = today
        elif report_type == 'weekly':
            period_start = today - timedelta(days=today.weekday())
            period_end = period_start + timedelta(days=6)
        else:  # monthly
            period_start = today.replace(day=1)
            next_month = today.replace(day=28) + timedelta(days=4)
            period_end = next_month - timedelta(days=next_month.day)

        # Check if report already exists for this date/type
        existing = PatientReport.objects.filter(
            user=request.user,
            report_type=report_type,
            report_date=period_end
        ).first()

        if existing:
            if existing.status == 'processing':
                # Already processing, return current status
                return success_response({
                    'report_id': existing.id,
                    'status': 'processing',
                    'progress': existing.progress,
                    'message': 'Report generation already in progress'
                })
            else:
                # Reset existing report for regeneration
                existing.status = 'processing'
                existing.progress = 0
                existing.error_message = None
                existing.period_start = period_start
                existing.period_end = period_end
                existing.report_data = None
                existing.ai_analysis = None
                existing.health_score = None
                existing.save()
                report = existing
        else:
            # Create new report with 'processing' status
            report = PatientReport.objects.create(
                user=request.user,
                report_type=report_type,
                report_date=period_end,
                period_start=period_start,
                period_end=period_end,
                status='processing',
                progress=0
            )

        # Start background generation
        def generate_in_background(report_id, user_id):
            from .models import PatientReport, User
            from .report_service import ReportService
            from django.db import connection

            try:
                # Re-fetch objects in new thread (Django connections are not thread-safe)
                connection.close()
                report = PatientReport.objects.get(id=report_id)
                user = User.objects.get(id=user_id)

                # Generate report with progress tracking
                service = ReportService(user, report_instance=report)
                report_data = service.generate_comprehensive_report(report_type)
                service.save_report(report_data)

                logger.info(f"Background report {report_id} completed successfully")

            except Exception as e:
                logger.exception(f"Background report {report_id} failed: {e}")
                try:
                    report = PatientReport.objects.get(id=report_id)
                    report.status = 'failed'
                    report.error_message = str(e)
                    report.save()
                except Exception:
                    pass

        thread = threading.Thread(
            target=generate_in_background,
            args=(report.id, request.user.id),
            daemon=True
        )
        thread.start()

        return success_response({
            'report_id': report.id,
            'status': 'processing',
            'progress': 0,
            'message': 'Report generation started'
        }, status_code=status.HTTP_202_ACCEPTED)

    @action(detail=False, methods=['get'], permission_classes=[IsAuthenticated], url_path='patient_reports/(?P<report_id>[^/.]+)/status')
    def report_status(self, request, report_id=None):
        """
        Get the status and progress of a report generation.
        """
        from .models import PatientReport

        try:
            report = PatientReport.objects.get(id=report_id, user=request.user)
        except PatientReport.DoesNotExist:
            return error_response("Report not found", status.HTTP_404_NOT_FOUND)

        response_data = {
            'report_id': report.id,
            'report_type': report.report_type,
            'status': report.status,
            'progress': report.progress,
        }

        if report.status == 'failed':
            response_data['error_message'] = report.error_message

        if report.status == 'completed':
            # Include full report data
            response_data.update({
                'report_date': report.report_date.isoformat(),
                'period_start': report.period_start.isoformat(),
                'period_end': report.period_end.isoformat(),
                'overall_health_score': report.overall_health_score,
                'adherence_score': report.adherence_score,
                'sleep_score': report.sleep_score,
                'vitals_score': report.vitals_score,
                'adherence_percentage': report.adherence_percentage,
                'ai_doctor_summary': report.ai_doctor_summary,
                'ai_patient_summary': report.ai_patient_summary,
            })

        return success_response(response_data)

    @action(detail=False, methods=['post'], permission_classes=[IsAuthenticated], url_path='patient_reports/(?P<report_id>[^/.]+)/generate_pdf')
    def generate_report_pdf(self, request, report_id=None):
        """
        Generate PDF for a patient report
        """
        from .models import PatientReport
        from .pdf_generator import generate_and_save_pdf

        if not report_id:
            report_id = request.data.get('report_id')

        try:
            report = PatientReport.objects.get(id=report_id, user=request.user)
        except PatientReport.DoesNotExist:
            return error_response("Report not found", status.HTTP_404_NOT_FOUND)

        try:
            pdf_url = generate_and_save_pdf(report)
            return success_response({
                'pdf_url': pdf_url,
                'report_id': report.id,
            }, "PDF generated successfully")
        except Exception as e:
            return error_response(f"Failed to generate PDF: {str(e)}", status.HTTP_500_INTERNAL_SERVER_ERROR)


class ContactViewSet(viewsets.ViewSet):
    """
    ViewSet for managing user contacts (family, caregivers, emergency contacts)
    """
    authentication_classes = [SimpleTokenAuthentication]
    permission_classes = [IsAuthenticated]

    def list(self, request):
        """
        Get all contacts for the authenticated user
        """
        from .models import Contact
        contact_type = request.query_params.get('type')
        emergency_only = request.query_params.get('emergency') == 'true'

        queryset = Contact.objects.filter(user=request.user, is_active=True)

        if contact_type:
            queryset = queryset.filter(contact_type=contact_type)
        if emergency_only:
            queryset = queryset.filter(is_emergency=True)

        serializer = ContactSerializer(queryset, many=True)
        return success_response(serializer.data)

    def create(self, request):
        """
        Create a new contact
        """
        serializer = ContactSerializer(data=request.data, context={'request': request})
        if serializer.is_valid():
            contact = serializer.save()
            return success_response(
                ContactSerializer(contact).data,
                "Contact created successfully",
                status.HTTP_201_CREATED
            )
        return error_response(serializer.errors, status.HTTP_400_BAD_REQUEST)

    def retrieve(self, request, pk=None):
        """
        Get a specific contact by ID
        """
        from .models import Contact
        try:
            contact = Contact.objects.get(id=pk, user=request.user, is_active=True)
            serializer = ContactSerializer(contact)
            return success_response(serializer.data)
        except Contact.DoesNotExist:
            return error_response("Contact not found", status.HTTP_404_NOT_FOUND)

    def update(self, request, pk=None):
        """
        Update an existing contact
        """
        from .models import Contact
        try:
            contact = Contact.objects.get(id=pk, user=request.user, is_active=True)
            serializer = ContactSerializer(contact, data=request.data, partial=True, context={'request': request})
            if serializer.is_valid():
                serializer.save()
                return success_response(serializer.data, "Contact updated successfully")
            return error_response(serializer.errors, status.HTTP_400_BAD_REQUEST)
        except Contact.DoesNotExist:
            return error_response("Contact not found", status.HTTP_404_NOT_FOUND)

    def destroy(self, request, pk=None):
        """
        Soft delete a contact
        """
        from .models import Contact
        try:
            contact = Contact.objects.get(id=pk, user=request.user)
            contact.is_active = False
            contact.save()
            return success_response(message="Contact deleted successfully")
        except Contact.DoesNotExist:
            return error_response("Contact not found", status.HTTP_404_NOT_FOUND)

    @action(detail=False, methods=['get'])
    def emergency(self, request):
        """
        Get emergency contacts only
        """
        from .models import Contact
        queryset = Contact.objects.filter(
            user=request.user,
            is_active=True,
            is_emergency=True
        )
        serializer = ContactSerializer(queryset, many=True)
        return success_response(serializer.data)

    @action(detail=False, methods=['get'])
    def for_agent(self, request):
        """
        Get contacts in a lightweight format for the agent
        """
        from .models import Contact
        queryset = Contact.objects.filter(user=request.user, is_active=True)
        serializer = ContactListSerializer(queryset, many=True)
        return success_response(serializer.data)

    @action(detail=True, methods=['get'])
    def facetime_info(self, request, pk=None):
        """
        Get FaceTime info for a contact
        """
        from .models import Contact
        try:
            contact = Contact.objects.get(id=pk, user=request.user, is_active=True)
            if not contact.facetime_available:
                return error_response("FaceTime not available for this contact", status.HTTP_400_BAD_REQUEST)
            return success_response({
                'id': contact.id,
                'name': contact.name,
                'facetime_target': contact.facetime_target,
                'facetime_url': f"facetime://{contact.facetime_target}",
                'facetime_audio_url': f"facetime-audio://{contact.facetime_target}",
            })
        except Contact.DoesNotExist:
            return error_response("Contact not found", status.HTTP_404_NOT_FOUND)


class DeviceContactViewSet(viewsets.ViewSet):
    """
    ViewSet for managing device contacts synced from iOS.
    Allows the AI agent to search contacts by name.
    """
    authentication_classes = [SimpleTokenAuthentication]
    permission_classes = [IsAuthenticated]

    def list(self, request):
        """Get all device contacts for the user"""
        from .models import DeviceContact
        queryset = DeviceContact.objects.filter(user=request.user)
        data = [{
            'id': c.id,
            'device_id': c.device_id,
            'full_name': c.full_name,
            'given_name': c.given_name,
            'family_name': c.family_name,
            'nickname': c.nickname,
            'organization': c.organization,
            'primary_phone': c.primary_phone,
            'primary_email': c.primary_email,
            'phone_numbers': c.phone_numbers,
            'emails': c.emails,
        } for c in queryset]
        return success_response(data)

    @action(detail=False, methods=['post'])
    def sync(self, request):
        """
        Bulk sync device contacts from iOS.
        Creates new contacts and updates existing ones.
        """
        from .models import DeviceContact
        contacts_data = request.data.get('contacts', [])

        if not contacts_data:
            return error_response("No contacts provided", status.HTTP_400_BAD_REQUEST)

        created = 0
        updated = 0

        for contact_data in contacts_data:
            device_id = contact_data.get('id')
            if not device_id:
                continue

            defaults = {
                'given_name': contact_data.get('givenName', ''),
                'family_name': contact_data.get('familyName', ''),
                'full_name': contact_data.get('fullName', ''),
                'nickname': contact_data.get('nickname'),
                'organization': contact_data.get('organization'),
                'phone_numbers': contact_data.get('phoneNumbers', []),
                'emails': contact_data.get('emails', []),
            }

            obj, was_created = DeviceContact.objects.update_or_create(
                user=request.user,
                device_id=device_id,
                defaults=defaults
            )

            if was_created:
                created += 1
            else:
                updated += 1

        return success_response({
            'created': created,
            'updated': updated,
            'total': created + updated,
        }, f"Synced {created + updated} contacts")

    @action(detail=False, methods=['get'])
    def search(self, request):
        """
        Search device contacts by name.
        Used by the AI agent to find contacts.
        """
        from .models import DeviceContact
        from django.db.models import Q

        query = request.query_params.get('q', '').strip()
        if not query:
            return error_response("Search query required", status.HTTP_400_BAD_REQUEST)

        queryset = DeviceContact.objects.filter(
            user=request.user
        ).filter(
            Q(full_name__icontains=query) |
            Q(given_name__icontains=query) |
            Q(family_name__icontains=query) |
            Q(nickname__icontains=query)
        )[:10]  # Limit to 10 results

        data = [{
            'id': c.id,
            'full_name': c.full_name,
            'primary_phone': c.primary_phone,
            'primary_email': c.primary_email,
        } for c in queryset]

        return success_response(data)


class CommunicationRequestViewSet(viewsets.ViewSet):
    """
    ViewSet for managing communication requests from the AI agent.
    Agent creates requests, Flutter app executes them.
    """
    authentication_classes = [SimpleTokenAuthentication]
    permission_classes = [IsAuthenticated]

    def list(self, request):
        """Get pending communication requests for the user"""
        from .models import CommunicationRequest
        from django.utils import timezone

        # Only get pending, non-expired requests
        queryset = CommunicationRequest.objects.filter(
            user=request.user,
            status='pending',
            expires_at__gt=timezone.now()
        )

        data = [{
            'id': r.id,
            'request_type': r.request_type,
            'contact_name': r.contact_name,
            'phone_number': r.phone_number,
            'email': r.email,
            'message_body': r.message_body,
            'agent_reason': r.agent_reason,
            'created_at': r.created_at.isoformat(),
            'expires_at': r.expires_at.isoformat(),
        } for r in queryset]

        return success_response(data)

    def create(self, request):
        """
        Create a communication request (called by AI agent).
        Uses contacts added in the Kindura app (family, caregivers, doctors).
        """
        from .models import CommunicationRequest, Contact
        from django.utils import timezone

        request_type = request.data.get('request_type')
        contact_name = request.data.get('contact_name')

        if not request_type or not contact_name:
            return error_response("request_type and contact_name are required", status.HTTP_400_BAD_REQUEST)

        # Try to find contact in Kindura app contacts
        phone_number = request.data.get('phone_number')
        email = request.data.get('email')

        if not phone_number and not email:
            # Search in Kindura contacts (family, caregivers, doctors, etc.)
            from django.db.models import Q
            contact = Contact.objects.filter(
                user=request.user,
                is_active=True
            ).filter(
                Q(name__icontains=contact_name)
            ).first()

            if contact:
                phone_number = contact.phone_number
                email = contact.email
                contact_name = contact.name  # Use exact name from contact

        if not phone_number and not email:
            return error_response(
                f"Contact '{contact_name}' not found in your Kindura contacts. "
                "Please add them as a family member, caregiver, or emergency contact first.",
                status.HTTP_404_NOT_FOUND
            )

        # Create the request
        comm_request = CommunicationRequest.objects.create(
            user=request.user,
            request_type=request_type,
            contact_name=contact_name,
            phone_number=phone_number,
            email=email,
            message_body=request.data.get('message_body'),
            agent_reason=request.data.get('agent_reason'),
            conversation_id=request.data.get('conversation_id'),
            expires_at=timezone.now() + timezone.timedelta(minutes=5)
        )

        return success_response({
            'id': comm_request.id,
            'request_type': comm_request.request_type,
            'contact_name': comm_request.contact_name,
            'phone_number': comm_request.phone_number,
            'message_body': comm_request.message_body,
            'expires_at': comm_request.expires_at.isoformat(),
        }, "Communication request created", status.HTTP_201_CREATED)

    @action(detail=True, methods=['post'])
    def approve(self, request, pk=None):
        """Mark request as approved (user confirmed)"""
        from .models import CommunicationRequest
        try:
            comm_request = CommunicationRequest.objects.get(id=pk, user=request.user)
            comm_request.status = 'approved'
            comm_request.save()
            return success_response({'status': 'approved'})
        except CommunicationRequest.DoesNotExist:
            return error_response("Request not found", status.HTTP_404_NOT_FOUND)

    @action(detail=True, methods=['post'])
    def reject(self, request, pk=None):
        """Mark request as rejected (user declined)"""
        from .models import CommunicationRequest
        try:
            comm_request = CommunicationRequest.objects.get(id=pk, user=request.user)
            comm_request.status = 'rejected'
            comm_request.save()
            return success_response({'status': 'rejected'})
        except CommunicationRequest.DoesNotExist:
            return error_response("Request not found", status.HTTP_404_NOT_FOUND)

    @action(detail=True, methods=['post'])
    def complete(self, request, pk=None):
        """Mark request as completed (action executed)"""
        from .models import CommunicationRequest
        from django.utils import timezone
        try:
            comm_request = CommunicationRequest.objects.get(id=pk, user=request.user)
            comm_request.status = 'completed'
            comm_request.completed_at = timezone.now()
            comm_request.save()
            return success_response({'status': 'completed'})
        except CommunicationRequest.DoesNotExist:
            return error_response("Request not found", status.HTTP_404_NOT_FOUND)

