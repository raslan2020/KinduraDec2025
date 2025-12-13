from django.contrib import admin
from .models import (
    Medicine, MedicationEvent, MedicationAdherenceDaily,
    MedicationInteraction, MedicationReminder
)


@admin.register(Medicine)
class MedicineAdmin(admin.ModelAdmin):
    """
    Admin for Medicine model
    """
    list_display = ['drug_name', 'brand_name', 'strength_display', 'user', 'is_active', 'created_at']
    list_filter = ['is_active', 'form', 'route', 'as_needed', 'created_at']
    search_fields = ['drug_name', 'brand_name', 'prescriber', 'user__email']
    readonly_fields = ['created_at', 'updated_at', 'display_name', 'strength_display']
    ordering = ['-created_at']

    fieldsets = (
        ('Basic Information', {
            'fields': ('user', 'drug_name', 'brand_name', 'display_name')
        }),
        ('Medication Details', {
            'fields': ('form', 'strength', 'strength_unit', 'strength_display', 'route')
        }),
        ('Instructions', {
            'fields': ('instructions_text', 'take_with_food', 'as_needed')
        }),
        ('Schedule', {
            'fields': ('schedule', 'start_date', 'end_date', 'timezone')
        }),
        ('Prescriber', {
            'fields': ('prescriber', 'prescription_number', 'source', 'source_document_id')
        }),
        ('Status', {
            'fields': ('is_active',)
        }),
        ('Timestamps', {
            'fields': ('created_at', 'updated_at'),
            'classes': ('collapse',)
        }),
    )


@admin.register(MedicationEvent)
class MedicationEventAdmin(admin.ModelAdmin):
    """
    Admin for MedicationEvent model
    """
    list_display = ['medication', 'scheduled_at', 'status', 'taken_at', 'source']
    list_filter = ['status', 'source', 'scheduled_at']
    search_fields = ['medication__drug_name', 'side_effect_note']
    readonly_fields = ['created_at', 'updated_at']
    ordering = ['-scheduled_at']


@admin.register(MedicationAdherenceDaily)
class MedicationAdherenceDailyAdmin(admin.ModelAdmin):
    """
    Admin for MedicationAdherenceDaily model
    """
    list_display = ['user', 'date', 'adherence_percentage', 'on_time_doses', 'total_doses']
    list_filter = ['date']
    search_fields = ['user__email']
    readonly_fields = ['created_at', 'updated_at']
    ordering = ['-date']


@admin.register(MedicationInteraction)
class MedicationInteractionAdmin(admin.ModelAdmin):
    """
    Admin for MedicationInteraction model
    """
    list_display = ['medication_1', 'medication_2', 'severity', 'is_active', 'acknowledged_by_user']
    list_filter = ['severity', 'is_active', 'acknowledged_by_user']
    search_fields = ['medication_1__drug_name', 'medication_2__drug_name', 'description']
    readonly_fields = ['created_at', 'updated_at']
    ordering = ['-severity', '-created_at']


@admin.register(MedicationReminder)
class MedicationReminderAdmin(admin.ModelAdmin):
    """
    Admin for MedicationReminder model
    """
    list_display = ['medication', 'reminder_enabled', 'caregiver_escalation_enabled']
    list_filter = ['reminder_enabled', 'caregiver_escalation_enabled']
    search_fields = ['medication__drug_name']
    readonly_fields = ['created_at', 'updated_at']