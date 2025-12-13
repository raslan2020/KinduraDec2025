from django.db import models
from django.conf import settings
from django.utils import timezone
import uuid
import json


class VitalSign(models.Model):
    VITAL_TYPES = [
        ('blood_pressure', 'Blood Pressure'),
        ('heart_rate', 'Heart Rate'),
        ('weight', 'Weight'),
        ('blood_sugar', 'Blood Sugar'),
        ('temperature', 'Temperature'),
        ('oxygen_saturation', 'Oxygen Saturation'),
    ]

    user = models.ForeignKey(settings.AUTH_USER_MODEL, on_delete=models.CASCADE, related_name='vital_signs')
    type = models.CharField(max_length=20, choices=VITAL_TYPES)
    value = models.FloatField(null=True, blank=True)  # For single values
    systolic = models.FloatField(null=True, blank=True)  # For blood pressure
    diastolic = models.FloatField(null=True, blank=True)  # For blood pressure
    unit = models.CharField(max_length=10)
    notes = models.TextField(blank=True)
    recorded_at = models.DateTimeField(default=timezone.now)
    created_at = models.DateTimeField(auto_now_add=True)
    updated_at = models.DateTimeField(auto_now=True)

    class Meta:
        ordering = ['-recorded_at']

    def __str__(self):
        return f"{self.user.username} - {self.type} - {self.recorded_at}"


class BloodTest(models.Model):
    user = models.ForeignKey(settings.AUTH_USER_MODEL, on_delete=models.CASCADE, related_name='blood_tests')
    test_name = models.CharField(max_length=200)
    test_date = models.DateTimeField(default=timezone.now)
    results = models.JSONField(default=dict)  # Store test results as JSON
    reference_ranges = models.JSONField(default=dict)
    notes = models.TextField(blank=True)
    created_at = models.DateTimeField(auto_now_add=True)
    updated_at = models.DateTimeField(auto_now=True)

    class Meta:
        ordering = ['-test_date']

    def __str__(self):
        return f"{self.user.username} - {self.test_name} - {self.test_date}"


class MedicalDocument(models.Model):
    DOCUMENT_TYPES = [
        ('lab_report', 'Lab Report'),
        ('prescription', 'Prescription'),
        ('scan', 'Medical Scan'),
        ('discharge_summary', 'Discharge Summary'),
        ('consultation', 'Consultation Report'),
        ('other', 'Other'),
    ]

    user = models.ForeignKey(settings.AUTH_USER_MODEL, on_delete=models.CASCADE, related_name='medical_documents')
    title = models.CharField(max_length=200)
    document_type = models.CharField(max_length=20, choices=DOCUMENT_TYPES, default='other')
    file = models.FileField(upload_to='medical_documents/%Y/%m/')
    description = models.TextField(blank=True)
    uploaded_at = models.DateTimeField(auto_now_add=True)
    parsed_data = models.JSONField(default=dict, blank=True)  # Store AI-parsed data
    is_parsed = models.BooleanField(default=False)

    class Meta:
        ordering = ['-uploaded_at']

    def __str__(self):
        return f"{self.user.username} - {self.title} - {self.document_type}"


class MedicalReport(models.Model):
    """Aggregated medical report data for a user"""
    user = models.OneToOneField(settings.AUTH_USER_MODEL, on_delete=models.CASCADE, related_name='medical_report')
    summary = models.TextField(blank=True)
    last_updated = models.DateTimeField(auto_now=True)

    def __str__(self):
        return f"{self.user.username} - Medical Report"

    def get_report_data(self):
        """Get all medical report data for the user"""
        vital_signs = list(self.user.vital_signs.values(
            'id', 'type', 'value', 'systolic', 'diastolic', 'unit', 'notes', 'recorded_at'
        ))

        blood_tests = list(self.user.blood_tests.values(
            'id', 'test_name', 'test_date', 'results', 'reference_ranges', 'notes'
        ))

        documents = list(self.user.medical_documents.values(
            'id', 'title', 'document_type', 'file', 'description', 'uploaded_at', 'is_parsed', 'parsed_data'
        ))

        return {
            'status': True,
            'result': {
                'vital_signs': vital_signs,
                'blood_tests': blood_tests,
                'documents': documents,
                'summary': self.summary,
                'last_updated': self.last_updated,
            }
        }


class UploadedMedicalReport(models.Model):
    """
    Comprehensive medical report uploaded by user
    Stores extracted information, recommendations, and tracking status
    """
    STATUS_CHOICES = [
        ('pending_review', 'Pending Review'),
        ('reviewed', 'Reviewed'),
        ('changes_applied', 'Changes Applied'),
        ('dismissed', 'Dismissed'),
    ]

    id = models.UUIDField(primary_key=True, default=uuid.uuid4, editable=False)
    user = models.ForeignKey(settings.AUTH_USER_MODEL, on_delete=models.CASCADE, related_name='uploaded_reports')

    # File information
    file = models.FileField(upload_to='uploaded_reports/%Y/%m/', null=False)
    file_name = models.CharField(max_length=255)
    file_type = models.CharField(max_length=50, blank=True)  # pdf, jpg, png, etc.
    file_size = models.IntegerField(blank=True, null=True)  # Size in bytes

    # Extracted text and structured data
    extracted_text = models.TextField(blank=True, null=True, help_text="Raw text extracted from document")

    # Structured extracted data
    biomarkers = models.JSONField(default=dict, blank=True, help_text="Extracted biomarkers and lab values")
    doctor_notes = models.TextField(blank=True, null=True, help_text="Doctor's notes and recommendations")
    diagnoses = models.JSONField(default=list, blank=True, help_text="List of diagnoses from report")

    # Medication recommendations
    medication_recommendations = models.JSONField(default=list, blank=True, help_text="Extracted medication changes")

    # Historical data
    report_date = models.DateField(null=True, blank=True, help_text="Date of the medical report itself")
    provider_name = models.CharField(max_length=255, blank=True, null=True)
    facility_name = models.CharField(max_length=255, blank=True, null=True)

    # Status tracking
    status = models.CharField(max_length=20, choices=STATUS_CHOICES, default='pending_review')
    uploaded_at = models.DateTimeField(auto_now_add=True)
    reviewed_at = models.DateTimeField(null=True, blank=True)

    # AI processing
    is_processed = models.BooleanField(default=False)
    processing_error = models.TextField(blank=True, null=True)

    class Meta:
        ordering = ['-uploaded_at']
        indexes = [
            models.Index(fields=['user', 'status']),
            models.Index(fields=['user', '-uploaded_at']),
        ]

    def __str__(self):
        return f"{self.user.email} - {self.file_name} - {self.uploaded_at.strftime('%Y-%m-%d')}"


class MedicationRecommendation(models.Model):
    """
    Individual medication change recommendations extracted from medical reports
    Tracks application status and user actions
    """
    CHANGE_TYPE_CHOICES = [
        ('new', 'New Medication'),
        ('dosage_change', 'Dosage Change'),
        ('schedule_change', 'Schedule Change'),
        ('discontinue', 'Discontinue'),
        ('frequency_change', 'Frequency Change'),
    ]

    STATUS_CHOICES = [
        ('pending', 'Pending'),
        ('applied', 'Applied'),
        ('dismissed', 'Dismissed'),
        ('failed', 'Failed to Apply'),
    ]

    id = models.UUIDField(primary_key=True, default=uuid.uuid4, editable=False)
    report = models.ForeignKey(UploadedMedicalReport, on_delete=models.CASCADE, related_name='recommendations')
    user = models.ForeignKey(settings.AUTH_USER_MODEL, on_delete=models.CASCADE, related_name='medication_recommendations')

    # Medication information
    medication_name = models.CharField(max_length=255, db_index=True)
    brand_name = models.CharField(max_length=255, blank=True, null=True)

    # Change details
    change_type = models.CharField(max_length=20, choices=CHANGE_TYPE_CHOICES)
    old_value = models.JSONField(null=True, blank=True, help_text="Previous medication details")
    new_value = models.JSONField(help_text="New medication details (dosage, frequency, schedule, etc.)")

    # Doctor's reasoning
    reason = models.TextField(blank=True, null=True, help_text="Doctor's reason for the change")
    clinical_notes = models.TextField(blank=True, null=True)

    # Status tracking
    status = models.CharField(max_length=20, choices=STATUS_CHOICES, default='pending')
    created_at = models.DateTimeField(auto_now_add=True)
    applied_at = models.DateTimeField(null=True, blank=True)
    dismissed_at = models.DateTimeField(null=True, blank=True)
    dismissal_reason = models.TextField(blank=True, null=True)

    # Link to medicine if applied
    applied_medicine = models.ForeignKey('medicines.Medicine', null=True, blank=True, on_delete=models.SET_NULL, related_name='source_recommendation')

    # Priority and urgency
    is_urgent = models.BooleanField(default=False)
    priority = models.IntegerField(default=0, help_text="Higher number = higher priority")

    class Meta:
        ordering = ['-priority', '-created_at']
        indexes = [
            models.Index(fields=['user', 'status']),
            models.Index(fields=['report', 'status']),
            models.Index(fields=['-priority', '-created_at']),
        ]

    def __str__(self):
        return f"{self.medication_name} - {self.change_type} - {self.status}"

    @property
    def is_pending(self):
        return self.status == 'pending'

    def mark_as_applied(self, medicine=None):
        """Mark this recommendation as applied"""
        self.status = 'applied'
        self.applied_at = timezone.now()
        if medicine:
            self.applied_medicine = medicine
        self.save()

    def dismiss(self, reason=None):
        """Dismiss this recommendation"""
        self.status = 'dismissed'
        self.dismissed_at = timezone.now()
        if reason:
            self.dismissal_reason = reason
        self.save()


class Biomarker(models.Model):
    """
    Track biomarkers and lab values from medical reports over time.
    Enhanced to handle multiple reports from different hospitals/facilities.
    """
    user = models.ForeignKey(settings.AUTH_USER_MODEL, on_delete=models.CASCADE, related_name='biomarkers')
    report = models.ForeignKey(UploadedMedicalReport, on_delete=models.SET_NULL, null=True, blank=True, related_name='extracted_biomarkers')

    # Biomarker details
    name = models.CharField(max_length=255, db_index=True, help_text="e.g., HbA1c, Cholesterol, Glucose")
    normalized_name = models.CharField(max_length=255, db_index=True, blank=True, null=True, help_text="Standardized biomarker name for matching")
    value = models.FloatField(help_text="Numeric value")
    unit = models.CharField(max_length=50, help_text="e.g., mg/dL, mmol/L, %")

    # Normalized value for cross-unit comparison
    normalized_value = models.FloatField(null=True, blank=True, help_text="Value converted to standard unit for comparison")
    normalized_unit = models.CharField(max_length=50, blank=True, null=True, help_text="Standard unit (SI or US based on user preference)")

    # Reference ranges
    reference_min = models.FloatField(null=True, blank=True)
    reference_max = models.FloatField(null=True, blank=True)
    is_normal = models.BooleanField(null=True, blank=True)

    # Status indicators
    flag = models.CharField(max_length=10, blank=True, null=True, help_text="H (high), L (low), N (normal)")

    # Source tracking - NEW: For multi-hospital support
    facility_name = models.CharField(max_length=255, blank=True, null=True, help_text="Hospital/lab facility name")
    provider_name = models.CharField(max_length=255, blank=True, null=True, help_text="Doctor/provider name")
    laboratory_name = models.CharField(max_length=255, blank=True, null=True, help_text="Lab where test was performed")

    # Context
    test_date = models.DateField(help_text="Date when the test was performed")
    test_time = models.TimeField(null=True, blank=True, help_text="Time when test was performed (if available)")
    notes = models.TextField(blank=True, null=True)

    # Data quality indicators - NEW
    extraction_confidence = models.FloatField(default=1.0, help_text="Confidence score from AI extraction (0-1)")
    is_manually_entered = models.BooleanField(default=False, help_text="True if entered manually by user")
    is_primary = models.BooleanField(default=True, help_text="Primary reading when multiple exist for same date")
    has_conflict = models.BooleanField(default=False, help_text="True if conflicting values exist for same test/date")
    conflict_note = models.TextField(blank=True, null=True, help_text="Details about conflicting values")

    # Validation status - NEW
    is_validated = models.BooleanField(default=False, help_text="True if value has been validated against expected ranges")
    validation_warning = models.TextField(blank=True, null=True, help_text="Warning message if value seems unusual")

    created_at = models.DateTimeField(auto_now_add=True)
    updated_at = models.DateTimeField(auto_now=True)

    class Meta:
        ordering = ['user', 'name', '-test_date']
        indexes = [
            models.Index(fields=['user', 'name', '-test_date']),
            models.Index(fields=['user', 'normalized_name', '-test_date']),
            models.Index(fields=['user', 'facility_name']),
            models.Index(fields=['user', '-test_date']),
        ]
        # Prevent exact duplicates but allow same test from different facilities
        constraints = [
            models.UniqueConstraint(
                fields=['user', 'name', 'test_date', 'facility_name'],
                name='unique_biomarker_per_facility_date'
            )
        ]

    def __str__(self):
        facility = f" @ {self.facility_name}" if self.facility_name else ""
        return f"{self.user.email} - {self.name}: {self.value} {self.unit} ({self.test_date}){facility}"

    @property
    def is_out_of_range(self):
        """Check if value is outside reference range"""
        if self.reference_min is not None and self.value < self.reference_min:
            return True
        if self.reference_max is not None and self.value > self.reference_max:
            return True
        return False

    def save(self, *args, **kwargs):
        """Auto-populate normalized name and validate on save"""
        from .biomarker_service import BiomarkerService

        # Set normalized name for consistent matching
        if not self.normalized_name:
            self.normalized_name = BiomarkerService.normalize_biomarker_name(self.name)

        # Validate value against expected ranges
        if not self.is_validated:
            warning = BiomarkerService.validate_biomarker_value(self.name, self.value, self.unit)
            if warning:
                self.validation_warning = warning
            self.is_validated = True

        super().save(*args, **kwargs)


class HealthInsight(models.Model):
    """
    AI-generated health insights based on biomarker data.
    Generated automatically when lab reports are uploaded.
    Includes user-specific analysis and research references.
    """
    SEVERITY_CHOICES = [
        ('critical', 'Critical - Requires Immediate Attention'),
        ('warning', 'Warning - Needs Monitoring'),
        ('info', 'Informational'),
        ('success', 'Normal/Healthy'),
    ]

    URGENCY_CHOICES = [
        ('immediate', 'Immediate Action Required'),
        ('soon', 'Address Within Days'),
        ('routine', 'Discuss at Next Appointment'),
        ('none', 'No Action Needed'),
    ]

    INSIGHT_TYPE_CHOICES = [
        ('biomarker_analysis', 'Biomarker Analysis'),
        ('trend_analysis', 'Trend Analysis'),
        ('correlation', 'Correlation with Other Data'),
        ('medication_interaction', 'Medication Interaction'),
        ('lifestyle_recommendation', 'Lifestyle Recommendation'),
        ('research_finding', 'Research-Based Finding'),
    ]

    id = models.UUIDField(primary_key=True, default=uuid.uuid4, editable=False)
    user = models.ForeignKey(settings.AUTH_USER_MODEL, on_delete=models.CASCADE, related_name='health_insights')

    # Source tracking
    report = models.ForeignKey(UploadedMedicalReport, on_delete=models.CASCADE, null=True, blank=True, related_name='insights')
    biomarker = models.ForeignKey(Biomarker, on_delete=models.CASCADE, null=True, blank=True, related_name='insights')
    biomarker_name = models.CharField(max_length=255, db_index=True, help_text="Biomarker this insight relates to")

    # Insight content
    insight_type = models.CharField(max_length=30, choices=INSIGHT_TYPE_CHOICES, default='biomarker_analysis')
    title = models.CharField(max_length=500, help_text="Short, descriptive title")
    summary = models.TextField(help_text="Brief summary for display")
    detailed_analysis = models.TextField(help_text="Full AI-generated analysis")

    # User-specific context used
    user_context = models.JSONField(default=dict, help_text="User data considered: medications, other biomarkers, history")

    # Research references
    research_references = models.JSONField(default=list, help_text="List of research citations and sources")
    research_summary = models.TextField(blank=True, null=True, help_text="Summary of relevant research findings")

    # Biomarker data at time of insight
    biomarker_value = models.FloatField(null=True, blank=True)
    biomarker_unit = models.CharField(max_length=50, blank=True, null=True)
    reference_min = models.FloatField(null=True, blank=True)
    reference_max = models.FloatField(null=True, blank=True)
    status = models.CharField(max_length=20, blank=True, null=True, help_text="normal, high, low, critical_high, critical_low")
    deviation_percent = models.FloatField(null=True, blank=True, help_text="How far from normal range in %")

    # Trend data
    trend_direction = models.CharField(max_length=20, blank=True, null=True, help_text="improving, worsening, stable")
    trend_percentage = models.FloatField(null=True, blank=True)
    previous_value = models.FloatField(null=True, blank=True)

    # Severity and urgency
    severity = models.CharField(max_length=20, choices=SEVERITY_CHOICES, default='info')
    urgency = models.CharField(max_length=20, choices=URGENCY_CHOICES, default='routine')

    # Recommendations
    recommendations = models.JSONField(default=list, help_text="List of actionable recommendations")
    doctor_discussion_points = models.JSONField(default=list, help_text="Points to discuss with doctor")
    lifestyle_tips = models.JSONField(default=list, help_text="Lifestyle modifications")

    # Related data
    related_biomarkers = models.JSONField(default=list, help_text="Other biomarkers that correlate")
    related_medications = models.JSONField(default=list, help_text="Medications that may affect this")

    # Flags
    requires_doctor_visit = models.BooleanField(default=False)
    is_dismissed = models.BooleanField(default=False)
    dismissed_at = models.DateTimeField(null=True, blank=True)
    is_read = models.BooleanField(default=False)
    read_at = models.DateTimeField(null=True, blank=True)

    # Timestamps
    created_at = models.DateTimeField(auto_now_add=True)
    updated_at = models.DateTimeField(auto_now=True)

    # For re-generation tracking
    ai_model_used = models.CharField(max_length=50, default='gpt-4o-mini')
    generation_prompt_version = models.CharField(max_length=20, default='v1')

    class Meta:
        ordering = ['-created_at']
        indexes = [
            models.Index(fields=['user', '-created_at']),
            models.Index(fields=['user', 'biomarker_name', '-created_at']),
            models.Index(fields=['user', 'severity', '-created_at']),
            models.Index(fields=['user', 'is_dismissed', '-created_at']),
            models.Index(fields=['report', '-created_at']),
        ]

    def __str__(self):
        return f"{self.user.email} - {self.biomarker_name}: {self.title}"

    def mark_as_read(self):
        if not self.is_read:
            self.is_read = True
            self.read_at = timezone.now()
            self.save(update_fields=['is_read', 'read_at'])

    def dismiss(self):
        self.is_dismissed = True
        self.dismissed_at = timezone.now()
        self.save(update_fields=['is_dismissed', 'dismissed_at'])
