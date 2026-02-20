from django.db import models
from django.conf import settings
from organizations.models import Organization, Branch, Batch, Sport

class CoachProfile(models.Model):
    # Link to the authentication account
    user = models.OneToOneField(
        settings.AUTH_USER_MODEL, 
        on_delete=models.CASCADE, 
        related_name='coach_profile'
    )
    organization = models.ForeignKey(Organization, on_delete=models.CASCADE, related_name='coaches')
    
    # Independent Profile Fields
    phone_number = models.CharField(max_length=15)
    specialization = models.CharField(max_length=100, help_text="e.g. Tennis, Yoga, etc.")
    bio = models.TextField(blank=True)
    profile_photo = models.ImageField(upload_to='coach_profiles/', blank=True, null=True)
    is_active = models.BooleanField(default=True)

    def __str__(self):
        return f"Coach: {self.user.get_full_name}"

class CoachAssignment(models.Model):
    coach = models.ForeignKey(CoachProfile, on_delete=models.CASCADE, related_name='assignments')
    branch = models.ForeignKey(Branch, on_delete=models.CASCADE)
    sport = models.ForeignKey(Sport, on_delete=models.CASCADE)
    batch = models.ForeignKey(Batch, on_delete=models.CASCADE)
    date_assigned = models.DateTimeField(auto_now_add=True)

    class Meta:
        unique_together = ('coach', 'batch') # Prevent double assignment to same batch

    def __str__(self):
        return f"{self.coach.user.first_name} assigned to {self.batch.name}"