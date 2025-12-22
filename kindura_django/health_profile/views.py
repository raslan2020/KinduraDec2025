import logging
from django.shortcuts import render
from django.utils import timezone
from datetime import timedelta
from rest_framework import viewsets, status
from rest_framework.decorators import action
from rest_framework.permissions import IsAuthenticated
from rest_framework.views import APIView
from .models import HealthProfile, WatchVitals
from .serializers import HealthProfileSerializer, WatchVitalsSerializer, WatchVitalsSummarySerializer
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
                return error_response(str(e), status.HTTP_500_INTERNAL_SERVER_ERROR)
        
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
                return error_response(str(e), status.HTTP_500_INTERNAL_SERVER_ERROR)
        
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
                return error_response(str(e), status.HTTP_500_INTERNAL_SERVER_ERROR)


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
                'sleep_hours': latest_vitals.total_sleep_hours or 0,
                'awakenings': latest_vitals.awakenings_count,
                'sleep_quality': latest_vitals.sleep_quality_computed or latest_vitals.sleep_quality or 'unknown',
                'falls_count': falls_count,
                'last_updated': latest_vitals.recorded_at,
                'is_demo': False
            }

            return success_response(summary)

        except Exception as e:
            return error_response(str(e), status.HTTP_500_INTERNAL_SERVER_ERROR)

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
            return error_response(str(e), status.HTTP_500_INTERNAL_SERVER_ERROR)


class WatchVitalsDevView(APIView):
    """
    Development endpoint for Watch vitals - no authentication required
    Used for simulator testing where Watch can't share tokens with iPhone
    """
    authentication_classes = []
    permission_classes = []

    def post(self, request):
        """Store vitals from Watch simulator (development only)"""
        try:
            # For development, allow specifying user via email parameter
            from users.models import User
            user_email = request.data.get('user_email')

            if user_email:
                user = User.objects.filter(email=user_email).first()
                if not user:
                    return error_response(f"User with email {user_email} not found", status.HTTP_400_BAD_REQUEST)
            else:
                # Default to first user if no email specified
                user = User.objects.first()

            if not user:
                return error_response("No user found in database", status.HTTP_400_BAD_REQUEST)

            serializer = WatchVitalsSerializer(data=request.data)
            if serializer.is_valid():
                vitals = serializer.save(user=user)
                logger.info("Watch vitals saved for %s: HR=%s, O2=%s", user.email, vitals.heart_rate, vitals.blood_oxygen)

                # Broadcast to WebSocket clients
                channel_layer = get_channel_layer()
                vitals_data = WatchVitalsSerializer(vitals).data
                async_to_sync(channel_layer.group_send)(
                    'watch_vitals',
                    {
                        'type': 'watch_vitals_update',
                        'vitals': vitals_data
                    }
                )
                logger.debug("Broadcasted vitals via WebSocket")

                return success_response(
                    vitals_data,
                    "Watch vitals saved successfully (dev mode)",
                    status.HTTP_201_CREATED
                )
            return error_response(serializer.errors, status.HTTP_400_BAD_REQUEST)
        except Exception as e:
            logger.error("Error saving watch vitals: %s", e)
            return error_response(str(e), status.HTTP_500_INTERNAL_SERVER_ERROR)


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
            return error_response(str(e), status.HTTP_500_INTERNAL_SERVER_ERROR)
