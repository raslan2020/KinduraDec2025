from rest_framework import serializers
from .models import (
    HealthProfile, LifestyleHabits, PhysicalActivity,
    DietaryHabits, MedicalHistory, MentalHealth, WatchVitals,
    PatientClinicalProfile, MotorSymptomEntry, NonMotorSymptomEntry,
    MedicationDoseEntry, SafetyEvent, SpeechMetrics, CognitiveScreening,
    ClinicalReport, AgentDataCollection
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
    Serializer for Apple Watch vitals data including extended vitals
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
            # Activity fields
            'steps', 'calories', 'distance_km', 'floors_climbed',
            'exercise_minutes', 'stand_minutes',
            # === EXTENDED VITALS ===
            # Walking Steadiness (3-month retention)
            'walking_steadiness_percent', 'walking_steadiness_classification',
            # Blood Pressure (2-month retention)
            'blood_pressure_systolic', 'blood_pressure_diastolic',
            # Blood Glucose (2-month retention)
            'blood_glucose',
            # AFib Detection (2-month retention)
            'afib_detected', 'afib_burden_percent',
            # Temperature (2-month retention)
            'body_temperature', 'wrist_temperature_delta',
            # Six-Minute Walk (2-month retention)
            'six_minute_walk_distance',
            # VO2 Max (2-month retention)
            'vo2_max',
            # Mobility Metrics (2-month retention)
            'walking_asymmetry_percent', 'walking_speed',
            'double_support_time_percent', 'stair_ascent_speed', 'stair_descent_speed',
            # Peripheral Perfusion (2-month retention)
            'peripheral_perfusion_index',
            # Timestamps
            'recorded_at', 'created_at', 'heart_rate_status', 'sleep_quality_computed'
        ]
        read_only_fields = ['id', 'created_at', 'heart_rate_status', 'sleep_quality_computed']
        extra_kwargs = {
            # Make all extended vitals optional
            'walking_steadiness_percent': {'required': False},
            'walking_steadiness_classification': {'required': False},
            'blood_pressure_systolic': {'required': False},
            'blood_pressure_diastolic': {'required': False},
            'blood_glucose': {'required': False},
            'afib_detected': {'required': False},
            'afib_burden_percent': {'required': False},
            'body_temperature': {'required': False},
            'wrist_temperature_delta': {'required': False},
            'six_minute_walk_distance': {'required': False},
            'vo2_max': {'required': False},
            'walking_asymmetry_percent': {'required': False},
            'walking_speed': {'required': False},
            'double_support_time_percent': {'required': False},
            'stair_ascent_speed': {'required': False},
            'stair_descent_speed': {'required': False},
            'peripheral_perfusion_index': {'required': False},
        }


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


# ============================================================
# CLINICAL DATA SERIALIZERS - Following Reports.md Specification
# ============================================================

class PatientClinicalProfileSerializer(serializers.ModelSerializer):
    """
    Serializer for patient clinical profile (context data)
    Following Reports.md Section 3.1
    """
    class Meta:
        model = PatientClinicalProfile
        fields = [
            'id', 'handedness', 'symptom_onset_date',
            'family_history_parkinsons', 'family_history_details',
            'comorbidities', 'living_situation', 'caregiver_availability',
            'caregiver_name', 'caregiver_contact',
            'is_diagnosed_pd', 'diagnosis_date', 'diagnosing_physician',
            'created_at', 'updated_at'
        ]
        read_only_fields = ['id', 'created_at', 'updated_at']


class MotorSymptomEntrySerializer(serializers.ModelSerializer):
    """
    Serializer for daily motor symptom entries
    Following Reports.md Section 3.2
    """
    class Meta:
        model = MotorSymptomEntry
        fields = [
            'id', 'recorded_date', 'bradykinesia', 'tremor', 'tremor_type',
            'rigidity', 'gait_difficulty', 'laterality',
            'freezing_episodes', 'falls_today', 'data_source', 'notes',
            'hours_since_last_medication', 'created_at'
        ]
        read_only_fields = ['id', 'created_at']

    def validate_bradykinesia(self, value):
        """Ensure bradykinesia is always provided (mandatory core feature)"""
        if value is None:
            raise serializers.ValidationError(
                "Bradykinesia is a mandatory core feature and must be provided."
            )
        return value


class NonMotorSymptomEntrySerializer(serializers.ModelSerializer):
    """
    Serializer for non-motor symptom entries
    Following Reports.md Section 3.3
    """
    class Meta:
        model = NonMotorSymptomEntry
        fields = [
            'id', 'recorded_date', 'sleep_disturbance', 'rem_behavior_disorder',
            'constipation', 'dizziness', 'mood_apathy', 'fatigue', 'smell_loss',
            'urinary_issues', 'drooling', 'data_source', 'notes', 'created_at'
        ]
        read_only_fields = ['id', 'created_at']


class MedicationDoseEntrySerializer(serializers.ModelSerializer):
    """
    Serializer for per-dose medication tracking
    Following Reports.md Section 3.4
    """
    class Meta:
        model = MedicationDoseEntry
        fields = [
            'id', 'medication_name', 'medication_id', 'dose',
            'scheduled_time', 'taken_time', 'delay_minutes', 'status',
            'side_effects', 'side_effects_notes', 'data_source', 'created_at'
        ]
        read_only_fields = ['id', 'created_at']

    def validate(self, data):
        """Calculate delay_minutes if not provided"""
        if data.get('taken_time') and data.get('scheduled_time'):
            delta = data['taken_time'] - data['scheduled_time']
            data['delay_minutes'] = int(delta.total_seconds() / 60)
        return data


class SafetyEventSerializer(serializers.ModelSerializer):
    """
    Serializer for safety and red-flag events
    Following Reports.md Section 3.8
    """
    class Meta:
        model = SafetyEvent
        fields = [
            'id', 'event_type', 'severity', 'occurred_at', 'description',
            'injury_sustained', 'injury_description',
            'hallucination_type', 'hallucination_content',
            'is_resolved', 'resolution_notes', 'resolved_at',
            'escalated_to_provider', 'escalated_at',
            'data_source', 'created_at'
        ]
        read_only_fields = ['id', 'created_at']


class SpeechMetricsSerializer(serializers.ModelSerializer):
    """
    Serializer for speech and voice metrics
    Following Reports.md Section 3.6
    """
    class Meta:
        model = SpeechMetrics
        fields = [
            'id', 'recorded_date', 'voice_volume', 'speech_variability',
            'articulation_clarity', 'speech_rate_wpm', 'pause_duration_avg',
            'data_source', 'notes', 'audio_file', 'created_at'
        ]
        read_only_fields = ['id', 'created_at']


class CognitiveScreeningSerializer(serializers.ModelSerializer):
    """
    Serializer for cognitive and mood screening
    Following Reports.md Section 3.7
    Safety: PHQ-9 Q9 >= 2 triggers escalation
    """
    class Meta:
        model = CognitiveScreening
        fields = [
            'id', 'recorded_date', 'moca_lite_score', 'moca_lite_responses',
            'phq9_total_score', 'phq9_responses', 'phq9_q9_score',
            'requires_immediate_escalation', 'escalation_handled',
            'escalation_notes', 'data_source', 'notes', 'created_at'
        ]
        read_only_fields = ['id', 'created_at', 'requires_immediate_escalation']


class ClinicalReportSerializer(serializers.ModelSerializer):
    """
    Serializer for clinical reports (daily, weekly, monthly)
    Following Reports.md Sections 2.1-2.4
    """
    class Meta:
        model = ClinicalReport
        fields = [
            'id', 'report_type', 'status', 'period_start', 'period_end',
            'data_completeness_percent', 'meets_minimum_criteria',
            'report_content', 'motor_summary', 'non_motor_summary',
            'medication_summary', 'safety_summary', 'quality_of_life_summary',
            'ai_insights', 'red_flags', 'recommendations',
            'validation_checklist', 'bradykinesia_assessed', 'laterality_captured',
            'medication_timing_correlated', 'red_flags_escalated', 'data_sources_tagged',
            'disclaimer', 'generated_at', 'ai_model_used', 'generation_time_seconds',
            'viewed_by_patient', 'viewed_by_patient_at',
            'viewed_by_provider', 'viewed_by_provider_at'
        ]
        read_only_fields = ['id', 'generated_at']


class ClinicalReportSummarySerializer(serializers.ModelSerializer):
    """
    Lightweight serializer for report listing
    """
    class Meta:
        model = ClinicalReport
        fields = [
            'id', 'report_type', 'status', 'period_start', 'period_end',
            'data_completeness_percent', 'meets_minimum_criteria',
            'generated_at', 'viewed_by_patient'
        ]


class AgentDataCollectionSerializer(serializers.ModelSerializer):
    """
    Serializer for agent data collection tracking
    """
    class Meta:
        model = AgentDataCollection
        fields = [
            'id', 'domain', 'field_name', 'last_collected_at',
            'collection_frequency', 'is_overdue', 'days_overdue',
            'priority', 'collection_prompt', 'created_at', 'updated_at'
        ]
        read_only_fields = ['id', 'created_at', 'updated_at']


class DataGapsSerializer(serializers.Serializer):
    """
    Serializer for returning data gaps to the agent
    Used by agent to know what questions to ask
    """
    domain = serializers.CharField()
    field_name = serializers.CharField()
    priority = serializers.IntegerField()
    days_overdue = serializers.IntegerField()
    prompt = serializers.CharField(help_text="Plain-language prompt (<=12 words)")


class AgentSymptomCollectionSerializer(serializers.Serializer):
    """
    Simplified serializer for agent to submit collected symptom data
    Following Reports.md conversational rules: one symptom at a time
    """
    symptom_type = serializers.ChoiceField(choices=[
        ('bradykinesia', 'Bradykinesia'),
        ('tremor', 'Tremor'),
        ('rigidity', 'Rigidity'),
        ('gait', 'Gait Difficulty'),
        ('laterality', 'Laterality'),
        ('sleep', 'Sleep Disturbance'),
        ('constipation', 'Constipation'),
        ('mood', 'Mood/Apathy'),
        ('fatigue', 'Fatigue'),
        ('dizziness', 'Dizziness'),
        ('smell', 'Smell Loss'),
    ])
    value = serializers.IntegerField(
        min_value=1, max_value=5,
        help_text="1=minimal/none, 5=severe"
    )
    laterality_value = serializers.ChoiceField(
        choices=[('L', 'Left'), ('R', 'Right'), ('B', 'Both')],
        required=False
    )
    data_source = serializers.ChoiceField(
        choices=['patient', 'caregiver', 'device', 'inferred'],
        default='patient'
    )
    notes = serializers.CharField(required=False, allow_blank=True)