from django.db import models
from organizations.models import Organization, Branch, Batch
from accounts.models import StudentProfile

class TrainingVideo(models.Model):
    organization = models.ForeignKey(Organization, on_delete=models.CASCADE)
    title = models.CharField(max_length=255)
    video_file = models.FileField(upload_to='training_videos/')
    
    # Target Filters
    branch = models.ForeignKey(Branch, on_delete=models.CASCADE, null=True, blank=True)
    batch = models.ForeignKey(Batch, on_delete=models.CASCADE, null=True, blank=True)
    
    # Many-to-Many for specific students
    # If empty, the entire batch sees it.
    target_students = models.ManyToManyField(StudentProfile, blank=True, related_name='assigned_videos')
    
    uploaded_at = models.DateTimeField(auto_now_add=True)

    def __str__(self):
        return f"{self.title} - {self.batch.name if self.batch else 'General'}"