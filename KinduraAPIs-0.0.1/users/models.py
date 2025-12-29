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
