from django.shortcuts import render
from rest_framework import viewsets, status
from rest_framework.permissions import IsAuthenticated
from .models import CourseMedicineSchedule, CourseDayTracking
from .serializers import CourseMedicineScheduleSerializer, CourseDayTrackingSerializer
from utils.response_utils import success_response, error_response
from utils.authentication import SimpleTokenAuthentication


class CourseMedicineScheduleViewSet(viewsets.ViewSet):
    """
    ViewSet for course medicine schedule management
    """
    authentication_classes = [SimpleTokenAuthentication]
    permission_classes = [IsAuthenticated]
    
    def get_queryset(self):
        return CourseMedicineSchedule.objects.filter(
            course__user=self.request.user,
            is_active=True
        )
    
    def list(self, request):
        """
        List all schedules for the authenticated user
        """
        try:
            schedules = self.get_queryset()
            serializer = CourseMedicineScheduleSerializer(schedules, many=True)
            return success_response(serializer.data)
        except Exception as e:
            return error_response(str(e), status.HTTP_500_INTERNAL_SERVER_ERROR)
    
    def create(self, request):
        """
        Create a new schedule
        """
        try:
            serializer = CourseMedicineScheduleSerializer(data=request.data)
            if serializer.is_valid():
                schedule = serializer.save()
                return success_response(
                    CourseMedicineScheduleSerializer(schedule).data,
                    "Schedule created successfully",
                    status.HTTP_201_CREATED
                )
            else:
                return error_response(serializer.errors, status.HTTP_400_BAD_REQUEST)
        except Exception as e:
            return error_response(str(e), status.HTTP_500_INTERNAL_SERVER_ERROR)
    
    def retrieve(self, request, pk=None):
        """
        Retrieve a specific schedule
        """
        try:
            schedule = self.get_queryset().get(pk=pk)
            serializer = CourseMedicineScheduleSerializer(schedule)
            return success_response(serializer.data)
        except CourseMedicineSchedule.DoesNotExist:
            return error_response("Schedule not found", status.HTTP_404_NOT_FOUND)
        except Exception as e:
            return error_response(str(e), status.HTTP_500_INTERNAL_SERVER_ERROR)
    
    def update(self, request, pk=None):
        """
        Update a schedule
        """
        try:
            schedule = self.get_queryset().get(pk=pk)
            serializer = CourseMedicineScheduleSerializer(schedule, data=request.data, partial=True)
            if serializer.is_valid():
                updated_schedule = serializer.save()
                return success_response(
                    CourseMedicineScheduleSerializer(updated_schedule).data,
                    "Schedule updated successfully"
                )
            else:
                return error_response(serializer.errors, status.HTTP_400_BAD_REQUEST)
        except CourseMedicineSchedule.DoesNotExist:
            return error_response("Schedule not found", status.HTTP_404_NOT_FOUND)
        except Exception as e:
            return error_response(str(e), status.HTTP_500_INTERNAL_SERVER_ERROR)
    
    def destroy(self, request, pk=None):
        """
        Soft delete a schedule (set is_active to False)
        """
        try:
            schedule = self.get_queryset().get(pk=pk)
            schedule.is_active = False
            schedule.save()
            return success_response(message="Schedule deleted successfully")
        except CourseMedicineSchedule.DoesNotExist:
            return error_response("Schedule not found", status.HTTP_404_NOT_FOUND)
        except Exception as e:
            return error_response(str(e), status.HTTP_500_INTERNAL_SERVER_ERROR)


class CourseDayTrackingViewSet(viewsets.ViewSet):
    """
    ViewSet for course day tracking management
    """
    authentication_classes = [SimpleTokenAuthentication]
    permission_classes = [IsAuthenticated]
    
    def get_queryset(self):
        return CourseDayTracking.objects.filter(
            course__user=self.request.user
        )
    
    def list(self, request):
        """
        List all tracking entries for the authenticated user
        """
        try:
            tracking_entries = self.get_queryset()
            serializer = CourseDayTrackingSerializer(tracking_entries, many=True)
            return success_response(serializer.data)
        except Exception as e:
            return error_response(str(e), status.HTTP_500_INTERNAL_SERVER_ERROR)
    
    def create(self, request):
        """
        Create a new tracking entry
        """
        try:
            serializer = CourseDayTrackingSerializer(data=request.data)
            if serializer.is_valid():
                tracking_entry = serializer.save()
                return success_response(
                    CourseDayTrackingSerializer(tracking_entry).data,
                    "Tracking entry created successfully",
                    status.HTTP_201_CREATED
                )
            else:
                return error_response(str(serializer.errors), status.HTTP_400_BAD_REQUEST)
        except Exception as e:
            return error_response(str(e), status.HTTP_500_INTERNAL_SERVER_ERROR)
    
    def retrieve(self, request, pk=None):
        """
        Retrieve a specific tracking entry
        """
        try:
            tracking_entry = self.get_queryset().get(pk=pk)
            serializer = CourseDayTrackingSerializer(tracking_entry)
            return success_response(serializer.data)
        except CourseDayTracking.DoesNotExist:
            return error_response("Tracking entry not found", status.HTTP_404_NOT_FOUND)
        except Exception as e:
            return error_response(str(e), status.HTTP_500_INTERNAL_SERVER_ERROR)
    
    def update(self, request, pk=None):
        """
        Update a specific tracking entry
        """
        try:
            tracking_entry = self.get_queryset().get(pk=pk)
            serializer = CourseDayTrackingSerializer(tracking_entry, data=request.data, partial=True)
            if serializer.is_valid():
                updated_entry = serializer.save()
                return success_response(
                    CourseDayTrackingSerializer(updated_entry).data,
                    "Tracking entry updated successfully"
                )
            else:
                return error_response(str(serializer.errors), status.HTTP_400_BAD_REQUEST)
        except CourseDayTracking.DoesNotExist:
            return error_response("Tracking entry not found", status.HTTP_404_NOT_FOUND)
        except Exception as e:
            return error_response(str(e), status.HTTP_500_INTERNAL_SERVER_ERROR)
    
    def destroy(self, request, pk=None):
        """
        Delete a tracking entry
        """
        try:
            tracking_entry = self.get_queryset().get(pk=pk)
            tracking_entry.delete()
            return success_response(message="Tracking entry deleted successfully")
        except CourseDayTracking.DoesNotExist:
            return error_response("Tracking entry not found", status.HTTP_404_NOT_FOUND)
        except Exception as e:
            return error_response(str(e), status.HTTP_500_INTERNAL_SERVER_ERROR)
