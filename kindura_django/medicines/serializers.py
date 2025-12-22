from rest_framework import serializers
from .models import (
    Medicine, MedicationEvent, MedicationAdherenceDaily,
    MedicationInteraction, MedicationReminder
)
from datetime import datetime


class MedicationReminderSerializer(serializers.ModelSerializer):
    """
    Serializer for MedicationReminder model
    """
    class Meta:
        model = MedicationReminder
        fields = [
            'reminder_enabled', 'reminder_minutes_before',
            'caregiver_escalation_enabled', 'escalation_delay_minutes',
            'snooze_enabled', 'max_snooze_count', 'snooze_duration_minutes',
            'sound_enabled', 'vibration_enabled'
        ]


class MedicineSerializer(serializers.ModelSerializer):
    """
    Serializer for Medicine model
    """
    display_name = serializers.ReadOnlyField()
    strength_display = serializers.ReadOnlyField()
    reminder_settings = MedicationReminderSerializer(read_only=True)
    # Ensure profile_id is serialized as string
    profile_id = serializers.CharField(required=False, allow_blank=True, allow_null=True)

    class Meta:
        model = Medicine
        fields = [
            'id', 'profile_id', 'drug_name', 'brand_name', 'form',
            'strength', 'strength_unit', 'route', 'instructions_text',
            'take_with_food', 'as_needed', 'missed_dose_action', 'schedule',
            'start_date', 'end_date', 'timezone', 'prescriber', 'prescription_number',
            'is_active', 'source', 'source_document_id', 'display_name', 'strength_display',
            'reminder_settings', 'created_at', 'updated_at'
        ]
        read_only_fields = ['id', 'created_at', 'updated_at', 'display_name', 'strength_display']

    def to_representation(self, instance):
        """Convert snake_case to camelCase for Flutter compatibility"""
        representation = super().to_representation(instance)

        # Convert to camelCase for Flutter
        camel_case_data = {
            'id': str(representation.get('id', '')),
            'profileId': str(representation.get('profile_id', '')) if representation.get('profile_id') else None,
            'drugName': representation.get('drug_name', ''),
            'brandName': representation.get('brand_name'),
            'form': representation.get('form', 'tablet'),
            'strength': float(representation.get('strength', 0)),
            'strengthUnit': representation.get('strength_unit', 'mg'),
            'route': representation.get('route', 'oral'),
            'instructionsText': representation.get('instructions_text', ''),
            'takeWithFood': representation.get('take_with_food', False),
            'asNeeded': representation.get('as_needed', False),
            'missedDoseAction': representation.get('missed_dose_action', 'no_policy'),
            'schedule': representation.get('schedule', {'times': [], 'days': [], 'frequency': 'daily', 'reminderEnabled': True, 'reminderMinutesBefore': 0, 'caregiverEscalationEnabled': False}),
            'startDate': representation.get('start_date'),
            'endDate': representation.get('end_date'),
            'prescribedBy': representation.get('prescriber'),
            'pharmacy': None,
            'rxNumber': representation.get('prescription_number'),
            'refillsRemaining': None,
            'notes': None,
            'isActive': representation.get('is_active', True),
            'createdAt': representation.get('created_at'),
            'updatedAt': representation.get('updated_at'),
            'createdBy': None,
        }
        return camel_case_data

    def validate_drug_name(self, value):
        if not value.strip():
            raise serializers.ValidationError("Drug name cannot be empty")
        return value.strip()

    def validate_schedule(self, value):
        """Validate schedule format and store all fields from Flutter"""
        if not isinstance(value, dict):
            raise serializers.ValidationError("Schedule must be a dictionary")

        # Store all schedule fields from Flutter
        cleaned_schedule = {}

        # Validate and store times
        if 'times' in value:
            if not isinstance(value['times'], list):
                raise serializers.ValidationError("Schedule times must be a list")
            for time in value['times']:
                try:
                    # Validate time format HH:MM
                    datetime.strptime(time, '%H:%M')
                except ValueError:
                    raise serializers.ValidationError(f"Invalid time format: {time}. Use HH:MM format")
            cleaned_schedule['times'] = value['times']

        # Validate and store days
        valid_days = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun']
        if 'days' in value:
            days = value['days']
            if days is not None:
                if not isinstance(days, list):
                    raise serializers.ValidationError("Schedule days must be a list")

                # Handle "Daily" or "daily" - convert to all days
                if len(days) == 1 and days[0].lower() == 'daily':
                    cleaned_schedule['days'] = valid_days
                else:
                    # Validate each day
                    for day in days:
                        if day not in valid_days:
                            raise serializers.ValidationError(f"Invalid day: {day}. Use: {', '.join(valid_days)} or 'Daily'")
                    cleaned_schedule['days'] = days
            else:
                # null days means daily schedule
                cleaned_schedule['days'] = valid_days
        else:
            # No days specified means daily schedule
            cleaned_schedule['days'] = valid_days

        # Store additional schedule fields from Flutter
        if 'frequency' in value:
            cleaned_schedule['frequency'] = value['frequency']
        if 'intervalHours' in value:
            cleaned_schedule['intervalHours'] = value['intervalHours']
        if 'dosesPerDay' in value:
            cleaned_schedule['dosesPerDay'] = value['dosesPerDay']
        if 'timezone' in value:
            cleaned_schedule['timezone'] = value['timezone']

        # Store reminder settings in schedule for later processing
        if 'reminderEnabled' in value:
            cleaned_schedule['reminderEnabled'] = value['reminderEnabled']
        if 'reminderMinutesBefore' in value:
            cleaned_schedule['reminderMinutesBefore'] = value['reminderMinutesBefore']
        if 'caregiverEscalationEnabled' in value:
            cleaned_schedule['caregiverEscalationEnabled'] = value['caregiverEscalationEnabled']
        if 'caregiverContactId' in value:
            cleaned_schedule['caregiverContactId'] = value['caregiverContactId']

        return cleaned_schedule

    def create(self, validated_data):
        """Create medicine with reminder settings"""
        medicine = super().create(validated_data)

        # Extract reminder settings from schedule
        schedule = validated_data.get('schedule', {})
        reminder_enabled = schedule.get('reminderEnabled', True)
        reminder_minutes_before = schedule.get('reminderMinutesBefore', 0)
        caregiver_escalation_enabled = schedule.get('caregiverEscalationEnabled', False)

        # Create reminder settings with values from Flutter
        MedicationReminder.objects.create(
            medication=medicine,
            reminder_enabled=reminder_enabled,
            reminder_minutes_before=reminder_minutes_before,
            caregiver_escalation_enabled=caregiver_escalation_enabled,
        )

        return medicine


class MedicationEventSerializer(serializers.ModelSerializer):
    """
    Serializer for MedicationEvent model
    """
    medication_name = serializers.CharField(source='medication.drug_name', read_only=True)

    class Meta:
        model = MedicationEvent
        fields = [
            'id', 'medication', 'medication_name', 'scheduled_at', 'taken_at',
            'status', 'delay_minutes', 'side_effect_note', 'source',
            'created_at', 'updated_at'
        ]
        read_only_fields = ['id', 'created_at', 'updated_at', 'medication_name']


class MedicationAdherenceDailySerializer(serializers.ModelSerializer):
    """
    Serializer for MedicationAdherenceDaily model
    """
    class Meta:
        model = MedicationAdherenceDaily
        fields = [
            'id', 'date', 'on_time_doses', 'late_doses', 'missed_doses',
            'total_doses', 'adherence_percentage', 'created_at', 'updated_at'
        ]
        read_only_fields = ['id', 'created_at', 'updated_at']


class MedicationInteractionSerializer(serializers.ModelSerializer):
    """
    Serializer for MedicationInteraction model
    """
    medication_1_name = serializers.CharField(source='medication_1.drug_name', read_only=True)
    medication_2_name = serializers.CharField(source='medication_2.drug_name', read_only=True)

    class Meta:
        model = MedicationInteraction
        fields = [
            'id', 'medication_1', 'medication_1_name', 'medication_2', 'medication_2_name',
            'severity', 'description', 'clinical_significance', 'management_strategy',
            'is_active', 'acknowledged_by_user', 'acknowledged_at',
            'created_at', 'updated_at'
        ]
        read_only_fields = ['id', 'created_at', 'updated_at']


class MedicineCreateUpdateSerializer(serializers.ModelSerializer):
    """
    Serializer for creating/updating medications
    Handles Flutter app format
    """
    class Meta:
        model = Medicine
        fields = [
            'drug_name', 'brand_name', 'form', 'strength', 'strength_unit',
            'route', 'instructions_text', 'take_with_food', 'as_needed',
            'missed_dose_action', 'schedule', 'start_date', 'end_date',
            'timezone', 'prescriber', 'is_active'
        ]

    def to_internal_value(self, data):
        """Convert Flutter format to Django format"""
        # Handle schedule format from Flutter
        if 'schedule' in data and isinstance(data['schedule'], dict):
            flutter_schedule = data['schedule']
            schedule = {
                'times': flutter_schedule.get('times', []),
                'days': flutter_schedule.get('days', ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'])
            }

            # Handle frequency field from Flutter
            if flutter_schedule.get('frequency') == 'asNeeded':
                data['as_needed'] = True

            data['schedule'] = schedule

        # Handle strength field - allow 0 or empty
        if 'strength' in data:
            if data['strength'] == '' or data['strength'] is None:
                data['strength'] = 0
            else:
                try:
                    data['strength'] = float(data['strength'])
                except (ValueError, TypeError):
                    data['strength'] = 0

        return super().to_internal_value(data)