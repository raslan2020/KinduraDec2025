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
