from django.db import models
from users.models import User


class Course(models.Model):
    """
    Course model for managing user courses
    """
    user = models.ForeignKey(User, on_delete=models.CASCADE, related_name='courses')
    name = models.CharField(max_length=200)
    start_date = models.DateField()
    duration = models.PositiveIntegerField(help_text="Duration in days")
    patient_history = models.TextField(blank=True, null=True)
    current_situation = models.TextField(blank=True, null=True)
    doctor_instructions = models.TextField(blank=True, null=True)
    created_at = models.DateTimeField(auto_now_add=True)
    updated_at = models.DateTimeField(auto_now=True)
    is_active = models.BooleanField(default=True)
    
    def __str__(self):
        return f"{self.name} - {self.user.email}"
    
    class Meta:
        ordering = ['-created_at']
