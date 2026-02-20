# backend/academy_reports/models.py

from django.db import models

class PlayerReport(models.Model):
    title = models.CharField(max_length=255)
    report_file = models.FileField(upload_to='player_reports/')
    
    # Use lowercase strings for lazy loading if needed, 
    # but Ensure 'organizations' is the correct app name in settings.py
    branch = models.ForeignKey('organizations.Branch', on_delete=models.CASCADE)
    batch = models.ForeignKey('organizations.Batch', on_delete=models.CASCADE)
    
    # Check if your model is 'Student' or 'student' - Django is case-sensitive here
    students = models.ManyToManyField('accounts.StudentProfile', related_name='reports')
    
    uploaded_at = models.DateTimeField(auto_now_add=True)

    def __str__(self):
        return self.title