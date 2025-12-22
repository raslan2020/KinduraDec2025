from django.contrib import admin
from .models import (
    HealthProfile, LifestyleHabits, PhysicalActivity,
    DietaryHabits, MedicalHistory, MentalHealth, WatchVitals
)


class LifestyleHabitsInline(admin.StackedInline):
    model = LifestyleHabits
    extra = 0


class PhysicalActivityInline(admin.StackedInline):
    model = PhysicalActivity
    extra = 0


class DietaryHabitsInline(admin.StackedInline):
    model = DietaryHabits
    extra = 0


class MedicalHistoryInline(admin.StackedInline):
    model = MedicalHistory
    extra = 0


class MentalHealthInline(admin.StackedInline):
    model = MentalHealth
    extra = 0


@admin.register(HealthProfile)
class HealthProfileAdmin(admin.ModelAdmin):
    """
    Admin for HealthProfile model
    """
    list_display = ['user', 'created_at', 'updated_at']
    list_filter = ['created_at', 'updated_at']
    search_fields = ['user__email', 'user__first_name', 'user__last_name']
    readonly_fields = ['created_at', 'updated_at']
    ordering = ['-created_at']
    
    inlines = [
        LifestyleHabitsInline,
        PhysicalActivityInline,
        DietaryHabitsInline,
        MedicalHistoryInline,
        MentalHealthInline,
    ]


@admin.register(LifestyleHabits)
class LifestyleHabitsAdmin(admin.ModelAdmin):
    """
    Admin for LifestyleHabits model
    """
    list_display = ['health_profile', 'smoking', 'drink_alcohol', 'caffeine_intake']
    list_filter = ['smoking', 'drink_alcohol']


@admin.register(PhysicalActivity)
class PhysicalActivityAdmin(admin.ModelAdmin):
    """
    Admin for PhysicalActivity model
    """
    list_display = ['health_profile', 'exercise_frequency', 'exercise_type', 'average_duration']
    list_filter = ['exercise_frequency']


@admin.register(DietaryHabits)
class DietaryHabitsAdmin(admin.ModelAdmin):
    """
    Admin for DietaryHabits model
    """
    list_display = ['health_profile', 'diet_type', 'daily_water_intake']
    list_filter = ['diet_type']


@admin.register(MedicalHistory)
class MedicalHistoryAdmin(admin.ModelAdmin):
    """
    Admin for MedicalHistory model
    """
    list_display = ['health_profile', 'taking_medications', 'has_allergies']
    list_filter = ['taking_medications', 'has_allergies']


@admin.register(MentalHealth)
class MentalHealthAdmin(admin.ModelAdmin):
    """
    Admin for MentalHealth model
    """
    list_display = ['health_profile', 'experienced_anxiety_depression', 'seeing_therapist']
    list_filter = ['experienced_anxiety_depression', 'seeing_therapist']


@admin.register(WatchVitals)
class WatchVitalsAdmin(admin.ModelAdmin):
    """
    Admin for WatchVitals model
    """
    list_display = [
        'user', 'heart_rate', 'blood_oxygen', 'sleep_quality',
        'fall_detected', 'recorded_at'
    ]
    list_filter = ['sleep_quality', 'fall_detected', 'recorded_at']
    search_fields = ['user__email', 'user__first_name', 'user__last_name']
    ordering = ['-recorded_at']
