import os
import django
from datetime import date

# Setup Django
os.environ.setdefault('DJANGO_SETTINGS_MODULE', 'sportsverse_project.settings')
django.setup()

from django.contrib.auth import get_user_model
from organizations.models import Organization, Batch, Enrollment
from accounts.models import AcademyAdminProfile, StudentProfile
from coaches.models import CoachProfile, CoachAssignment

User = get_user_model()

def create_users():
    org = Organization.objects.get(academy_name='Elite Tennis Academy')
    batch = Batch.objects.filter(organization=org).first()
    password = "abcd1234"
    
    new_creds = ["\n--- Avadhoot Special Users ---"]

    # 1. Academy Admin
    admin_user, created = User.objects.get_or_create(
        username='avadhoot_admin',
        defaults={
            'first_name': 'Avadhoot',
            'last_name': 'Admin',
            'email': 'avadhoot_admin@example.com',
            'user_type': 'ACADEMY_ADMIN'
        }
    )
    admin_user.set_password(password)
    admin_user.save()
    AcademyAdminProfile.objects.get_or_create(user=admin_user, organization=org)
    new_creds.append(f"Academy Admin: avadhoot_admin | {password}")

    # 2. Coach
    coach_user, created = User.objects.get_or_create(
        username='avadhoot_coach',
        defaults={
            'first_name': 'Avadhoot',
            'last_name': 'Coach',
            'email': 'avadhoot_coach@example.com',
            'user_type': 'COACH'
        }
    )
    coach_user.set_password(password)
    coach_user.save()
    coach_profile, _ = CoachProfile.objects.get_or_create(
        user=coach_user, 
        organization=org,
        defaults={'specialization': 'Tennis'}
    )
    if batch:
        CoachAssignment.objects.get_or_create(coach=coach_profile, branch=batch.branch, sport=batch.sport, batch=batch)
    new_creds.append(f"Coach: avadhoot_coach | {password}")

    # 3. Student
    student_user, created = User.objects.get_or_create(
        username='avadhoot_student',
        defaults={
            'first_name': 'Avadhoot',
            'last_name': 'Student',
            'email': 'avadhoot_student@example.com',
            'user_type': 'STUDENT'
        }
    )
    student_user.set_password(password)
    student_user.save()
    student_profile, _ = StudentProfile.objects.get_or_create(
        user=student_user,
        organization=org,
        defaults={
            'first_name': 'Avadhoot',
            'last_name': 'Student',
            'date_of_birth': date(2000, 1, 1)
        }
    )
    if batch:
        Enrollment.objects.get_or_create(
            student=student_profile,
            batch=batch,
            organization=org,
            defaults={'enrollment_type': 'DURATION_BASED', 'is_active': True}
        )
    new_creds.append(f"Student: avadhoot_student | {password}")

    # Update credentials.txt
    cred_file_path = os.path.join('..', 'credentials.txt')
    with open(cred_file_path, 'a') as f:
        f.write("\n" + "\n".join(new_creds))

    print("Successfully created Avadhoot users and updated credentials.txt")

if __name__ == "__main__":
    create_users()
