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
                'is_finalized': report.is_finalized,
                'pdf_available': bool(report.pdf_file),
                'created_at': report.created_at.isoformat(),
            })

        return success_response(reports_data)

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

