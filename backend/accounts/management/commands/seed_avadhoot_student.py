"""
Seed rich demo data for avadhoot_student (password: abcd1234).
Run: python manage.py seed_avadhoot_student
"""
from datetime import date, timedelta
from decimal import Decimal

from django.core.management.base import BaseCommand
from django.contrib.auth import get_user_model
from django.utils import timezone

User = get_user_model()


class Command(BaseCommand):
    help = 'Seed dashboard data for avadhoot_student at Elite Tennis Academy'

    def handle(self, *args, **options):
        from organizations.models import Organization, Batch, Enrollment, Attendance, Sport
        from accounts.models import StudentProfile, AcademyAdminProfile
        from coaches.models import CoachProfile, CoachAssignment
        from payments.models import FeeTransaction
        from academy_contents.models import TrainingVideo
        from communications.models import Notification
        from academy_reports.models import PlayerReport
        from ratings.models import PlayerRatingProfile

        password = 'abcd1234'
        org = Organization.objects.filter(academy_name='Elite Tennis Academy').first()
        if not org:
            self.stderr.write('Elite Tennis Academy not found. Run seed_data first.')
            return

        batch = Batch.objects.filter(organization=org, is_active=True).first()
        sport = batch.sport if batch else Sport.objects.filter(name__icontains='tennis').first()
        enrollment = None

        student_user, _ = User.objects.get_or_create(
            username='avadhoot_student',
            defaults={
                'first_name': 'Avadhoot',
                'last_name': 'Student',
                'email': 'avadhoot_student@example.com',
                'user_type': 'STUDENT',
            },
        )
        student_user.set_password(password)
        student_user.save()

        student_profile, _ = StudentProfile.objects.get_or_create(
            user=student_user,
            organization=org,
            defaults={
                'first_name': 'Avadhoot',
                'last_name': 'Student',
                'email': 'avadhoot_student@example.com',
                'date_of_birth': date(2000, 1, 1),
                'phone_number': '9876543210',
            },
        )

        if batch:
            batch.schedule_details = {
                'days': ['Mon', 'Wed', 'Fri'],
                'start_time': '6:00 AM',
                'end_time': '8:00 AM',
            }
            batch.save(update_fields=['schedule_details'])

            enrollment, _ = Enrollment.objects.update_or_create(
                student=student_profile,
                batch=batch,
                organization=org,
                defaults={
                    'enrollment_type': 'SESSION_BASED',
                    'is_active': True,
                    'total_sessions': 20,
                    'sessions_attended': 12,
                    'enrollment_started': True,
                    'start_date': date.today() - timedelta(days=30),
                },
            )

            Attendance.objects.filter(enrollment=enrollment).delete()
            for i in range(12):
                att_date = date.today() - timedelta(days=i * 2)
                Attendance.objects.get_or_create(
                    enrollment=enrollment,
                    date=att_date,
                    defaults={
                        'batch': batch,
                        'student': student_profile,
                        'organization': org,
                    },
                )

        FeeTransaction.objects.filter(student=student_profile).delete()
        enr = enrollment
        FeeTransaction.objects.create(
            organization=org,
            student=student_profile,
            enrollment=enr,
            amount=Decimal('2500.00'),
            is_paid=True,
            payment_method='upi',
            transaction_date=date.today() - timedelta(days=20),
            paid_date=timezone.now() - timedelta(days=20),
            receipt_number='RCP-AVD-001',
        )
        FeeTransaction.objects.create(
            organization=org,
            student=student_profile,
            enrollment=enr,
            amount=Decimal('2500.00'),
            is_paid=True,
            payment_method='cash',
            transaction_date=date.today() - timedelta(days=5),
            paid_date=timezone.now() - timedelta(days=5),
            receipt_number='RCP-AVD-002',
        )
        FeeTransaction.objects.create(
            organization=org,
            student=student_profile,
            enrollment=enr,
            amount=Decimal('3000.00'),
            is_paid=False,
            payment_method='cash',
            transaction_date=date.today(),
            due_date=date.today() + timedelta(days=14),
        )

        if sport:
            PlayerRatingProfile.objects.update_or_create(
                user=student_user,
                sport=sport,
                organization=org,
                defaults={
                    'dupr_rating_singles': Decimal('4.250'),
                    'dupr_rating_doubles': Decimal('4.100'),
                    'matches_played_singles': 8,
                    'matches_played_doubles': 4,
                    'reliability': Decimal('72.50'),
                },
            )

        if batch:
            video, _ = TrainingVideo.objects.get_or_create(
                organization=org,
                title='Forehand Technique – Avadhoot Session',
                batch=batch,
                defaults={'branch': batch.branch},
            )
            video.target_students.add(student_profile)

            TrainingVideo.objects.get_or_create(
                organization=org,
                title='Morning Warm-up Routine',
                batch=batch,
                defaults={'branch': batch.branch},
            )

            if batch.branch:
                report, _ = PlayerReport.objects.get_or_create(
                    title='Monthly Performance – Avadhoot',
                    branch=batch.branch,
                    batch=batch,
                    defaults={},
                )
                report.students.add(student_profile)

        admin_user = User.objects.filter(username='avadhoot_admin').first()
        Notification.objects.get_or_create(
            organization=org,
            subject='Welcome to Elite Tennis Academy',
            defaults={
                'message': 'Your training schedule is now live. Check Events for upcoming sessions.',
                'sent_to_all_students': True,
                'sender': admin_user,
            },
        )
        Notification.objects.get_or_create(
            organization=org,
            subject='New training video added',
            defaults={
                'message': 'Coach uploaded "Forehand Technique" to your video library.',
                'sent_to_all_students': False,
                'sender': admin_user,
            },
        )
        note = Notification.objects.filter(
            organization=org, subject='New training video added',
        ).first()
        if note:
            note.recipients.add(student_user)

        self.stdout.write(self.style.SUCCESS(
            f'Seeded avadhoot_student | {password} — enrollments, fees, attendance, videos, DUPR, notifications',
        ))
