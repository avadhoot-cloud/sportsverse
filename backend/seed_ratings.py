import os
import sys
import django
import random
from decimal import Decimal

# Setup Django environment
sys.path.append(os.path.dirname(os.path.abspath(__file__)))
os.environ.setdefault('DJANGO_SETTINGS_MODULE', 'sportsverse_project.settings')
django.setup()

from django.contrib.auth import get_user_model
from organizations.models import Organization, Sport
from accounts.models import StudentProfile
from ratings.models import PlayerRatingProfile

User = get_user_model()

def seed_ratings():
    print("Seeding Player Rating Profiles...")
    
    # Get all students
    students = StudentProfile.objects.select_related('user', 'organization')
    
    # Get a sport (default to Tennis or first available)
    sport = Sport.objects.filter(name='Tennis').first() or Sport.objects.first()
    
    if not sport:
        print("No sports found. Please run dummy data script first.")
        return

    count = 0
    for s in students:
        if not s.user:
            continue
            
        # Check if profile already exists
        profile, created = PlayerRatingProfile.objects.get_or_create(
            user=s.user,
            sport=sport,
            organization=s.organization,
            defaults={
                'dupr_rating_singles': Decimal(str(round(random.uniform(3.0, 5.5), 3))),
                'dupr_rating_doubles': Decimal(str(round(random.uniform(3.0, 5.5), 3))),
                'matches_played_singles': random.randint(5, 25),
                'matches_played_doubles': random.randint(5, 25),
                'reliability': Decimal(str(round(random.uniform(60, 95), 2))),
            }
        )
        if created:
            count += 1
            
    print(f"Created {count} new Player Rating Profiles for sport '{sport.name}'.")

if __name__ == "__main__":
    seed_ratings()
