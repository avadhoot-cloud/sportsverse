from django.contrib.auth.models import AbstractUser
from django.db import models

class User(AbstractUser):
    HAND_CHOICES = (
        ('left', 'Left'),
        ('right', 'Right'),
    )
    
    SKILL_CHOICES = (
        ('beginner', 'Beginner'),
        ('intermediate', 'Intermediate'),
        ('advanced', 'Advanced'),
        ('pro', 'Pro'),
    )

    profile_photo = models.ImageField(upload_to='profile_photos/', blank=True, null=True)
    date_of_birth = models.DateField(blank=True, null=True)
    dominant_hand = models.CharField(max_length=10, choices=HAND_CHOICES, blank=True, null=True)
    skill_level = models.CharField(max_length=20, choices=SKILL_CHOICES, blank=True, null=True)

    def __str__(self):
        return f"{self.username} ({self.email})"
