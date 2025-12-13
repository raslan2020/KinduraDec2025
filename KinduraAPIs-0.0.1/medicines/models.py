from django.db import models
from django.core.validators import MinValueValidator
from users.models import User
import json


class Medicine(models.Model):
    """
    Comprehensive Medicine model for managing user medications
    Aligned with Kindura MVP specifications
    """
    # User relationship
    user = models.ForeignKey(User, on_delete=models.CASCADE, related_name='medicines')
    profile_id = models.CharField(max_length=100, blank=True, null=True)

    # Basic medication info
    drug_name = models.CharField(max_length=200, db_index=True)
    brand_name = models.CharField(max_length=200, blank=True, null=True)
    form = models.CharField(max_length=50, choices=[
        ('tablet', 'Tablet'),
        ('capsule', 'Capsule'),
        ('liquid', 'Liquid'),
        ('injection', 'Injection'),
        ('patch', 'Patch'),
        ('inhaler', 'Inhaler'),
        ('cream', 'Cream'),
        ('drops', 'Drops'),
        ('other', 'Other'),
    ], default='tablet')

    strength = models.DecimalField(max_digits=10, decimal_places=2, default=0, validators=[MinValueValidator(0)])
    strength_unit = models.CharField(max_length=20, choices=[
        ('mg', 'mg'),
        ('mcg', 'mcg'),
        ('g', 'g'),
        ('ml', 'ml'),
        ('units', 'units'),
        ('percentage', '%'),
    ], default='mg')

    route = models.CharField(max_length=50, choices=[
        ('oral', 'Oral'),
        ('sublingual', 'Sublingual'),
        ('injection', 'Injection'),
        ('topical', 'Topical'),
        ('inhalation', 'Inhalation'),
        ('rectal', 'Rectal'),
        ('transdermal', 'Transdermal'),
        ('nasal', 'Nasal'),
        ('ophthalmic', 'Ophthalmic'),
        ('otic', 'Otic'),
    ], default='oral')

    # Instructions and usage
    instructions_text = models.TextField(blank=True, help_text="Detailed instructions for taking medication")
    take_with_food = models.BooleanField(null=True, blank=True, help_text="True=with food, False=empty stomach, None=doesn't matter")
    as_needed = models.BooleanField(default=False, help_text="PRN medication")

    # Missed dose handling policy
    missed_dose_action = models.CharField(max_length=50, choices=[
        ('skip_dose', 'Skip and take next dose at regular time'),
        ('take_asap', 'Take as soon as possible'),
        ('take_and_shift', 'Take now and shift next doses'),
        ('contact_doctor', 'Contact doctor for guidance'),
        ('no_policy', 'No specific policy set'),
    ], default='no_policy', help_text="Action to take when a dose is missed")

    # Schedule stored as JSON
    schedule = models.JSONField(default=dict, help_text="Schedule containing times and days")
    # Expected format: {"times": ["06:00", "14:00", "22:00"], "days": ["Mon", "Tue", "Wed", "Thu", "Fri", "Sat", "Sun"]}

    # Dates
    start_date = models.DateField(null=True, blank=True)
    end_date = models.DateField(null=True, blank=True)

    # Timezone for scheduling
    timezone = models.CharField(max_length=50, default='Asia/Riyadh')

    # Prescriber info
    prescriber = models.CharField(max_length=200, blank=True, null=True)
    prescription_number = models.CharField(max_length=100, blank=True, null=True)

    # Status and metadata
    is_active = models.BooleanField(default=True)
    created_at = models.DateTimeField(auto_now_add=True)
    updated_at = models.DateTimeField(auto_now=True)

    # Source of medication entry
    source = models.CharField(max_length=50, choices=[
        ('manual', 'Manual Entry'),
        ('prescription', 'From Prescription'),
        ('report', 'From Medical Report'),
        ('import', 'Imported'),
    ], default='manual')

    # Related document ID if extracted from report
    source_document_id = models.CharField(max_length=100, blank=True, null=True)

    def __str__(self):
        return f"{self.drug_name} {self.strength}{self.strength_unit} - {self.user.email}"

    @property
    def display_name(self):
        """Get display name with brand if available"""
        if self.brand_name:
            return f"{self.drug_name} ({self.brand_name})"
        return self.drug_name

    @property
    def strength_display(self):
        """Get formatted strength display"""
        if self.strength and self.strength > 0:
            return f"{self.strength} {self.strength_unit}"
        return ""

    class Meta:
        ordering = ['-created_at']
        indexes = [
            models.Index(fields=['user', 'is_active']),
            models.Index(fields=['drug_name']),
        ]


class MedicationEvent(models.Model):
    """
    Track medication dose events (taken, missed, skipped, etc.)
    """
    medication = models.ForeignKey(Medicine, on_delete=models.CASCADE, related_name='events')
    scheduled_at = models.DateTimeField(db_index=True)
    taken_at = models.DateTimeField(null=True, blank=True)

    STATUS_CHOICES = [
        ('scheduled', 'Scheduled'),
        ('taken', 'Taken'),
        ('late', 'Late'),
        ('missed', 'Missed'),
        ('skipped', 'Skipped'),
        ('snoozed', 'Snoozed'),
    ]
    status = models.CharField(max_length=20, choices=STATUS_CHOICES, default='scheduled')

    delay_minutes = models.IntegerField(null=True, blank=True, help_text="Minutes late if taken late")
    side_effect_note = models.TextField(blank=True, null=True, max_length=500)

    SOURCE_CHOICES = [
        ('patient', 'Patient'),
        ('caregiver', 'Caregiver'),
        ('auto', 'Automatic'),
        ('voice', 'Voice Command'),
    ]
    source = models.CharField(max_length=20, choices=SOURCE_CHOICES, default='patient')

    created_at = models.DateTimeField(auto_now_add=True)
    updated_at = models.DateTimeField(auto_now=True)

    def __str__(self):
        return f"{self.medication.drug_name} - {self.scheduled_at} - {self.status}"

    class Meta:
        ordering = ['-scheduled_at']
        indexes = [
            models.Index(fields=['medication', 'scheduled_at']),
            models.Index(fields=['status', 'scheduled_at']),
        ]


class MedicationAdherenceDaily(models.Model):
    """
    Daily adherence summary for reporting
    """
    user = models.ForeignKey(User, on_delete=models.CASCADE, related_name='adherence_records')
    date = models.DateField(db_index=True)

    on_time_doses = models.IntegerField(default=0)
    late_doses = models.IntegerField(default=0)
    missed_doses = models.IntegerField(default=0)
    total_doses = models.IntegerField(default=0)

    adherence_percentage = models.DecimalField(max_digits=5, decimal_places=2, default=0)

    created_at = models.DateTimeField(auto_now_add=True)
    updated_at = models.DateTimeField(auto_now=True)

    class Meta:
        unique_together = ['user', 'date']
        ordering = ['-date']
        indexes = [
            models.Index(fields=['user', 'date']),
        ]

    def calculate_adherence(self):
        """Calculate adherence percentage"""
        if self.total_doses > 0:
            self.adherence_percentage = ((self.on_time_doses + self.late_doses) / self.total_doses) * 100
        else:
            self.adherence_percentage = 0
        return self.adherence_percentage


class MedicationInteraction(models.Model):
    """
    Track potential drug interactions
    """
    user = models.ForeignKey(User, on_delete=models.CASCADE, related_name='medication_interactions')
    medication_1 = models.ForeignKey(Medicine, on_delete=models.CASCADE, related_name='interactions_as_first')
    medication_2 = models.ForeignKey(Medicine, on_delete=models.CASCADE, related_name='interactions_as_second')

    SEVERITY_CHOICES = [
        ('minor', 'Minor'),
        ('moderate', 'Moderate'),
        ('major', 'Major'),
        ('contraindicated', 'Contraindicated'),
    ]
    severity = models.CharField(max_length=20, choices=SEVERITY_CHOICES)

    description = models.TextField()
    clinical_significance = models.TextField(blank=True, null=True)
    management_strategy = models.TextField(blank=True, null=True)

    is_active = models.BooleanField(default=True)
    acknowledged_by_user = models.BooleanField(default=False)
    acknowledged_at = models.DateTimeField(null=True, blank=True)

    created_at = models.DateTimeField(auto_now_add=True)
    updated_at = models.DateTimeField(auto_now=True)

    class Meta:
        unique_together = ['medication_1', 'medication_2']
        ordering = ['-severity', '-created_at']


class MedicationReminder(models.Model):
    """
    Medication reminder settings
    """
    medication = models.OneToOneField(Medicine, on_delete=models.CASCADE, related_name='reminder_settings')

    reminder_enabled = models.BooleanField(default=True)
    reminder_minutes_before = models.IntegerField(default=0, help_text="Minutes before scheduled time to remind")

    # Escalation settings
    caregiver_escalation_enabled = models.BooleanField(default=False)
    escalation_delay_minutes = models.IntegerField(default=20, help_text="Minutes after missed dose to notify caregiver")

    # Snooze settings
    snooze_enabled = models.BooleanField(default=True)
    max_snooze_count = models.IntegerField(default=3)
    snooze_duration_minutes = models.IntegerField(default=10)

    # Sound settings
    sound_enabled = models.BooleanField(default=True)
    vibration_enabled = models.BooleanField(default=True)

    created_at = models.DateTimeField(auto_now_add=True)
    updated_at = models.DateTimeField(auto_now=True)

    def __str__(self):
        return f"Reminder settings for {self.medication.drug_name}"