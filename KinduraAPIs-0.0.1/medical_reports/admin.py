from django.contrib import admin
from .models import (
    VitalSign, BloodTest, MedicalDocument, MedicalReport,
    UploadedMedicalReport, MedicationRecommendation, Biomarker
)

@admin.register(VitalSign)
class VitalSignAdmin(admin.ModelAdmin):
    list_display = ['user', 'type', 'value', 'systolic', 'diastolic', 'unit', 'recorded_at']
    list_filter = ['type', 'recorded_at', 'user']
    search_fields = ['user__username', 'notes']
    date_hierarchy = 'recorded_at'

@admin.register(BloodTest)
class BloodTestAdmin(admin.ModelAdmin):
    list_display = ['user', 'test_name', 'test_date']
    list_filter = ['test_date', 'user']
    search_fields = ['user__username', 'test_name', 'notes']
    date_hierarchy = 'test_date'

@admin.register(MedicalDocument)
class MedicalDocumentAdmin(admin.ModelAdmin):
    list_display = ['user', 'title', 'document_type', 'uploaded_at', 'is_parsed']
    list_filter = ['document_type', 'is_parsed', 'uploaded_at']
    search_fields = ['user__username', 'title', 'description']
    date_hierarchy = 'uploaded_at'

@admin.register(MedicalReport)
class MedicalReportAdmin(admin.ModelAdmin):
    list_display = ['user', 'last_updated']
    search_fields = ['user__username', 'summary']


@admin.register(UploadedMedicalReport)
class UploadedMedicalReportAdmin(admin.ModelAdmin):
    list_display = ['user', 'file_name', 'status', 'uploaded_at', 'is_processed']
    list_filter = ['status', 'is_processed', 'uploaded_at']
    search_fields = ['user__email', 'file_name', 'doctor_notes', 'provider_name']
    date_hierarchy = 'uploaded_at'
    readonly_fields = ['id', 'uploaded_at']


@admin.register(MedicationRecommendation)
class MedicationRecommendationAdmin(admin.ModelAdmin):
    list_display = ['medication_name', 'user', 'change_type', 'status', 'is_urgent', 'created_at']
    list_filter = ['status', 'change_type', 'is_urgent', 'created_at']
    search_fields = ['medication_name', 'brand_name', 'user__email', 'reason']
    date_hierarchy = 'created_at'
    readonly_fields = ['id', 'created_at']


@admin.register(Biomarker)
class BiomarkerAdmin(admin.ModelAdmin):
    list_display = ['user', 'name', 'value', 'unit', 'flag', 'test_date', 'is_out_of_range']
    list_filter = ['name', 'flag', 'test_date']
    search_fields = ['user__email', 'name', 'notes']
    date_hierarchy = 'test_date'
    readonly_fields = ['created_at', 'is_out_of_range']
