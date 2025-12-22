from rest_framework import serializers
from .models import Course
from medicines.models import Medicine
from schedules.models import CourseMedicineSchedule


class MedicineCreateSerializer(serializers.ModelSerializer):
    """
    Serializer for creating Medicine model (for nested creation)
    """
    class Meta:
        model = Medicine
        fields = ['name', 'description']


class ScheduleCreateSerializer(serializers.Serializer):
    """
    Serializer for creating schedule data (for nested creation)
    """
    medicine_name = serializers.CharField(max_length=255)
    medicine_description = serializers.CharField(required=False, allow_blank=True)
    time = serializers.TimeField()
    dosage = serializers.CharField(max_length=100)


class CourseWithMedicinesAndSchedulesSerializer(serializers.ModelSerializer):
    """
    Comprehensive course serializer for creating course with medicines and schedules
    """
    medicines_and_schedules = ScheduleCreateSerializer(many=True, required=False)
    
    class Meta:
        model = Course
        fields = [
            'name', 'start_date', 'duration', 'patient_history', 'current_situation',
            'doctor_instructions', 'medicines_and_schedules'
        ]

    # --- Field-level validation methods ---

    def validate_name(self, value):
        if not value.strip():
            raise serializers.ValidationError("Name cannot be blank.")
        return value

    def validate_start_date(self, value):
        from django.utils import timezone
        today = timezone.now().date()
        if value < today:
            return today 
        return value

    def validate_duration(self, value):
        if value <= 0:
            raise serializers.ValidationError("Duration must be greater than 0.")
        if value > 365:
            raise serializers.ValidationError("Duration cannot exceed 365 days.")
        return value

    def validate_patient_history(self, value):
        if not value.strip():
            raise serializers.ValidationError("Patient history is required.")
        if len(value) < 10:
            raise serializers.ValidationError("Patient history must be more descriptive.")
        return value

    def validate_current_situation(self, value):
        if not value.strip():
            raise serializers.ValidationError("Current situation is required.")
        if len(value) < 10:
            raise serializers.ValidationError("Current situation must be more descriptive.")
        return value

    def validate_doctor_instructions(self, value):
        if not value.strip():
            raise serializers.ValidationError("Doctor instructions are required.")
        if len(value) < 10:
            raise serializers.ValidationError("Doctor instructions must be more descriptive.")
        return value

    def create(self, validated_data):
        medicines_and_schedules_data = validated_data.pop('medicines_and_schedules', [])

        # Get user from context
        user = self.context.get('user')
        if not user:
            raise serializers.ValidationError("User is required to create course")

        # Create the course with user
        validated_data['user'] = user
        course = Course.objects.create(**validated_data)

        # Create medicines and schedules
        for item in medicines_and_schedules_data:
            medicine, created = Medicine.objects.get_or_create(
                user=user,
                name=item['medicine_name'],
                defaults={
                    'description': item.get('medicine_description', ''),
                    'is_active': True
                }
            )

            CourseMedicineSchedule.objects.create(
                course=course,
                medicine=medicine,
                time=item['time'],
                dosage=item['dosage'],
                is_active=True
            )

        return course


class CourseSerializer(serializers.ModelSerializer):
    """
    Serializer for Course model
    """
    class Meta:
        model = Course
        fields = [
            'id', 'name', 'start_date', 'duration', 'patient_history', 'current_situation',
            'doctor_instructions', 'created_at', 'updated_at', 'is_active'
        ]
        read_only_fields = ['id', 'created_at', 'updated_at']
    
    def validate_start_date(self, value):
        from django.utils import timezone
        if value < timezone.now().date():
            raise serializers.ValidationError("Start date cannot be in the past")
        return value
    
    def validate_duration(self, value):
        if value <= 0:
            raise serializers.ValidationError("Duration must be greater than 0")
        return value 