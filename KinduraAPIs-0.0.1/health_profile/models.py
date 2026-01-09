from django.db import models
from django.core.validators import MinValueValidator, MaxValueValidator
from users.models import User


class HealthProfile(models.Model):
    """
    Comprehensive health profile for users
    """
    user = models.OneToOneField(User, on_delete=models.CASCADE, related_name='health_profile')
    created_at = models.DateTimeField(auto_now_add=True)
    updated_at = models.DateTimeField(auto_now=True)
    
    def __str__(self):
        return f"Health Profile for {self.user.email}"


class LifestyleHabits(models.Model):
    """
    Lifestyle habits information
    """
    health_profile = models.OneToOneField(HealthProfile, on_delete=models.CASCADE, related_name='lifestyle_habits')
    smoking = models.BooleanField(default=False)
    drink_alcohol = models.BooleanField(default=False)
    caffeine_intake = models.PositiveIntegerField(help_text="Cups of tea/coffee/energy drinks per day", default=0)
    
    def __str__(self):
        return f"Lifestyle Habits for {self.health_profile.user.email}"


class PhysicalActivity(models.Model):
    """
    Physical activity information
    """
    health_profile = models.OneToOneField(HealthProfile, on_delete=models.CASCADE, related_name='physical_activity')
    EXERCISE_FREQUENCY_CHOICES = [
        ('never', 'Never'),
        ('1-2', '1-2 times per week'),
        ('3-4', '3-4 times per week'),
        ('5-6', '5-6 times per week'),
        ('daily', 'Daily'),
    ]
    exercise_frequency = models.CharField(max_length=10, choices=EXERCISE_FREQUENCY_CHOICES, default='never')
    exercise_type = models.CharField(max_length=100, blank=True, null=True, help_text="e.g., walking, running, gym, yoga")
    average_duration = models.PositiveIntegerField(help_text="Duration in minutes", blank=True, null=True)
    
    def __str__(self):
        return f"Physical Activity for {self.health_profile.user.email}"


class DietaryHabits(models.Model):
    """
    Dietary habits information
    """
    health_profile = models.OneToOneField(HealthProfile, on_delete=models.CASCADE, related_name='dietary_habits')
    DIET_TYPE_CHOICES = [
        ('vegetarian', 'Vegetarian'),
        ('non_vegetarian', 'Non-vegetarian'),
        ('vegan', 'Vegan'),
        ('other', 'Other'),
    ]
    diet_type = models.CharField(max_length=20, choices=DIET_TYPE_CHOICES, default='non_vegetarian')
    dietary_restrictions = models.TextField(blank=True, null=True, help_text="e.g., allergies, religious, medical")
    daily_water_intake = models.DecimalField(max_digits=4, decimal_places=1, help_text="Liters per day", default=2.0)
    
    def __str__(self):
        return f"Dietary Habits for {self.health_profile.user.email}"


class MedicalHistory(models.Model):
    """
    Medical history information
    """
    health_profile = models.OneToOneField(HealthProfile, on_delete=models.CASCADE, related_name='medical_history')
    taking_medications = models.BooleanField(default=False)
    current_medications = models.TextField(blank=True, null=True, help_text="List of current medications")
    has_allergies = models.BooleanField(default=False)
    allergies = models.TextField(blank=True, null=True, help_text="Specify allergies")
    chronic_conditions = models.TextField(blank=True, null=True, help_text="e.g., diabetes, hypertension")
    
    def __str__(self):
        return f"Medical History for {self.health_profile.user.email}"


class MentalHealth(models.Model):
    """
    Mental health information
    """
    health_profile = models.OneToOneField(HealthProfile, on_delete=models.CASCADE, related_name='mental_health')
    experienced_anxiety_depression = models.BooleanField(default=False)
    seeing_therapist = models.BooleanField(default=False)

    def __str__(self):
        return f"Mental Health for {self.health_profile.user.email}"


class WatchVitals(models.Model):
    """
    Apple Watch vitals data - real-time health monitoring
    """
    SLEEP_QUALITY_CHOICES = [
        ('excellent', 'Excellent'),
        ('good', 'Good'),
        ('fair', 'Fair'),
        ('poor', 'Poor'),
    ]

    user = models.ForeignKey(User, on_delete=models.CASCADE, related_name='watch_vitals')

    # Vitals - with physiological validation ranges
    heart_rate = models.FloatField(
        validators=[MinValueValidator(30), MaxValueValidator(250)],
        help_text="Heart rate in BPM (valid range: 30-250)"
    )
    blood_oxygen = models.FloatField(
        validators=[MinValueValidator(50), MaxValueValidator(100)],
        help_text="Blood oxygen percentage SpO2 (valid range: 50-100)"
    )
    hrv = models.FloatField(
        blank=True, null=True,
        validators=[MinValueValidator(1), MaxValueValidator(300)],
        help_text="Heart rate variability in ms (valid range: 1-300)"
    )
    respiratory_rate = models.FloatField(
        blank=True, null=True,
        validators=[MinValueValidator(5), MaxValueValidator(60)],
        help_text="Breaths per minute (valid range: 5-60)"
    )

    # Sleep data - with reasonable validation
    total_sleep_hours = models.FloatField(
        blank=True, null=True,
        validators=[MinValueValidator(0), MaxValueValidator(24)]
    )
    deep_sleep_hours = models.FloatField(
        blank=True, null=True,
        validators=[MinValueValidator(0), MaxValueValidator(12)]
    )
    rem_sleep_hours = models.FloatField(
        blank=True, null=True,
        validators=[MinValueValidator(0), MaxValueValidator(12)]
    )
    core_sleep_hours = models.FloatField(
        blank=True, null=True,
        validators=[MinValueValidator(0), MaxValueValidator(12)]
    )
    awake_time_hours = models.FloatField(
        blank=True, null=True,
        validators=[MinValueValidator(0), MaxValueValidator(24)]
    )
    awakenings_count = models.IntegerField(
        default=0,
        validators=[MinValueValidator(0), MaxValueValidator(100)],
        help_text="Number of times woke up during night"
    )
    sleep_quality = models.CharField(max_length=10, choices=SLEEP_QUALITY_CHOICES, blank=True, null=True)

    # Fall detection
    fall_detected = models.BooleanField(default=False)
    fall_resolved = models.BooleanField(default=True)

    # Activity data
    steps = models.IntegerField(default=0, help_text="Daily step count")
    calories = models.IntegerField(default=0, help_text="Active calories burned")
    distance_km = models.FloatField(default=0, help_text="Distance in kilometers")
    floors_climbed = models.IntegerField(default=0, help_text="Floors climbed")
    exercise_minutes = models.IntegerField(default=0, help_text="Exercise minutes")
    stand_minutes = models.IntegerField(default=0, help_text="Stand minutes")

    # === EXTENDED VITALS (2-3 month retention) ===

    # Walking Steadiness (3-month retention, iOS 15+)
    walking_steadiness_percent = models.FloatField(
        blank=True, null=True,
        validators=[MinValueValidator(0), MaxValueValidator(100)],
        help_text="Walking steadiness percentage (0-100%)"
    )
    WALKING_STEADINESS_CHOICES = [
        ('OK', 'OK'),
        ('Low', 'Low'),
        ('Very Low', 'Very Low'),
    ]
    walking_steadiness_classification = models.CharField(
        max_length=20, choices=WALKING_STEADINESS_CHOICES,
        blank=True, null=True,
        help_text="Classification: OK (>=75%), Low (50-75%), Very Low (<50%)"
    )

    # Blood Pressure (2-month retention)
    blood_pressure_systolic = models.FloatField(
        blank=True, null=True,
        validators=[MinValueValidator(50), MaxValueValidator(250)],
        help_text="Systolic blood pressure in mmHg"
    )
    blood_pressure_diastolic = models.FloatField(
        blank=True, null=True,
        validators=[MinValueValidator(30), MaxValueValidator(150)],
        help_text="Diastolic blood pressure in mmHg"
    )

    # Blood Glucose (2-month retention)
    blood_glucose = models.FloatField(
        blank=True, null=True,
        validators=[MinValueValidator(20), MaxValueValidator(600)],
        help_text="Blood glucose in mg/dL"
    )

    # AFib Detection (2-month retention, iOS 14+)
    afib_detected = models.BooleanField(default=False, help_text="AFib detected in ECG")
    afib_burden_percent = models.FloatField(
        blank=True, null=True,
        validators=[MinValueValidator(0), MaxValueValidator(100)],
        help_text="AFib burden percentage"
    )

    # Body Temperature (2-month retention)
    body_temperature = models.FloatField(
        blank=True, null=True,
        validators=[MinValueValidator(30), MaxValueValidator(45)],
        help_text="Body temperature in Celsius"
    )
    wrist_temperature_delta = models.FloatField(
        blank=True, null=True,
        validators=[MinValueValidator(-5), MaxValueValidator(5)],
        help_text="Wrist temperature delta from baseline (iOS 16+)"
    )

    # Six-Minute Walk Test (2-month retention, iOS 14+)
    six_minute_walk_distance = models.FloatField(
        blank=True, null=True,
        validators=[MinValueValidator(0), MaxValueValidator(1000)],
        help_text="Six-minute walk test distance in meters"
    )

    # VO2 Max - Cardiovascular Fitness (2-month retention, iOS 11+)
    vo2_max = models.FloatField(
        blank=True, null=True,
        validators=[MinValueValidator(10), MaxValueValidator(90)],
        help_text="VO2 Max in mL/kg/min"
    )

    # Mobility Metrics (2-month retention, iOS 14+)
    walking_asymmetry_percent = models.FloatField(
        blank=True, null=True,
        validators=[MinValueValidator(0), MaxValueValidator(100)],
        help_text="Walking asymmetry percentage - gait imbalance indicator"
    )
    walking_speed = models.FloatField(
        blank=True, null=True,
        validators=[MinValueValidator(0), MaxValueValidator(10)],
        help_text="Walking speed in m/s"
    )
    double_support_time_percent = models.FloatField(
        blank=True, null=True,
        validators=[MinValueValidator(0), MaxValueValidator(100)],
        help_text="Double support time percentage - balance indicator"
    )
    stair_ascent_speed = models.FloatField(
        blank=True, null=True,
        validators=[MinValueValidator(0), MaxValueValidator(5)],
        help_text="Stair ascent speed in m/s"
    )
    stair_descent_speed = models.FloatField(
        blank=True, null=True,
        validators=[MinValueValidator(0), MaxValueValidator(5)],
        help_text="Stair descent speed in m/s"
    )

    # Peripheral Perfusion Index (2-month retention, iOS 11+)
    peripheral_perfusion_index = models.FloatField(
        blank=True, null=True,
        validators=[MinValueValidator(0), MaxValueValidator(20)],
        help_text="Peripheral perfusion index percentage"
    )

    # Timestamps
    recorded_at = models.DateTimeField(help_text="When the data was recorded on Watch")
    created_at = models.DateTimeField(auto_now_add=True)

    class Meta:
        db_table = 'watch_vitals'
        ordering = ['-recorded_at']
        indexes = [
            models.Index(fields=['user', 'recorded_at']),
        ]
        constraints = [
            models.UniqueConstraint(
                fields=['user', 'recorded_at'],
                name='unique_vitals_per_timestamp'
            ),
        ]

    def __str__(self):
        return f"{self.user.email} - Vitals at {self.recorded_at}"

    @property
    def heart_rate_status(self):
        if self.heart_rate < 50:
            return 'low'
        elif self.heart_rate > 100:
            return 'high'
        return 'normal'

    @property
    def sleep_quality_computed(self):
        """Compute sleep quality based on data"""
        if not self.total_sleep_hours:
            return None

        score = 0
        # Total sleep (7-9 hours ideal)
        if 7 <= self.total_sleep_hours <= 9:
            score += 3
        elif 6 <= self.total_sleep_hours < 7:
            score += 2
        elif self.total_sleep_hours < 6:
            score += 0
        else:
            score += 1

        # Awakenings (0-2 ideal)
        if self.awakenings_count <= 2:
            score += 3
        elif self.awakenings_count <= 4:
            score += 2
        elif self.awakenings_count <= 6:
            score += 1

        # Deep sleep (1.5-2h ideal)
        if self.deep_sleep_hours and self.deep_sleep_hours >= 1.5:
            score += 2
        elif self.deep_sleep_hours and self.deep_sleep_hours >= 1:
            score += 1

        if score >= 7:
            return 'excellent'
        elif score >= 5:
            return 'good'
        elif score >= 3:
            return 'fair'
        return 'poor'


# ============================================================
# CLINICAL DATA MODELS - Following Reports.md Specification
# For Parkinson's Disease Monitoring & Clinical Support
# ============================================================

class PatientClinicalProfile(models.Model):
    """
    Patient context data (collected once/updated rarely)
    Following Reports.md Section 3.1
    """
    HANDEDNESS_CHOICES = [
        ('L', 'Left'),
        ('R', 'Right'),
        ('A', 'Ambidextrous'),
    ]

    LIVING_SITUATION_CHOICES = [
        ('alone', 'Living Alone'),
        ('family', 'Living with Family'),
        ('caregiver', 'Living with Caregiver'),
        ('facility', 'Care Facility'),
    ]

    CAREGIVER_AVAILABILITY_CHOICES = [
        ('none', 'No Caregiver'),
        ('part_time', 'Part-time'),
        ('full_time', 'Full-time'),
        ('on_call', 'On-call/As needed'),
    ]

    user = models.OneToOneField(User, on_delete=models.CASCADE, related_name='clinical_profile')

    # Basic context
    handedness = models.CharField(max_length=1, choices=HANDEDNESS_CHOICES, blank=True, null=True)
    symptom_onset_date = models.DateField(blank=True, null=True, help_text="Date of first symptom onset")
    family_history_parkinsons = models.BooleanField(default=False, help_text="Family history of Parkinson's or tremor")
    family_history_details = models.TextField(blank=True, null=True, help_text="Details of family history")

    # Comorbidities (JSONField for flexibility)
    comorbidities = models.JSONField(default=list, blank=True, help_text="List of comorbid conditions")

    # Living situation
    living_situation = models.CharField(max_length=20, choices=LIVING_SITUATION_CHOICES, blank=True, null=True)
    caregiver_availability = models.CharField(max_length=20, choices=CAREGIVER_AVAILABILITY_CHOICES, default='none')
    caregiver_name = models.CharField(max_length=255, blank=True, null=True)
    caregiver_contact = models.CharField(max_length=50, blank=True, null=True)

    # Diagnosis status
    is_diagnosed_pd = models.BooleanField(default=False, help_text="Officially diagnosed with Parkinson's")
    diagnosis_date = models.DateField(blank=True, null=True)
    diagnosing_physician = models.CharField(max_length=255, blank=True, null=True)

    created_at = models.DateTimeField(auto_now_add=True)
    updated_at = models.DateTimeField(auto_now=True)

    class Meta:
        db_table = 'patient_clinical_profile'

    def __str__(self):
        return f"Clinical Profile for {self.user.email}"


class MotorSymptomEntry(models.Model):
    """
    Daily motor symptom tracking (mandatory core features)
    Following Reports.md Section 3.2
    Scale: 1-5 (1=minimal, 5=severe)
    """
    DATA_SOURCE_CHOICES = [
        ('patient', 'Patient-reported'),
        ('caregiver', 'Caregiver-reported'),
        ('device', 'Device-derived'),
        ('inferred', 'Inferred (low confidence)'),
    ]

    LATERALITY_CHOICES = [
        ('L', 'Left'),
        ('R', 'Right'),
        ('B', 'Both/Bilateral'),
    ]

    TREMOR_TYPE_CHOICES = [
        ('rest', 'Rest Tremor'),
        ('action', 'Action Tremor'),
        ('both', 'Both'),
        ('unknown', 'Unknown/Not specified'),
    ]

    user = models.ForeignKey(User, on_delete=models.CASCADE, related_name='motor_symptoms')
    recorded_date = models.DateField(help_text="Date of symptom recording")

    # Core motor symptoms (1-5 scale)
    bradykinesia = models.IntegerField(
        validators=[MinValueValidator(1), MaxValueValidator(5)],
        help_text="Slowness of movement (1=minimal, 5=severe) - MANDATORY core feature"
    )
    tremor = models.IntegerField(
        validators=[MinValueValidator(1), MaxValueValidator(5)],
        blank=True, null=True,
        help_text="Tremor severity (1=minimal, 5=severe)"
    )
    tremor_type = models.CharField(max_length=10, choices=TREMOR_TYPE_CHOICES, default='unknown')
    rigidity = models.IntegerField(
        validators=[MinValueValidator(1), MaxValueValidator(5)],
        blank=True, null=True,
        help_text="Muscle stiffness (1=minimal, 5=severe)"
    )
    gait_difficulty = models.IntegerField(
        validators=[MinValueValidator(1), MaxValueValidator(5)],
        blank=True, null=True,
        help_text="Gait/balance difficulty (1=minimal, 5=severe)"
    )

    # Laterality (diagnostic relevance)
    laterality = models.CharField(
        max_length=1, choices=LATERALITY_CHOICES,
        help_text="Which side primarily affected"
    )

    # Additional motor observations
    freezing_episodes = models.IntegerField(default=0, help_text="Number of freezing episodes")
    falls_today = models.IntegerField(default=0, help_text="Number of falls")

    # Data source tracking
    data_source = models.CharField(max_length=20, choices=DATA_SOURCE_CHOICES, default='patient')
    notes = models.TextField(blank=True, null=True)

    # Medication context (for correlation)
    hours_since_last_medication = models.FloatField(blank=True, null=True, help_text="Hours since last PD medication")

    created_at = models.DateTimeField(auto_now_add=True)

    class Meta:
        db_table = 'motor_symptom_entries'
        ordering = ['-recorded_date']
        indexes = [
            models.Index(fields=['user', '-recorded_date']),
        ]
        constraints = [
            models.UniqueConstraint(
                fields=['user', 'recorded_date'],
                name='unique_motor_entry_per_day'
            ),
        ]

    def __str__(self):
        return f"{self.user.email} - Motor Symptoms {self.recorded_date}"


class NonMotorSymptomEntry(models.Model):
    """
    Non-motor symptom tracking (collected weekly/monthly)
    Following Reports.md Section 3.3
    Scale: 1-5 (1=minimal, 5=severe)
    """
    DATA_SOURCE_CHOICES = [
        ('patient', 'Patient-reported'),
        ('caregiver', 'Caregiver-reported'),
        ('device', 'Device-derived'),
        ('inferred', 'Inferred (low confidence)'),
    ]

    user = models.ForeignKey(User, on_delete=models.CASCADE, related_name='non_motor_symptoms')
    recorded_date = models.DateField(help_text="Date of symptom recording")

    # Non-motor symptoms (1-5 scale)
    sleep_disturbance = models.IntegerField(
        validators=[MinValueValidator(1), MaxValueValidator(5)],
        blank=True, null=True,
        help_text="Sleep quality issues (1=none, 5=severe)"
    )
    rem_behavior_disorder = models.BooleanField(default=False, help_text="Acting out dreams during sleep")
    constipation = models.IntegerField(
        validators=[MinValueValidator(1), MaxValueValidator(5)],
        blank=True, null=True,
        help_text="Constipation severity (1=none, 5=severe)"
    )
    dizziness = models.IntegerField(
        validators=[MinValueValidator(1), MaxValueValidator(5)],
        blank=True, null=True,
        help_text="Dizziness/autonomic symptoms (1=none, 5=severe)"
    )
    mood_apathy = models.IntegerField(
        validators=[MinValueValidator(1), MaxValueValidator(5)],
        blank=True, null=True,
        help_text="Mood issues/apathy (1=none, 5=severe)"
    )
    fatigue = models.IntegerField(
        validators=[MinValueValidator(1), MaxValueValidator(5)],
        blank=True, null=True,
        help_text="Fatigue level (1=none, 5=severe)"
    )
    smell_loss = models.IntegerField(
        validators=[MinValueValidator(1), MaxValueValidator(5)],
        blank=True, null=True,
        help_text="Loss of smell (1=none, 5=complete)"
    )

    # Additional autonomic symptoms
    urinary_issues = models.IntegerField(
        validators=[MinValueValidator(1), MaxValueValidator(5)],
        blank=True, null=True,
        help_text="Urinary urgency/frequency (1=none, 5=severe)"
    )
    drooling = models.IntegerField(
        validators=[MinValueValidator(1), MaxValueValidator(5)],
        blank=True, null=True,
        help_text="Excessive saliva/drooling (1=none, 5=severe)"
    )

    # Data source
    data_source = models.CharField(max_length=20, choices=DATA_SOURCE_CHOICES, default='patient')
    notes = models.TextField(blank=True, null=True)

    created_at = models.DateTimeField(auto_now_add=True)

    class Meta:
        db_table = 'non_motor_symptom_entries'
        ordering = ['-recorded_date']
        indexes = [
            models.Index(fields=['user', '-recorded_date']),
        ]

    def __str__(self):
        return f"{self.user.email} - Non-Motor Symptoms {self.recorded_date}"


class MedicationDoseEntry(models.Model):
    """
    Per-dose medication tracking with timing
    Following Reports.md Section 3.4
    """
    STATUS_CHOICES = [
        ('taken', 'Taken'),
        ('missed', 'Missed'),
        ('late', 'Taken Late'),
        ('skipped', 'Skipped Intentionally'),
    ]

    DATA_SOURCE_CHOICES = [
        ('patient', 'Patient-reported'),
        ('caregiver', 'Caregiver-reported'),
        ('device', 'Device-derived'),
        ('inferred', 'Inferred (low confidence)'),
    ]

    user = models.ForeignKey(User, on_delete=models.CASCADE, related_name='medication_doses')

    # Medication info
    medication_name = models.CharField(max_length=255, help_text="Name of medication")
    medication_id = models.IntegerField(blank=True, null=True, help_text="Link to medicines.Medicine if exists")
    dose = models.CharField(max_length=100, help_text="Dose amount (e.g., '100mg', '1 tablet')")

    # Timing
    scheduled_time = models.DateTimeField(help_text="When the dose was scheduled")
    taken_time = models.DateTimeField(blank=True, null=True, help_text="When actually taken")
    delay_minutes = models.IntegerField(default=0, help_text="Delay from scheduled time")

    # Status
    status = models.CharField(max_length=10, choices=STATUS_CHOICES, default='taken')

    # Side effects
    side_effects = models.JSONField(default=list, blank=True, help_text="List of side effects observed")
    side_effects_notes = models.TextField(blank=True, null=True)

    # Data source
    data_source = models.CharField(max_length=20, choices=DATA_SOURCE_CHOICES, default='patient')

    created_at = models.DateTimeField(auto_now_add=True)

    class Meta:
        db_table = 'medication_dose_entries'
        ordering = ['-scheduled_time']
        indexes = [
            models.Index(fields=['user', '-scheduled_time']),
            models.Index(fields=['user', 'medication_name', '-scheduled_time']),
        ]

    def __str__(self):
        return f"{self.user.email} - {self.medication_name} {self.scheduled_time.date()}"


class SafetyEvent(models.Model):
    """
    Safety and red-flag event logging (event-driven, immediate)
    Following Reports.md Section 3.8
    """
    EVENT_TYPE_CHOICES = [
        ('fall', 'Fall'),
        ('hallucination', 'Hallucination'),
        ('rapid_worsening', 'Rapid Symptom Worsening'),
        ('autonomic_severe', 'Severe Autonomic Symptoms'),
        ('poor_levodopa_response', 'Poor Levodopa Response'),
        ('suicidal_ideation', 'Suicidal Ideation (PHQ-9 Q9>=2)'),
        ('other', 'Other Safety Concern'),
    ]

    SEVERITY_CHOICES = [
        ('low', 'Low'),
        ('medium', 'Medium'),
        ('high', 'High'),
        ('critical', 'Critical'),
    ]

    DATA_SOURCE_CHOICES = [
        ('patient', 'Patient-reported'),
        ('caregiver', 'Caregiver-reported'),
        ('device', 'Device-derived'),
        ('inferred', 'Inferred (low confidence)'),
    ]

    user = models.ForeignKey(User, on_delete=models.CASCADE, related_name='safety_events')

    event_type = models.CharField(max_length=30, choices=EVENT_TYPE_CHOICES)
    severity = models.CharField(max_length=10, choices=SEVERITY_CHOICES, default='medium')

    # Event details
    occurred_at = models.DateTimeField(help_text="When the event occurred")
    description = models.TextField(help_text="Description of the event")

    # For falls
    injury_sustained = models.BooleanField(default=False)
    injury_description = models.TextField(blank=True, null=True)

    # For hallucinations
    hallucination_type = models.CharField(max_length=50, blank=True, null=True, help_text="Visual, auditory, etc.")
    hallucination_content = models.TextField(blank=True, null=True)

    # Resolution
    is_resolved = models.BooleanField(default=False)
    resolution_notes = models.TextField(blank=True, null=True)
    resolved_at = models.DateTimeField(blank=True, null=True)

    # Escalation
    escalated_to_provider = models.BooleanField(default=False)
    escalated_at = models.DateTimeField(blank=True, null=True)

    # Data source
    data_source = models.CharField(max_length=20, choices=DATA_SOURCE_CHOICES, default='patient')

    created_at = models.DateTimeField(auto_now_add=True)

    class Meta:
        db_table = 'safety_events'
        ordering = ['-occurred_at']
        indexes = [
            models.Index(fields=['user', '-occurred_at']),
            models.Index(fields=['user', 'event_type', '-occurred_at']),
            models.Index(fields=['user', 'severity', '-occurred_at']),
        ]

    def __str__(self):
        return f"{self.user.email} - {self.event_type} at {self.occurred_at}"


class SpeechMetrics(models.Model):
    """
    Speech and voice metrics (collected weekly)
    Following Reports.md Section 3.6
    """
    DATA_SOURCE_CHOICES = [
        ('patient', 'Patient-reported'),
        ('caregiver', 'Caregiver-reported'),
        ('device', 'Device-derived'),
        ('inferred', 'Inferred (low confidence)'),
    ]

    user = models.ForeignKey(User, on_delete=models.CASCADE, related_name='speech_metrics')
    recorded_date = models.DateField(help_text="Date of recording")

    # Speech metrics (1-5 scale where applicable)
    voice_volume = models.IntegerField(
        validators=[MinValueValidator(1), MaxValueValidator(5)],
        blank=True, null=True,
        help_text="Voice volume (1=very quiet, 5=normal)"
    )
    speech_variability = models.IntegerField(
        validators=[MinValueValidator(1), MaxValueValidator(5)],
        blank=True, null=True,
        help_text="Speech variability/monotone (1=monotone, 5=normal variation)"
    )
    articulation_clarity = models.IntegerField(
        validators=[MinValueValidator(1), MaxValueValidator(5)],
        blank=True, null=True,
        help_text="Articulation clarity (1=unclear, 5=clear)"
    )

    # Device-derived metrics (if available)
    speech_rate_wpm = models.FloatField(blank=True, null=True, help_text="Words per minute")
    pause_duration_avg = models.FloatField(blank=True, null=True, help_text="Average pause duration in seconds")

    # Data source
    data_source = models.CharField(max_length=20, choices=DATA_SOURCE_CHOICES, default='patient')
    notes = models.TextField(blank=True, null=True)

    # Audio file reference (if recorded)
    audio_file = models.FileField(upload_to='speech_recordings/%Y/%m/', blank=True, null=True)

    created_at = models.DateTimeField(auto_now_add=True)

    class Meta:
        db_table = 'speech_metrics'
        ordering = ['-recorded_date']
        indexes = [
            models.Index(fields=['user', '-recorded_date']),
        ]

    def __str__(self):
        return f"{self.user.email} - Speech Metrics {self.recorded_date}"


class CognitiveScreening(models.Model):
    """
    Cognitive and mood screening (collected monthly)
    Following Reports.md Section 3.7
    Safety rule: PHQ-9 Q9 >= 2 triggers immediate escalation
    """
    DATA_SOURCE_CHOICES = [
        ('patient', 'Patient-reported'),
        ('caregiver', 'Caregiver-reported'),
        ('device', 'Device-derived'),
        ('inferred', 'Inferred (low confidence)'),
    ]

    user = models.ForeignKey(User, on_delete=models.CASCADE, related_name='cognitive_screenings')
    recorded_date = models.DateField(help_text="Date of screening")

    # MoCA-lite (cognitive screening)
    moca_lite_score = models.IntegerField(
        validators=[MinValueValidator(0), MaxValueValidator(30)],
        blank=True, null=True,
        help_text="MoCA-lite total score (0-30)"
    )
    moca_lite_responses = models.JSONField(default=dict, blank=True, help_text="Individual MoCA-lite responses")

    # PHQ-9 (depression screening)
    phq9_total_score = models.IntegerField(
        validators=[MinValueValidator(0), MaxValueValidator(27)],
        blank=True, null=True,
        help_text="PHQ-9 total score (0-27)"
    )
    phq9_responses = models.JSONField(default=dict, blank=True, help_text="Individual PHQ-9 responses (Q1-Q9)")
    phq9_q9_score = models.IntegerField(
        validators=[MinValueValidator(0), MaxValueValidator(3)],
        blank=True, null=True,
        help_text="PHQ-9 Question 9 score (suicidal ideation) - SAFETY CRITICAL"
    )

    # Safety flag
    requires_immediate_escalation = models.BooleanField(
        default=False,
        help_text="True if PHQ-9 Q9 >= 2 (suicidal ideation)"
    )
    escalation_handled = models.BooleanField(default=False)
    escalation_notes = models.TextField(blank=True, null=True)

    # Data source
    data_source = models.CharField(max_length=20, choices=DATA_SOURCE_CHOICES, default='patient')
    notes = models.TextField(blank=True, null=True)

    created_at = models.DateTimeField(auto_now_add=True)

    class Meta:
        db_table = 'cognitive_screenings'
        ordering = ['-recorded_date']
        indexes = [
            models.Index(fields=['user', '-recorded_date']),
        ]

    def save(self, *args, **kwargs):
        # Safety rule: PHQ-9 Q9 >= 2 triggers immediate escalation
        if self.phq9_q9_score is not None and self.phq9_q9_score >= 2:
            self.requires_immediate_escalation = True
        super().save(*args, **kwargs)

    def __str__(self):
        return f"{self.user.email} - Cognitive Screening {self.recorded_date}"


class ClinicalReport(models.Model):
    """
    Generated clinical reports (daily, weekly, monthly)
    Following Reports.md Sections 2.1-2.4
    """
    REPORT_TYPE_CHOICES = [
        ('baseline', 'Baseline Diagnostic Summary'),
        ('daily', 'Daily Clinical Summary'),
        ('weekly', 'Weekly Clinical Trend Report'),
        ('monthly', 'Monthly Neurologist Report'),
    ]

    STATUS_CHOICES = [
        ('generating', 'Generating'),
        ('complete', 'Complete'),
        ('incomplete', 'Incomplete Data'),
        ('failed', 'Generation Failed'),
    ]

    user = models.ForeignKey(User, on_delete=models.CASCADE, related_name='clinical_reports')

    report_type = models.CharField(max_length=20, choices=REPORT_TYPE_CHOICES)
    status = models.CharField(max_length=20, choices=STATUS_CHOICES, default='generating')

    # Report period
    period_start = models.DateField(help_text="Start of reporting period")
    period_end = models.DateField(help_text="End of reporting period")

    # Data completeness (following Reports.md Section 6)
    data_completeness_percent = models.FloatField(
        default=0,
        validators=[MinValueValidator(0), MaxValueValidator(100)],
        help_text="Percentage of required fields completed"
    )
    meets_minimum_criteria = models.BooleanField(default=False, help_text="Daily>=60%, Weekly>=4days, Monthly>=70%")

    # Report content (structured JSON following Toon format)
    report_content = models.JSONField(default=dict, help_text="Structured report data in Toon format")

    # Summary sections
    motor_summary = models.TextField(blank=True, null=True, help_text="Motor symptom summary")
    non_motor_summary = models.TextField(blank=True, null=True, help_text="Non-motor symptom summary")
    medication_summary = models.TextField(blank=True, null=True, help_text="Medication adherence/effectiveness summary")
    safety_summary = models.TextField(blank=True, null=True, help_text="Safety events summary")
    quality_of_life_summary = models.TextField(blank=True, null=True, help_text="QoL impact summary")

    # AI-generated insights
    ai_insights = models.JSONField(default=list, help_text="AI-generated clinical insights")
    red_flags = models.JSONField(default=list, help_text="Identified red flags requiring attention")
    recommendations = models.JSONField(default=list, help_text="Recommendations for clinician review")

    # Validation checklist (Reports.md Section 8)
    validation_checklist = models.JSONField(default=dict, help_text="Agent validation results")
    bradykinesia_assessed = models.BooleanField(default=False)
    laterality_captured = models.BooleanField(default=False)
    medication_timing_correlated = models.BooleanField(default=False)
    red_flags_escalated = models.BooleanField(default=False)
    data_sources_tagged = models.BooleanField(default=False)

    # Legal disclaimer (Reports.md Section 7)
    disclaimer = models.TextField(
        default="This report is generated from self-reported and device-derived data and is intended to support, not replace, clinical judgment.",
        help_text="Legal/ethical disclaimer"
    )

    # Metadata
    generated_at = models.DateTimeField(auto_now_add=True)
    ai_model_used = models.CharField(max_length=50, default='gpt-4o-mini')
    generation_time_seconds = models.FloatField(blank=True, null=True)

    # Access tracking
    viewed_by_patient = models.BooleanField(default=False)
    viewed_by_patient_at = models.DateTimeField(blank=True, null=True)
    viewed_by_provider = models.BooleanField(default=False)
    viewed_by_provider_at = models.DateTimeField(blank=True, null=True)

    class Meta:
        db_table = 'clinical_reports'
        ordering = ['-period_end', '-generated_at']
        indexes = [
            models.Index(fields=['user', 'report_type', '-period_end']),
            models.Index(fields=['user', '-generated_at']),
        ]

    def __str__(self):
        return f"{self.user.email} - {self.report_type} Report ({self.period_start} to {self.period_end})"

    def check_minimum_criteria(self):
        """Check if report meets minimum data requirements per Reports.md Section 6"""
        if self.report_type == 'daily':
            return self.data_completeness_percent >= 60
        elif self.report_type == 'weekly':
            # At least 4 days of data
            days_with_data = self.report_content.get('days_with_data', 0)
            return days_with_data >= 4
        elif self.report_type == 'monthly':
            return self.data_completeness_percent >= 70
        return True  # Baseline reports have different criteria


class AgentDataCollection(models.Model):
    """
    Tracks agent's data collection activity and gaps
    Helps agent know what questions to ask
    """
    user = models.ForeignKey(User, on_delete=models.CASCADE, related_name='agent_data_collections')

    # Data domain tracking
    domain = models.CharField(max_length=50, help_text="Data domain (motor, non_motor, medication, etc.)")
    field_name = models.CharField(max_length=100, help_text="Specific field name")

    # Collection status
    last_collected_at = models.DateTimeField(blank=True, null=True)
    collection_frequency = models.CharField(
        max_length=20,
        choices=[
            ('daily', 'Daily'),
            ('weekly', 'Weekly'),
            ('monthly', 'Monthly'),
            ('once', 'One-time'),
        ],
        default='daily'
    )

    # Gap tracking
    is_overdue = models.BooleanField(default=False)
    days_overdue = models.IntegerField(default=0)
    priority = models.IntegerField(default=5, help_text="Collection priority (1=highest, 10=lowest)")

    # Agent prompt
    collection_prompt = models.TextField(
        help_text="Plain-language prompt for agent to ask (<=12 words per Reports.md)"
    )

    created_at = models.DateTimeField(auto_now_add=True)
    updated_at = models.DateTimeField(auto_now=True)

    class Meta:
        db_table = 'agent_data_collection'
        ordering = ['priority', '-days_overdue']
        indexes = [
            models.Index(fields=['user', 'domain', 'is_overdue']),
        ]
        constraints = [
            models.UniqueConstraint(
                fields=['user', 'domain', 'field_name'],
                name='unique_data_collection_per_user_field'
            ),
        ]

    def __str__(self):
        return f"{self.user.email} - {self.domain}.{self.field_name}"
