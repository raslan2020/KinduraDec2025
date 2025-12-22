import logging
from django.shortcuts import render
from rest_framework import viewsets, status
from rest_framework.decorators import action
from rest_framework.permissions import IsAuthenticated
from .models import Course
from .serializers import CourseSerializer, CourseWithMedicinesAndSchedulesSerializer
from utils.response_utils import success_response, error_response
from utils.authentication import SimpleTokenAuthentication
from schedules.models import CourseMedicineSchedule
from schedules.models import CourseDayTracking
from django.utils import timezone
import os
import json
from llm_model.gpt_model import GPTModel
from utils.llm_prompt import pdf_to_markdown_prompt
from llm_model.pdf_markdown import pdf_to_markdown
from rest_framework.parsers import MultiPartParser, FormParser
from django.core.files.storage import default_storage
from django.core.files.base import ContentFile

logger = logging.getLogger(__name__)


class CourseViewSet(viewsets.ViewSet):
    """
    ViewSet for course management
    """
    authentication_classes = [SimpleTokenAuthentication]
    permission_classes = [IsAuthenticated]
    
    def get_queryset(self):
        return Course.objects.filter(user=self.request.user, is_active=True)
    
    def list(self, request):
        """
        List all courses for the authenticated user with medicines and schedules
        """
        try:
            courses = self.get_queryset().order_by('-created_at')
            final_response = []

            for course in courses:
                # Get all schedules with related medicines
                schedules = CourseMedicineSchedule.objects.filter(
                    course=course,
                    is_active=True
                ).select_related('medicine')

                # Prepare per-course response
                course_data = {
                    'course': {
                        'id': course.id,
                        'name': course.name,
                        'start_date': course.start_date,
                        'duration': course.duration,
                        'patient_history': course.patient_history,
                        'current_situation': course.current_situation,
                        'doctor_instructions': course.doctor_instructions,
                        'created_at': course.created_at,
                        'is_active': course.is_active
                    },
                    'medicines': [],
                    'schedules': []
                }

                # Unique medicines collection
                medicines_set = set()
                for schedule in schedules:
                    medicine = schedule.medicine
                    medicines_set.add(medicine)

                    schedule_data = {
                        'id': schedule.id,
                        'medicine_id': medicine.id,
                        'medicine_name': medicine.name,
                        'time': schedule.time,
                        'dosage': schedule.dosage,
                        'is_active': schedule.is_active
                    }
                    course_data['schedules'].append(schedule_data)

                # Add unique medicines
                for medicine in medicines_set:
                    medicine_data = {
                        'id': medicine.id,
                        'name': medicine.name,
                        'description': medicine.description,
                        'is_active': medicine.is_active
                    }
                    course_data['medicines'].append(medicine_data)

                final_response.append(course_data)

            return success_response(final_response)

        except Exception as e:
            return error_response(str(e), status.HTTP_500_INTERNAL_SERVER_ERROR)

    
    def create(self, request):
        """
        Create a new course
        """
        try:
            serializer = CourseSerializer(data=request.data)
            if serializer.is_valid():
                course = serializer.save(user=request.user)
                return success_response(
                    CourseSerializer(course).data,
                    "Course created successfully",
                    status.HTTP_201_CREATED
                )
            else:
                return error_response(serializer.errors, status.HTTP_400_BAD_REQUEST)
        except Exception as e:
            return error_response(str(e), status.HTTP_500_INTERNAL_SERVER_ERROR)
    
    def retrieve(self, request, pk=None):
        """
        Retrieve a specific course
        """
        try:
            course = self.get_queryset().get(pk=pk)
            serializer = CourseSerializer(course)
            return success_response(serializer.data)
        except Course.DoesNotExist:
            return error_response("Course not found", status.HTTP_404_NOT_FOUND)
        except Exception as e:
            return error_response(str(e), status.HTTP_500_INTERNAL_SERVER_ERROR)
    
    def update(self, request, pk=None):
        """
        Update a course
        """
        try:
            course = self.get_queryset().get(pk=pk)
            serializer = CourseSerializer(course, data=request.data, partial=True)
            if serializer.is_valid():
                updated_course = serializer.save()
                return success_response(
                    CourseSerializer(updated_course).data,
                    "Course updated successfully"
                )
            else:
                return error_response(serializer.errors, status.HTTP_400_BAD_REQUEST)
        except Course.DoesNotExist:
            return error_response("Course not found", status.HTTP_404_NOT_FOUND)
        except Exception as e:
            return error_response(str(e), status.HTTP_500_INTERNAL_SERVER_ERROR)
    
    def destroy(self, request, pk=None):
        """
        Soft delete a course (set is_active to False)
        """
        try:
            course = self.get_queryset().get(pk=pk)
            course.is_active = False
            course.save()
            return success_response(message="Course deleted successfully")
        except Course.DoesNotExist:
            return error_response("Course not found", status.HTTP_404_NOT_FOUND)
        except Exception as e:
            return error_response(str(e), status.HTTP_500_INTERNAL_SERVER_ERROR)
    
    @action(detail=False, methods=['post'], permission_classes=[IsAuthenticated], parser_classes=[MultiPartParser, FormParser])
    def with_medicines_and_schedules(self, request):
        """
        Create a course with medicines and schedules in a single request, or extract data from a PDF using GPT if a PDF is uploaded.
        """
        # Check if a PDF file is uploaded
        pdf_file = request.FILES.get('pdf')
        if pdf_file:
            # Save file to media directory
            file_name = default_storage.save(f'pdf_uploads/{pdf_file.name}', ContentFile(pdf_file.read()))
            file_path = default_storage.path(file_name)

            # Now pass the saved file path to your markdown function
            markdown = pdf_to_markdown(file_path)

            # Prepare messages for GPT
            messages = [
                {"role": "system", "content": pdf_to_markdown_prompt},
                {"role": "user", "content": markdown}
            ]

            gpt = GPTModel()
            gpt_response = gpt.chat(messages)

            if gpt_response is None:
                return error_response("GPT processing failed. Please try again or check your API configuration.", status.HTTP_500_INTERNAL_SERVER_ERROR)

            try:
                gpt_json = json.loads(gpt_response)
            except Exception as e:
                return error_response(f"GPT did not return valid JSON: {e}", status.HTTP_400_BAD_REQUEST)

            data = gpt_json
        else:
            data = request.data

        serializer = CourseWithMedicinesAndSchedulesSerializer(
            data=data,
            context={'user': request.user}
        )
        if serializer.is_valid():
            course = serializer.save()
            
            # Get the created course with its relationships
            schedules = CourseMedicineSchedule.objects.filter(
                course=course, 
                is_active=True
            ).select_related('medicine')
            
            # Prepare response data
            response_data = {
                'course': {
                    'id': course.id,
                    'name': course.name,
                    'start_date': course.start_date,
                    'duration': course.duration,
                    'patient_history': course.patient_history,
                    'current_situation': course.current_situation,
                    'doctor_instructions': course.doctor_instructions,
                    'created_at': course.created_at,
                    'is_active': course.is_active
                },
                'medicines': [],
                'schedules': []
            }
            
            # Collect unique medicines and schedules
            medicines_set = set()
            for schedule in schedules:
                medicine = schedule.medicine
                medicines_set.add(medicine)
                
                schedule_data = {
                    'id': schedule.id,
                    'medicine_id': medicine.id,
                    'medicine_name': medicine.name,
                    'time': schedule.time,
                    'dosage': schedule.dosage,
                    'is_active': schedule.is_active
                }
                response_data['schedules'].append(schedule_data)
            
            # Add unique medicines
            for medicine in medicines_set:
                medicine_data = {
                    'id': medicine.id,
                    'name': medicine.name,
                    'description': medicine.description,
                    'is_active': medicine.is_active
                }
                response_data['medicines'].append(medicine_data)
            
            return success_response(
                response_data,
                "Course with medicines and schedules created successfully",
                status.HTTP_201_CREATED
            )
        else:
            return error_response(str(serializer.errors), status.HTTP_400_BAD_REQUEST)

    @action(detail=True, methods=['get'], permission_classes=[IsAuthenticated])
    def get_with_medicines_and_schedules(self, request, pk=None):
        """
        Retrieve a specific course with its medicines and schedules
        """
        try:
            # Get the course
            course = self.get_queryset().get(pk=pk)
            
            # Get the course schedules with medicines
            
            schedules = CourseMedicineSchedule.objects.filter(
                course=course, 
                is_active=True
            ).select_related('medicine')
            
            # Get today's date for tracking
            today = timezone.now().date()
            
            # Prepare response data
            response_data = {
                'course': {
                    'id': course.id,
                    'name': course.name,
                    'start_date': course.start_date,
                    'duration': course.duration,
                    'patient_history': course.patient_history,
                    'current_situation': course.current_situation,
                    'doctor_instructions': course.doctor_instructions,
                    'created_at': course.created_at,
                    'is_active': course.is_active
                },
                'medicines': [],
                'schedules': []
            }
            
            # Collect unique medicines and schedules
            medicines_set = set()
            for schedule in schedules:
                medicine = schedule.medicine
                medicines_set.add(medicine)
                
                # Check if this schedule has been taken today
                tracking_record = CourseDayTracking.objects.filter(
                    course=course,
                    medicine=medicine,
                    date=today,
                    time=schedule.time
                ).first()
                
                taken_today = tracking_record.taken if tracking_record else False
                
                schedule_data = {
                    'id': schedule.id,
                    'medicine_id': medicine.id,
                    'medicine_name': medicine.name,
                    'time': schedule.time,
                    'dosage': schedule.dosage,
                    'is_active': schedule.is_active,
                    'taken': taken_today
                }
                response_data['schedules'].append(schedule_data)
            
            # Add unique medicines
            for medicine in medicines_set:
                medicine_data = {
                    'id': medicine.id,
                    'name': medicine.name,
                    'description': medicine.description,
                    'is_active': medicine.is_active
                }
                response_data['medicines'].append(medicine_data)
            
            return success_response(response_data)
            
        except Course.DoesNotExist:
            return error_response("Course not found", status.HTTP_404_NOT_FOUND)
        except Exception as e:
            return error_response(str(e), status.HTTP_500_INTERNAL_SERVER_ERROR)

    def _get_time_slot(self, target_time):
        """
        Determine the 3-hour time slot for a given time.
        Returns tuple of (start_time, end_time) for the slot.
        """
        from datetime import time
        
        hour = target_time.hour
        
        # Define time slots: each slot is 3 hours
        time_slots = [
            (0, 3), (3, 6), (6, 9), (9, 12),
            (12, 15), (15, 18), (18, 21), (21, 0)  # Changed 24 to 0
        ]
        
        # Find which slot the hour falls into
        for start_hour, end_hour in time_slots:
            if start_hour <= hour < end_hour or (start_hour == 21 and hour >= 21):
                # Special case for 21-24 hour slot
                if end_hour == 0:
                    return time(start_hour, 0, 0), time(0, 0, 0)
                else:
                    return time(start_hour, 0, 0), time(end_hour, 0, 0)
        
        # Fallback (shouldn't happen with valid 24-hour format)
        return time(0, 0, 0), time(3, 0, 0)

    @action(detail=False, methods=['get'], permission_classes=[IsAuthenticated])
    def get_current_course(self, request):
        """
        Retrieve the current (most recent) course for the authenticated user with medicines and schedules
        Filter by time parameter if provided (3-hour slot)
        """
        try:
            # Get the most recent active course for the user
            course = self.get_queryset().order_by('-created_at').first()
            
            if not course:
                return error_response("No active course found for the user", status.HTTP_404_NOT_FOUND)
            
            # Get the course schedules with medicines
            schedules = CourseMedicineSchedule.objects.filter(
                course=course, 
                is_active=True
            ).select_related('medicine')
            
            # Get time parameter from query params
            time_param = request.query_params.get('time')
            logger.debug("Time parameter: %s", time_param)
            
            if time_param:
                try:
                    # Parse the time parameter (expected format: HH:MM:SS or HH:MM)
                    from datetime import datetime
                    
                    # Handle different time formats
                    if len(time_param.split(':')) == 2:
                        time_param += ':00'  # Add seconds if not provided
                    
                    target_time = datetime.strptime(time_param, '%H:%M:%S').time()
                    
                    # Get the 3-hour time slot for this time
                    start_time, end_time = self._get_time_slot(target_time)
                    
                    logger.debug("Time slot for %s: %s to %s", time_param, start_time, end_time)
                    
                    # Filter schedules based on the time slot
                    filtered_schedules = schedules.filter(
                        time__gte=start_time,
                        time__lt=end_time
                    )
                    
                    schedules = filtered_schedules
                    
                except ValueError:
                    return error_response("Invalid time format. Use HH:MM:SS or HH:MM", status.HTTP_400_BAD_REQUEST)
            
            # Get today's date for tracking
            today = timezone.now().date()
            
            # Get medical reports for the user (including unparsed)
            from medical_reports.models import MedicalDocument, MedicalReport
            medical_documents = MedicalDocument.objects.filter(
                user=request.user
            ).values('id', 'title', 'document_type', 'description', 'uploaded_at', 'parsed_data', 'is_parsed')

            # Get user profile data
            from users.serializers import UserProfileSerializer
            user_profile_data = UserProfileSerializer(request.user).data

            # Get all medications (not just from courses)
            from medicines.models import Medicine, DoseEvent
            user_medications = Medicine.objects.filter(
                user=request.user,
                is_active=True
            ).values('id', 'name', 'strength', 'form', 'route', 'instructions',
                    'take_with_food', 'created_at', 'updated_at')

            # Get recent dose events
            dose_events = DoseEvent.objects.filter(
                medication__user=request.user
            ).order_by('-scheduled_at')[:20].values(
                'id', 'medication__name', 'scheduled_at', 'taken_at',
                'status', 'method', 'notes'
            )

            # Get medical report summary if exists
            medical_report_summary = None
            try:
                med_report = MedicalReport.objects.get(user=request.user)
                medical_report_summary = med_report.get_report_data()
            except MedicalReport.DoesNotExist:
                pass

            # Prepare response data
            response_data = {
                'user_profile': user_profile_data,
                'course': {
                    'id': course.id,
                    'name': course.name,
                    'start_date': course.start_date,
                    'duration': course.duration,
                    'patient_history': course.patient_history,
                    'current_situation': course.current_situation,
                    'doctor_instructions': course.doctor_instructions,
                    'created_at': course.created_at,
                    'is_active': course.is_active
                },
                'medicines': [],
                'schedules': [],
                'next_schedules': [],
                'medical_reports': list(medical_documents),
                'all_medications': list(user_medications),
                'recent_dose_events': list(dose_events),
                'medical_report_summary': medical_report_summary
            }
            
            # Collect unique medicines and schedules
            medicines_set = set()
            for schedule in schedules:
                medicine = schedule.medicine
                medicines_set.add(medicine)
                
                # Check if this schedule has been taken today
                tracking_record = CourseDayTracking.objects.filter(
                    course=course,
                    medicine=medicine,
                    taken=True,
                    # time=schedule.time
                ).first()
                
                taken_today = tracking_record.taken if tracking_record else False
                
                schedule_data = {
                    'id': schedule.id,
                    'medicine_id': medicine.id,
                    'medicine_name': medicine.name,
                    'time': schedule.time,
                    'dosage': schedule.dosage,
                    'is_active': schedule.is_active,
                    'taken': taken_today
                }
                response_data['schedules'].append(schedule_data)
            
            # Add unique medicines
            for medicine in medicines_set:
                medicine_data = {
                    'id': medicine.id,
                    'name': medicine.name,
                    'description': medicine.description,
                    'is_active': medicine.is_active
                }
                response_data['medicines'].append(medicine_data)
            
            if time_param:
                try:
                    # Get all schedules for the course (not just filtered ones)
                    all_schedules = CourseMedicineSchedule.objects.filter(
                        course=course, 
                        is_active=True
                    ).select_related('medicine').order_by('time')
                    
                    # Find the first schedule after the current time slot
                    next_schedules = []
                    for schedule in all_schedules:
                        if schedule.time >= end_time:
                            # Check if this schedule has been taken today
                            tracking_record = CourseDayTracking.objects.filter(
                                course=course,
                                medicine=schedule.medicine,
                                taken=True,
                            ).first()
                            
                            taken_today = tracking_record.taken if tracking_record else False
                            
                            next_schedule_data = {
                                'id': schedule.id,
                                'medicine_id': schedule.medicine.id,
                                'medicine_name': schedule.medicine.name,
                                'time': schedule.time,
                                'dosage': schedule.dosage,
                                'is_active': schedule.is_active,
                                'taken': taken_today
                            }
                            next_schedules.append(next_schedule_data)
                            break  # Only get the first next schedule
                    
                    response_data['next_schedules'] = next_schedules
                    
                except Exception as e:
                    logger.error("Error getting next schedules: %s", e)
                    response_data['next_schedules'] = []
            
            return success_response(response_data)
            
        except Exception as e:
            return error_response(str(e), status.HTTP_500_INTERNAL_SERVER_ERROR)
