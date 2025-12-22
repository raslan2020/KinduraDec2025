from django.contrib import admin
from .models import CourseMedicineSchedule, CourseDayTracking


@admin.register(CourseMedicineSchedule)
class CourseMedicineScheduleAdmin(admin.ModelAdmin):
    """
    Admin for CourseMedicineSchedule model
    """
    list_display = ['course', 'medicine', 'time', 'dosage', 'is_active', 'created_at']
    list_filter = ['is_active', 'time', 'created_at']
    search_fields = ['course__name', 'medicine__name', 'dosage']
    readonly_fields = ['created_at', 'updated_at']
    ordering = ['-created_at']
    
    fieldsets = (
        (None, {'fields': ('course', 'medicine', 'time', 'dosage')}),
        ('Status', {'fields': ('is_active',)}),
        ('Timestamps', {'fields': ('created_at', 'updated_at'), 'classes': ('collapse',)}),
    )


@admin.register(CourseDayTracking)
class CourseDayTrackingAdmin(admin.ModelAdmin):
    """
    Admin for CourseDayTracking model
    """
    list_display = ['course', 'medicine', 'date', 'time', 'taken', 'created_at']
    list_filter = ['taken', 'date', 'time', 'created_at']
    search_fields = ['course__name', 'medicine__name', 'summary']
    readonly_fields = ['created_at', 'updated_at']
    ordering = ['-date', '-time']
    
    fieldsets = (
        (None, {'fields': ('course', 'medicine', 'date', 'time', 'taken')}),
        ('Summary', {'fields': ('summary',)}),
        ('Timestamps', {'fields': ('created_at', 'updated_at'), 'classes': ('collapse',)}),
    )
