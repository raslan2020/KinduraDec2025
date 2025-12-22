from django.db import models
from courses.models import Course
from medicines.models import Medicine
from users.models import User


class CourseMedicineSchedule(models.Model):
    """
    Schedule for medicines in a course
    """
    course = models.ForeignKey(Course, on_delete=models.CASCADE, related_name='medicine_schedules')
    medicine = models.ForeignKey(Medicine, on_delete=models.CASCADE, related_name='course_schedules')
    time = models.TimeField()
    dosage = models.CharField(max_length=100, help_text="e.g., 1 tablet, 2 capsules")
    created_at = models.DateTimeField(auto_now_add=True)
    updated_at = models.DateTimeField(auto_now=True)
    is_active = models.BooleanField(default=True)
    
    def __str__(self):
        return f"{self.course.name} - {self.medicine.name} at {self.time}"
    
    class Meta:
        unique_together = ['course', 'medicine', 'time']
        ordering = ['time']


class CourseDayTracking(models.Model):
    """
    Daily tracking of medicine intake
    """
    course = models.ForeignKey(Course, on_delete=models.CASCADE, related_name='day_tracking')
    medicine = models.ForeignKey(Medicine, on_delete=models.CASCADE, related_name='day_tracking')
    date = models.DateField()
    time = models.TimeField()
    taken = models.BooleanField(default=False)
    summary = models.TextField(blank=True, null=True, help_text="Notes about the day")
    created_at = models.DateTimeField(auto_now_add=True)
    updated_at = models.DateTimeField(auto_now=True)
    
    def __str__(self):
        return f"{self.course.name} - {self.medicine.name} on {self.date} at {self.time}"
    
    class Meta:
        unique_together = ['course', 'medicine', 'date', 'time']
        ordering = ['-date', 'time']
