import os
import sys
import django
from datetime import timedelta, date, datetime
import random

# Setup Django environment
sys.path.append(os.path.dirname(os.path.abspath(__file__)))
os.environ.setdefault('DJANGO_SETTINGS_MODULE', 'sportsverse_project.settings')
django.setup()

from django.utils import timezone
from django.contrib.auth import get_user_model
from organizations.models import Organization, Sport, Branch, Batch, Enrollment, Attendance
from accounts.models import AcademyAdminProfile, StudentProfile
from coaches.models import CoachProfile, CoachAssignment
from payments.models import FeeTransaction, CoachSalaryTransaction, GeneralExpense

User = get_user_model()

# Path to store credentials
CREDENTIALS_PATH = os.path.abspath(os.path.join(os.path.dirname(__file__), '..', 'credentials.txt'))

def wipe_existing_data():
    print("Wiping existing data...")
    # Be careful with the order of deletion due to foreign key constraints
    Attendance.objects.all().delete()
    Enrollment.objects.all().delete()
    FeeTransaction.objects.all().delete()
    CoachSalaryTransaction.objects.all().delete()
    GeneralExpense.objects.all().delete()
    CoachAssignment.objects.all().delete()
    CoachProfile.objects.all().delete()
    StudentProfile.objects.all().delete()
    AcademyAdminProfile.objects.all().delete()
    Batch.objects.all().delete()
    Branch.objects.all().delete()
    Organization.objects.all().delete()
    Sport.objects.all().delete()
    # Delete users except superusers
    User.objects.filter(is_superuser=False).delete()
    print("Existing data wiped.")

def create_sports():
    print("Creating sports...")
    sports = ['Tennis', 'Cricket', 'Football', 'Basketball', 'Swimming']
    sport_objs = []
    for s in sports:
        sport_objs.append(Sport.objects.create(name=s, description=f"{s} training and coaching."))
    return sport_objs

def generate_dummy_data():
    wipe_existing_data()
    sports = create_sports()
    
    credentials = []
    credentials.append("=== SPORTSVERSE DUMMY CREDENTIALS ===\n")
    credentials.append("Note: Password for all generated users is: password123\n\n")

    password = "password123"

    print("Generating Organizations and Admins...")
    org_data = [
        {"name": "Elite Tennis Academy", "slug": "elite-tennis", "email": "admin@elitetennis.com"},
        {"name": "Pro Strikers Football", "slug": "pro-strikers", "email": "admin@prostrikers.com"},
        {"name": "All Stars Sports Club", "slug": "all-stars", "email": "admin@allstars.com"}
    ]

    organizations = []
    for o in org_data:
        org = Organization.objects.create(
            full_name=o['name'],
            academy_name=o['name'],
            email_address=o['email'],
            slug=o['slug'],
            mobile_number="9876543210",
            subscription_plan='PREMIUM',
            subscription_end_date=date.today() + timedelta(days=365)
        )
        # Assign some sports
        org.sports_offered.add(*random.sample(sports, k=random.randint(1, 3)))
        organizations.append(org)

        # Create Admin
        admin_user = User.objects.create_user(
            username=f"admin_{o['slug']}",
            email=o['email'],
            password=password,
            first_name="Admin",
            last_name=o['name'],
            user_type='ACADEMY_ADMIN'
        )
        AcademyAdminProfile.objects.create(user=admin_user, organization=org)
        credentials.append(f"Academy Admin ({o['name']}): Username: {admin_user.username} | Password: {password}")

    print("Generating Branches and Batches...")
    batches = []
    for org in organizations:
        for b_idx in range(1, 3):
            branch = Branch.objects.create(
                organization=org,
                name=f"{org.academy_name} Branch {b_idx}",
                address=f"{random.randint(10, 99)} Main St, City"
            )
            
            # Create batches for this branch
            for org_sport in org.sports_offered.all():
                for time_slot in ["Morning", "Evening"]:
                    batch = Batch.objects.create(
                        organization=org,
                        branch=branch,
                        sport=org_sport,
                        name=f"{time_slot} {org_sport.name} Squad",
                        max_students=20,
                        fee_per_session=random.choice([50.00, 100.00, 150.00]),
                        payment_policy='POST_PAID'
                    )
                    batches.append(batch)

    print("Generating Coaches...")
    coaches = []
    credentials.append("\n--- Coaches ---")
    for idx in range(1, 16):
        org = random.choice(organizations)
        user = User.objects.create_user(
            username=f"coach{idx}",
            email=f"coach{idx}@{org.slug}.com",
            password=password,
            first_name=f"CoachFirst{idx}",
            last_name=f"CoachLast{idx}",
            user_type='COACH'
        )
        coach = CoachProfile.objects.create(
            user=user,
            organization=org,
            phone_number=f"55500010{idx:02d}",
            specialization=random.choice(org.sports_offered.all()).name
        )
        coaches.append(coach)
        credentials.append(f"Coach: {user.username} | Org: {org.academy_name}")

        # Assign coach to 1-2 batches in their org
        org_batches = [b for b in batches if b.organization == org]
        if org_batches:
            assigned_batches = random.sample(org_batches, k=min(2, len(org_batches)))
            for b in assigned_batches:
                CoachAssignment.objects.get_or_create(coach=coach, branch=b.branch, sport=b.sport, batch=b)

    print("Generating Students, Enrollments, Attendance, and Financials...")
    credentials.append("\n--- Students (Sample) ---")
    
    end_date_ref = timezone.now().date()
    start_date_ref = end_date_ref - timedelta(days=90) # 3 months of history

    for idx in range(1, 101):
        org = random.choice(organizations)
        user = User.objects.create_user(
            username=f"student{idx}",
            email=f"student{idx}@{org.slug}.com",
            password=password,
            first_name=f"StudentFirst{idx}",
            last_name=f"StudentLast{idx}",
            user_type='STUDENT'
        )
        student = StudentProfile.objects.create(
            user=user,
            organization=org,
            first_name=user.first_name,
            last_name=user.last_name,
            email=user.email,
            date_of_birth=date(2005, 1, 1) + timedelta(days=random.randint(0, 3650)),
            parent_name=f"ParentOf{idx}"
        )
        
        if idx <= 5: # Just output a few students to the file
            credentials.append(f"Student: {user.username} | Org: {org.academy_name}")

        # Enroll in a random batch in their org
        org_batches = [b for b in batches if b.organization == org]
        if not org_batches: continue
        
        batch = random.choice(org_batches)
        enrollment = Enrollment.objects.create(
            student=student,
            batch=batch,
            organization=org,
            enrollment_type='DURATION_BASED',
            start_date=start_date_ref,
            end_date=start_date_ref + timedelta(days=180),
            is_active=True,
            enrollment_started=True,
            date_first_attendance=timezone.now() - timedelta(days=80)
        )

        # Generate Attendance and Fees
        current_date = start_date_ref
        while current_date <= end_date_ref:
            # 30% chance of attending on a given day to spread it out realistically
            if random.random() < 0.3:
                Attendance.objects.create(
                    enrollment=enrollment,
                    batch=batch,
                    student=student,
                    organization=org,
                    date=current_date,
                    is_session_deducted=True
                )
                
                # Fee transaction
                if batch.fee_per_session:
                    is_paid = random.random() > 0.2 # 80% chance paid
                    FeeTransaction.objects.create(
                        organization=org,
                        student=student,
                        enrollment=enrollment,
                        amount=batch.fee_per_session,
                        transaction_date=current_date,
                        due_date=current_date + timedelta(days=7),
                        is_paid=is_paid,
                        payment_method=random.choice(['cash', 'upi', 'card']),
                        paid_date=timezone.now() if is_paid else None
                    )
            current_date += timedelta(days=1)

    print("Generating Expenses and Salaries...")
    for org in organizations:
        for _ in range(5):
            GeneralExpense.objects.create(
                organization=org,
                title=random.choice(["Rent", "Electricity", "Equipment", "Maintenance"]),
                amount=random.uniform(500, 5000),
                date=start_date_ref + timedelta(days=random.randint(0, 90)),
                category="Operations"
            )
        
        org_coaches = CoachProfile.objects.filter(organization=org)
        for coach in org_coaches:
            for month_offset in range(3):
                CoachSalaryTransaction.objects.create(
                    organization=org,
                    coach=coach,
                    amount=random.uniform(2000, 5000),
                    payment_period=f"Month {-month_offset}",
                    is_paid=True
                )

    # Write credentials
    print(f"Writing credentials to {CREDENTIALS_PATH}...")
    with open(CREDENTIALS_PATH, 'w') as f:
        f.write("\n".join(credentials))
        
    print("Done! Dummy data generation complete.")

if __name__ == "__main__":
    generate_dummy_data()
