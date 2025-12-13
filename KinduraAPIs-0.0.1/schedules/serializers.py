from rest_framework import serializers
from .models import CourseMedicineSchedule, CourseDayTracking
from courses.models import Course
from medicines.models import Medicine


class CourseMedicineScheduleSerializer(serializers.ModelSerializer):
    """
    Serializer for CourseMedicineSchedule model
    """
    course_name = serializers.CharField(source='course.name', read_only=True)
    medicine_name = serializers.CharField(source='medicine.name', read_only=True)
    
    class Meta:
        model = CourseMedicineSchedule
        fields = [
            'id', 'course', 'medicine', 'course_name', 'medicine_name',
            'time', 'dosage', 'created_at', 'updated_at', 'is_active'
        ]
        read_only_fields = ['id', 'created_at', 'updated_at']
    
    def validate(self, attrs):
        course = attrs.get('course')
        medicine = attrs.get('medicine')
        time = attrs.get('time')
        
        # Check if course and medicine belong to the same user
        if course.user != medicine.user:
            raise serializers.ValidationError("Course and medicine must belong to the same user")
        
        # Check for duplicate schedule
        if CourseMedicineSchedule.objects.filter(
            course=course, 
            medicine=medicine, 
            time=time,
            is_active=True
        ).exists():
            raise serializers.ValidationError("This schedule already exists")
        
        return attrs


class CourseDayTrackingSerializer(serializers.ModelSerializer):
    """
    Serializer for CourseDayTracking model
    """
    course_name = serializers.CharField(source='course.name', read_only=True)
    medicine_name = serializers.CharField(source='medicine.name', read_only=True)
    
    class Meta:
        model = CourseDayTracking
        fields = [
            'id', 'course', 'medicine', 'course_name', 'medicine_name',
            'date', 'time', 'taken', 'summary', 'created_at', 'updated_at'
        ]
        read_only_fields = ['id', 'created_at', 'updated_at']
    
    def validate(self, attrs):
        course = attrs.get('course')
        medicine = attrs.get('medicine')
        
        # Check if course and medicine belong to the same user
        if course.user != medicine.user:
            raise serializers.ValidationError("Course and medicine must belong to the same user")
        
        # Check for duplicate tracking entry
        if CourseDayTracking.objects.filter(
            course=course,
            medicine=medicine,
            date=attrs.get('date'),
            time=attrs.get('time')
        ).exists():
            raise serializers.ValidationError("This tracking entry already exists")
        
        return attrs 