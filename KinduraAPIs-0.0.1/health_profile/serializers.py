from rest_framework import serializers
from .models import (
    HealthProfile, LifestyleHabits, PhysicalActivity,
    DietaryHabits, MedicalHistory, MentalHealth, WatchVitals
)


class LifestyleHabitsSerializer(serializers.ModelSerializer):
    """
    Serializer for lifestyle habits
    """
    class Meta:
        model = LifestyleHabits
        fields = ['smoking', 'drink_alcohol', 'caffeine_intake']


class PhysicalActivitySerializer(serializers.ModelSerializer):
    """
    Serializer for physical activity
    """
    class Meta:
        model = PhysicalActivity
        fields = ['exercise_frequency', 'exercise_type', 'average_duration']


class DietaryHabitsSerializer(serializers.ModelSerializer):
    """
    Serializer for dietary habits
    """
    class Meta:
        model = DietaryHabits
        fields = ['diet_type', 'dietary_restrictions', 'daily_water_intake']


class MedicalHistorySerializer(serializers.ModelSerializer):
    """
    Serializer for medical history
    """
    class Meta:
        model = MedicalHistory
        fields = [
            'taking_medications', 'current_medications', 
            'has_allergies', 'allergies', 'chronic_conditions'
        ]


class MentalHealthSerializer(serializers.ModelSerializer):
    """
    Serializer for mental health
    """
    class Meta:
        model = MentalHealth
        fields = ['experienced_anxiety_depression', 'seeing_therapist']


class HealthProfileSerializer(serializers.ModelSerializer):
    """
    Comprehensive health profile serializer
    """
    lifestyle_habits = LifestyleHabitsSerializer(required=False)
    physical_activity = PhysicalActivitySerializer(required=False)
    dietary_habits = DietaryHabitsSerializer(required=False)
    
    
    class Meta:
        model = HealthProfile
        fields = [
            'id', 'created_at', 'updated_at',
            'lifestyle_habits', 'physical_activity', 
            'dietary_habits'
        ]
        read_only_fields = ['id', 'created_at', 'updated_at']
    
    def create(self, validated_data):
        lifestyle_data = validated_data.pop('lifestyle_habits', None)
        physical_data = validated_data.pop('physical_activity', None)
        dietary_data = validated_data.pop('dietary_habits', None)
        
        health_profile = HealthProfile.objects.create(**validated_data)
        
        if lifestyle_data:
            LifestyleHabits.objects.create(health_profile=health_profile, **lifestyle_data)
        if physical_data:
            PhysicalActivity.objects.create(health_profile=health_profile, **physical_data)
        if dietary_data:
            DietaryHabits.objects.create(health_profile=health_profile, **dietary_data)
        
        return health_profile
    
    def update(self, instance, validated_data):
        lifestyle_data = validated_data.pop('lifestyle_habits', None)
        physical_data = validated_data.pop('physical_activity', None)
        dietary_data = validated_data.pop('dietary_habits', None)
        
        # Update health profile
        for attr, value in validated_data.items():
            setattr(instance, attr, value)
        instance.save()
        
        # Update related models
        if lifestyle_data:
            LifestyleHabits.objects.update_or_create(
                health_profile=instance,
                defaults=lifestyle_data
            )
        if physical_data:
            PhysicalActivity.objects.update_or_create(
                health_profile=instance,
                defaults=physical_data
            )
        if dietary_data:
            DietaryHabits.objects.update_or_create(
                health_profile=instance,
                defaults=dietary_data
            )
        
        
        return instance


class WatchVitalsSerializer(serializers.ModelSerializer):
    """
    Serializer for Apple Watch vitals data
    """
    heart_rate_status = serializers.CharField(read_only=True)
    sleep_quality_computed = serializers.CharField(read_only=True)

    class Meta:
        model = WatchVitals
        fields = [
            'id', 'heart_rate', 'blood_oxygen', 'hrv', 'respiratory_rate',
            'total_sleep_hours', 'deep_sleep_hours', 'rem_sleep_hours',
            'core_sleep_hours', 'awake_time_hours', 'awakenings_count',
            'sleep_quality', 'fall_detected', 'fall_resolved',
            'recorded_at', 'created_at', 'heart_rate_status', 'sleep_quality_computed'
        ]
        read_only_fields = ['id', 'created_at', 'heart_rate_status', 'sleep_quality_computed']


class WatchVitalsSummarySerializer(serializers.Serializer):
    """
    Summary serializer for the Watch widget on iPhone
    """
    heart_rate = serializers.FloatField()
    blood_oxygen = serializers.FloatField()
    sleep_hours = serializers.FloatField()
    awakenings = serializers.IntegerField()
    sleep_quality = serializers.CharField()
    falls_count = serializers.IntegerField()
    last_updated = serializers.DateTimeField()