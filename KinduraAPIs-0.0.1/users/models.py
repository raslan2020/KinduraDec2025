"""
=============================================================================
KINDURA AI - USER MODELS
=============================================================================
Core user and health-related data models for the Kindura AI application.

Models in this file:
- User: Custom user model with health-specific fields
- UserToken: Authentication tokens with expiration
- UserJSON: Uploaded JSON data storage
- PasswordResetToken: Password reset OTP tokens
- PatientReport: AI-generated health reports (daily/weekly/monthly)
- Contact: Emergency contacts and caregivers
- PatientObservation: Health observations from voice conversations

Database:
- PostgreSQL with Django ORM
- Run `python manage.py migrate` after changes

Flutter Mapping:
- User → lib/models/user_profile/user_profile_model.dart
- PatientReport → lib/screens/kindura_reports/
- Contact → lib/models/contact/contact_model.dart

API Endpoints:
- /api/users/profile/ → User profile
- /api/users/patient-reports/ → Patient reports
- /api/users/observations/ → Health observations
- /api/users/contacts/ → Emergency contacts

@see /docs/DEVELOPER_GUIDE.md for full documentation
=============================================================================
"""

from django.contrib.auth.models import AbstractUser
from django.db import models
from django.core.validators import EmailValidator
from django.core.exceptions import ValidationError
from django.utils import timezone
import secrets


class User(AbstractUser):
    """
    Custom User model for the medical app
    """
    email = models.EmailField(unique=True, validators=[EmailValidator()])
    phone_number = models.CharField(max_length=15, blank=True, null=True)
    age = models.PositiveIntegerField(blank=True, null=True)
    language = models.CharField(default='en')
    GENDER_CHOICES = [
        ('M', 'Male'),
        ('F', 'Female'),
        ('O', 'Other'),
    ]
    AGENT_CONSERVATION_CHOICES = [
        ('S', 'Short'),
        ('M', 'Medium'),
        ('D', 'Detailed'),
    ]
    UNIT_SYSTEM_CHOICES = [
        ('US', 'US Standard (mg/dL, lbs, °F)'),
        ('SI', 'International SI (mmol/L, kg, °C)'),
    ]
    gender = models.CharField(max_length=1, choices=GENDER_CHOICES, default='M' ,blank=True, null=True)
    agent_conservation_choice = models.CharField(max_length=1, choices=AGENT_CONSERVATION_CHOICES, blank=True, null=True)
    address = models.TextField(blank=True, null=True)
    terms_and_conditions = models.BooleanField(default=False)
    unit_system = models.CharField(max_length=2, choices=UNIT_SYSTEM_CHOICES, default='US', help_text='Preferred unit system for lab values and measurements')

    # Agent permissions
    allow_agent_medication_updates = models.BooleanField(
        default=False,
        help_text='Allow Kindura AI to mark medications as taken/missed via voice commands'
    )

    # Extended health vitals collection
    extended_vitals_enabled = models.BooleanField(
        default=False,
        help_text='Enable collection of extended HealthKit vitals (walking steadiness, blood glucose, VO2 max, mobility metrics, etc.)'
    )

    # Vitals data retention period
    VITALS_RETENTION_CHOICES = [
        (30, '30 days'),
        (60, '60 days'),
    ]
    vitals_retention_days = models.IntegerField(
        choices=VITALS_RETENTION_CHOICES,
        default=60,
        help_text='Number of days to retain health vitals data (30 or 60 days max)'
    )

    # Individual extended vitals preferences (which vitals to display)
    # JSON object with vital name as key and boolean as value
    # Default enables all vitals
    extended_vitals_preferences = models.JSONField(
        default=dict,
        blank=True,
        help_text='Individual toggle for each extended vital. Keys: walking_steadiness, blood_pressure, blood_glucose, body_temperature, wrist_temperature, vo2_max, afib_detection, six_min_walk, walking_asymmetry, walking_speed, double_support_time, stair_ascent, stair_descent, peripheral_perfusion'
    )

    # Override username field to use email
    USERNAME_FIELD = 'email'
    REQUIRED_FIELDS = ['username']
    
    def clean(self):
        super().clean()
        if self.age and self.age > 150:
            raise ValidationError('Age cannot be greater than 150')
    
    def __str__(self):
        return self.email


class UserToken(models.Model):
    """
    Token model for user authentication with expiration support
    """
    TOKEN_EXPIRY_DAYS = 30  # Default token validity period

    user = models.ForeignKey(User, on_delete=models.CASCADE, related_name='tokens')
    token = models.CharField(max_length=255, unique=True)
    created_at = models.DateTimeField(auto_now_add=True)
    expires_at = models.DateTimeField(null=True, blank=True)
    is_active = models.BooleanField(default=True)
    last_used_at = models.DateTimeField(null=True, blank=True)

    def save(self, *args, **kwargs):
        # Set default expiration if not provided
        if not self.expires_at and not self.pk:
            self.expires_at = timezone.now() + timezone.timedelta(days=self.TOKEN_EXPIRY_DAYS)
        super().save(*args, **kwargs)

    def is_valid(self):
        """Check if token is active and not expired"""
        if not self.is_active:
            return False
        if self.expires_at and timezone.now() > self.expires_at:
            return False
        return True

    def refresh(self, extend_days=None):
        """Extend token expiration"""
        days = extend_days or self.TOKEN_EXPIRY_DAYS
        self.expires_at = timezone.now() + timezone.timedelta(days=days)
        self.last_used_at = timezone.now()
        self.save()

    def __str__(self):
        return f"Token for {self.user.email}"

    class Meta:
        db_table = 'user_tokens'


class UserJSON(models.Model):
    """
    Model to store uploaded JSON data for each user
    """
    STATUS_CHOICES = [
        ('pending', 'Pending'),
        ('processing', 'Processing'),
        ('completed', 'Completed'),
        ('failed', 'Failed'),
    ]
    
    user = models.ForeignKey(User, on_delete=models.CASCADE, related_name='json_uploads')
    uploaded_at = models.DateTimeField(auto_now_add=True)
    data = models.JSONField()
    status = models.CharField(max_length=20, choices=STATUS_CHOICES, default='pending')
    summarize_patient_report = models.CharField(null=True, blank=True) 
    error_message = models.TextField(blank=True, null=True)

    def __str__(self):
        return f"JSON upload by {self.user.email} at {self.uploaded_at} (Status: {self.status})"


class PasswordResetToken(models.Model):
    """
    Token for password reset functionality
    """
    user = models.ForeignKey(User, on_delete=models.CASCADE, related_name='password_reset_tokens')
    token = models.CharField(max_length=6)  # 6-digit OTP code
    created_at = models.DateTimeField(auto_now_add=True)
    expires_at = models.DateTimeField()
    is_used = models.BooleanField(default=False)

    def save(self, *args, **kwargs):
        if not self.token:
            self.token = ''.join([str(secrets.randbelow(10)) for _ in range(6)])
        if not self.expires_at:
            self.expires_at = timezone.now() + timezone.timedelta(minutes=15)
        super().save(*args, **kwargs)

    def is_valid(self):
        return not self.is_used and timezone.now() < self.expires_at

    def __str__(self):
        return f"Password reset token for {self.user.email}"

    class Meta:
        db_table = 'password_reset_tokens'


class PatientReport(models.Model):
    """
    Kindura patient reports - daily, weekly, monthly summaries
    Generated by the AI agent with observations and recommendations
    """
    REPORT_TYPE_CHOICES = [
        ('daily', 'Daily'),
        ('weekly', 'Weekly'),
        ('monthly', 'Monthly'),
    ]

    user = models.ForeignKey(User, on_delete=models.CASCADE, related_name='patient_reports')
    report_type = models.CharField(max_length=10, choices=REPORT_TYPE_CHOICES)
    report_date = models.DateField()  # The date the report covers
    period_start = models.DateField()  # Start of reporting period
    period_end = models.DateField()  # End of reporting period

    # Medication Adherence Summary
    total_doses_scheduled = models.IntegerField(default=0)
    doses_taken = models.IntegerField(default=0)
    doses_missed = models.IntegerField(default=0)
    doses_late = models.IntegerField(default=0)
    adherence_percentage = models.FloatField(default=0)

    # Side Effects Summary
    side_effects_reported = models.JSONField(default=list)  # List of side effects
    side_effects_count = models.IntegerField(default=0)

    # Well-being Observations
    sleep_quality_avg = models.CharField(max_length=20, blank=True, null=True)  # good/fair/poor
    energy_level_avg = models.CharField(max_length=20, blank=True, null=True)
    mood_observations = models.TextField(blank=True, null=True)
    symptom_observations = models.TextField(blank=True, null=True)

    # AI-generated content
    ai_summary = models.TextField(blank=True, null=True)  # Overall summary
    ai_observations = models.TextField(blank=True, null=True)  # Key observations
    ai_recommendations = models.TextField(blank=True, null=True)  # Recommendations for doctor
    ai_concerns = models.TextField(blank=True, null=True)  # Areas of concern

    # Conversation data
    conversation_count = models.IntegerField(default=0)  # Number of conversations
    conversations_data = models.JSONField(default=list)  # Raw conversation summaries

    # Enhanced Analytics Data (for graphs and detailed insights)
    # Vitals Analytics - time series data for graphing
    vitals_analytics = models.JSONField(default=dict, blank=True)  # {heart_rate: [{date, value, avg, min, max}], ...}

    # Sleep Analytics - detailed sleep data
    sleep_analytics = models.JSONField(default=dict, blank=True)  # {total_hours: [], quality: [], stages: {deep, rem, light}, patterns}

    # Fall Events - fall detection data
    fall_events = models.JSONField(default=list, blank=True)  # [{date, time, severity, context, follow_up_status}]
    fall_count = models.IntegerField(default=0)

    # Medication Analytics - per-medication performance
    medication_analytics = models.JSONField(default=dict, blank=True)  # {med_id: {adherence, side_effects, timing_accuracy}}

    # Biomarker Trends - lab value changes during period
    biomarker_trends = models.JSONField(default=dict, blank=True)  # {biomarker: {values, trend_direction, analysis}}

    # Activity Analytics - steps, calories, exercise (from Apple Watch)
    activity_analytics = models.JSONField(default=dict, blank=True)  # {avg_steps, avg_calories, exercise_minutes, activity_level}

    # Mobility Analytics - walking metrics critical for PD monitoring
    mobility_analytics = models.JSONField(default=dict, blank=True)  # {walking_asymmetry, walking_speed, double_support_time, stair_climbing}

    # Clinical Analytics - motor/non-motor symptoms, speech metrics, cognitive screening
    clinical_analytics = models.JSONField(default=dict, blank=True)  # {motor_symptoms, non_motor_symptoms, speech_metrics, cognitive_screening}

    # AI-enhanced analysis sections
    ai_sleep_analysis = models.TextField(blank=True, null=True)  # Detailed sleep pattern analysis
    ai_vitals_analysis = models.TextField(blank=True, null=True)  # Heart rate, BP, SpO2 insights
    ai_medication_insights = models.TextField(blank=True, null=True)  # Medication effectiveness
    ai_side_effect_correlations = models.TextField(blank=True, null=True)  # What caused side effects
    ai_doctor_summary = models.TextField(blank=True, null=True)  # Executive summary for doctor
    ai_patient_summary = models.TextField(blank=True, null=True)  # Patient-friendly summary

    # Health Scores (0-100)
    overall_health_score = models.IntegerField(default=0)
    adherence_score = models.IntegerField(default=0)
    sleep_score = models.IntegerField(default=0)
    vitals_score = models.IntegerField(default=0)

    # Generation Status & Progress
    STATUS_CHOICES = [
        ('pending', 'Pending'),
        ('processing', 'Processing'),
        ('completed', 'Completed'),
        ('failed', 'Failed'),
    ]
    status = models.CharField(max_length=20, choices=STATUS_CHOICES, default='pending')
    progress = models.IntegerField(default=0)  # 0-100 percentage
    error_message = models.TextField(blank=True, null=True)

    # Metadata
    created_at = models.DateTimeField(auto_now_add=True)
    updated_at = models.DateTimeField(auto_now=True)
    is_finalized = models.BooleanField(default=False)  # Can no longer be updated
    pdf_generated = models.BooleanField(default=False)
    pdf_file = models.FileField(upload_to='patient_reports/', blank=True, null=True)

    class Meta:
        db_table = 'patient_reports'
        ordering = ['-report_date', '-created_at']
        unique_together = ['user', 'report_type', 'report_date']

    def __str__(self):
        return f"{self.user.email} - {self.report_type} report for {self.report_date}"

    @property
    def adherence_grade(self):
        if self.adherence_percentage >= 95:
            return 'Excellent'
        elif self.adherence_percentage >= 85:
            return 'Good'
        elif self.adherence_percentage >= 70:
            return 'Fair'
        return 'Poor'


class Contact(models.Model):
    """
    Contact list for user - family members, caregivers, emergency contacts, etc.
    Agent can read these contacts and user can call them via FaceTime.
    """
    CONTACT_TYPE_CHOICES = [
        ('family', 'Family Member'),
        ('caregiver', 'Caregiver'),
        ('emergency', 'Emergency Contact'),
        ('doctor', 'Doctor'),
        ('pharmacy', 'Pharmacy'),
        ('other', 'Other'),
    ]

    RELATIONSHIP_CHOICES = [
        ('spouse', 'Spouse'),
        ('parent', 'Parent'),
        ('child', 'Child'),
        ('sibling', 'Sibling'),
        ('friend', 'Friend'),
        ('caregiver', 'Caregiver'),
        ('doctor', 'Doctor'),
        ('nurse', 'Nurse'),
        ('other', 'Other'),
    ]

    user = models.ForeignKey(User, on_delete=models.CASCADE, related_name='contacts')
    name = models.CharField(max_length=100)
    contact_type = models.CharField(max_length=20, choices=CONTACT_TYPE_CHOICES, default='family')
    relationship = models.CharField(max_length=20, choices=RELATIONSHIP_CHOICES, default='other')
    phone_number = models.CharField(max_length=20, blank=True, null=True)
    email = models.EmailField(blank=True, null=True)
    is_emergency = models.BooleanField(default=False)
    is_primary = models.BooleanField(default=False)  # Primary contact for this type
    notes = models.TextField(blank=True, null=True)

    # FaceTime support
    facetime_id = models.CharField(max_length=100, blank=True, null=True)  # Phone or email for FaceTime

    # Metadata
    created_at = models.DateTimeField(auto_now_add=True)
    updated_at = models.DateTimeField(auto_now=True)
    is_active = models.BooleanField(default=True)

    class Meta:
        db_table = 'user_contacts'
        ordering = ['-is_emergency', '-is_primary', 'name']

    def __str__(self):
        return f"{self.name} ({self.contact_type}) - {self.user.email}"

    @property
    def facetime_available(self):
        """Check if FaceTime is available for this contact"""
        return bool(self.facetime_id or self.phone_number or self.email)

    @property
    def facetime_target(self):
        """Get the best FaceTime target (phone or email)"""
        return self.facetime_id or self.phone_number or self.email


class PatientObservation(models.Model):
    """
    Daily observations collected by Kindura AI during conversations.
    Used to build daily/weekly/monthly reports for doctors.
    """
    OBSERVATION_TYPE_CHOICES = [
        ('medication', 'Medication'),
        ('sleep', 'Sleep'),
        ('mood', 'Mood'),
        ('symptom', 'Symptom'),
        ('side_effect', 'Side Effect'),
        ('fall', 'Fall'),
        ('pain', 'Pain'),
        ('energy', 'Energy'),
        ('appetite', 'Appetite'),
        ('vital', 'Vital Sign'),
        ('general', 'General'),
    ]

    SEVERITY_CHOICES = [
        ('normal', 'Normal'),
        ('mild', 'Mild'),
        ('moderate', 'Moderate'),
        ('severe', 'Severe'),
        ('critical', 'Critical'),
    ]

    user = models.ForeignKey(User, on_delete=models.CASCADE, related_name='observations')
    observation_type = models.CharField(max_length=20, choices=OBSERVATION_TYPE_CHOICES)
    severity = models.CharField(max_length=10, choices=SEVERITY_CHOICES, default='normal')

    # Core observation data
    title = models.CharField(max_length=200)  # Brief description
    description = models.TextField()  # Detailed observation
    value = models.CharField(max_length=100, blank=True, null=True)  # e.g., "7 hours", "good", "5/10"

    # Context
    medication_id = models.IntegerField(blank=True, null=True)  # Related medication if applicable
    conversation_id = models.CharField(max_length=100, blank=True, null=True)

    # AI analysis
    ai_insight = models.TextField(blank=True, null=True)  # AI-generated insight
    ai_concern_level = models.IntegerField(default=0)  # 0-10 scale
    requires_attention = models.BooleanField(default=False)  # Flag for doctor review

    # Timestamps
    observed_at = models.DateTimeField()  # When the observation occurred
    created_at = models.DateTimeField(auto_now_add=True)

    # Metadata
    source = models.CharField(max_length=50, default='voice')  # voice, app, sensor

    class Meta:
        db_table = 'patient_observations'
        ordering = ['-observed_at']
        indexes = [
            models.Index(fields=['user', 'observation_type', 'observed_at']),
            models.Index(fields=['user', 'requires_attention']),
        ]

    def __str__(self):
        return f"{self.user.email} - {self.observation_type}: {self.title}"


class DeviceContact(models.Model):
    """
    Contacts synced from user's device (iOS Contacts).
    Allows the AI agent to search and reference device contacts.
    """
    user = models.ForeignKey(User, on_delete=models.CASCADE, related_name='device_contacts')
    device_id = models.CharField(max_length=100)  # iOS contact identifier

    # Name fields
    given_name = models.CharField(max_length=100, blank=True)
    family_name = models.CharField(max_length=100, blank=True)
    full_name = models.CharField(max_length=200)
    nickname = models.CharField(max_length=100, blank=True, null=True)
    organization = models.CharField(max_length=200, blank=True, null=True)

    # Contact info (stored as JSON for multiple numbers/emails)
    phone_numbers = models.JSONField(default=list)  # [{"label": "mobile", "number": "+1234567890"}, ...]
    emails = models.JSONField(default=list)  # [{"label": "home", "email": "test@test.com"}, ...]

    # Primary contact methods (for quick access)
    primary_phone = models.CharField(max_length=20, blank=True, null=True)
    primary_email = models.EmailField(blank=True, null=True)

    # Sync metadata
    last_synced_at = models.DateTimeField(auto_now=True)
    created_at = models.DateTimeField(auto_now_add=True)

    class Meta:
        db_table = 'device_contacts'
        unique_together = ['user', 'device_id']
        ordering = ['full_name']
        indexes = [
            models.Index(fields=['user', 'full_name']),
        ]

    def __str__(self):
        return f"{self.full_name} ({self.user.email})"

    def save(self, *args, **kwargs):
        # Auto-extract primary phone and email
        if self.phone_numbers and not self.primary_phone:
            # Prefer mobile numbers
            for phone in self.phone_numbers:
                label = phone.get('label', '').lower()
                if 'mobile' in label or 'cell' in label:
                    self.primary_phone = phone.get('number')
                    break
            if not self.primary_phone and self.phone_numbers:
                self.primary_phone = self.phone_numbers[0].get('number')

        if self.emails and not self.primary_email:
            self.primary_email = self.emails[0].get('email')

        super().save(*args, **kwargs)


class CommunicationRequest(models.Model):
    """
    Communication requests from the AI agent.
    Agent creates these requests, and the Flutter app polls and executes them.
    """
    REQUEST_TYPE_CHOICES = [
        ('call', 'Phone Call'),
        ('facetime_video', 'FaceTime Video'),
        ('facetime_audio', 'FaceTime Audio'),
        ('message', 'Text Message'),
    ]

    STATUS_CHOICES = [
        ('pending', 'Pending'),
        ('shown', 'Shown to User'),
        ('approved', 'Approved'),
        ('rejected', 'Rejected'),
        ('completed', 'Completed'),
        ('expired', 'Expired'),
    ]

    user = models.ForeignKey(User, on_delete=models.CASCADE, related_name='communication_requests')
    request_type = models.CharField(max_length=20, choices=REQUEST_TYPE_CHOICES)
    status = models.CharField(max_length=20, choices=STATUS_CHOICES, default='pending')

    # Target contact
    contact_name = models.CharField(max_length=200)  # Name of the contact
    phone_number = models.CharField(max_length=20, blank=True, null=True)
    email = models.EmailField(blank=True, null=True)

    # For messages
    message_body = models.TextField(blank=True, null=True)

    # Context from agent
    agent_reason = models.TextField(blank=True, null=True)  # Why the agent is making this request
    conversation_id = models.CharField(max_length=100, blank=True, null=True)

    # Timestamps
    created_at = models.DateTimeField(auto_now_add=True)
    expires_at = models.DateTimeField()  # Requests expire after some time
    completed_at = models.DateTimeField(blank=True, null=True)

    class Meta:
        db_table = 'communication_requests'
        ordering = ['-created_at']
        indexes = [
            models.Index(fields=['user', 'status', 'created_at']),
        ]

    def __str__(self):
        return f"{self.request_type} to {self.contact_name} ({self.status})"

    def save(self, *args, **kwargs):
        # Set expiration to 5 minutes from creation if not set
        if not self.expires_at:
            self.expires_at = timezone.now() + timezone.timedelta(minutes=5)
        super().save(*args, **kwargs)

    @property
    def is_expired(self):
        return timezone.now() > self.expires_at
