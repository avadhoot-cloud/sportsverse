# accounts/views/admin_views.py — Academy admin dashboard, student management, financials

import logging
from datetime import datetime

from django.db.models import Sum, Q
from django.shortcuts import get_object_or_404
from django.utils import timezone
from rest_framework import status
from rest_framework.decorators import api_view, permission_classes
from rest_framework.permissions import IsAuthenticated
from rest_framework.response import Response
from rest_framework.views import APIView

from accounts.models import StudentProfile, AcademyAdminProfile
from accounts.serializers import StudentFinancialsSerializer, StudentListSerializer, StudentFeeSerializer
from coaches.models import CoachProfile
from organizations.models import Enrollment, Attendance, Batch, Branch, Sport
from payments.models import FeeTransaction
from payments.financial_helpers import build_student_financial_data

logger = logging.getLogger(__name__)


# ─── Dashboard ────────────────────────────────────────────────────────────────

@api_view(['GET'])
@permission_classes([IsAuthenticated])
def dashboard_stats(request):
    """GET /api/accounts/dashboard/ — academy admin summary counts."""
    try:
        if not hasattr(request.user, 'academy_admin_profile'):
            return Response({'error': 'Access denied. Academy admin required.'}, status=403)
        org = request.user.academy_admin_profile.organization
        return Response(
            {
                'total_students': StudentProfile.objects.filter(organization=org).count(),
                'total_coaches': CoachProfile.objects.filter(organization=org).count(),
                'total_branches': Branch.objects.filter(organization=org).count(),
                'total_batches': Batch.objects.filter(organization=org).count(),
            },
            status=200,
        )
    except Exception as exc:
        logger.error("dashboard_stats: unexpected error — %s", exc)
        return Response({'error': str(exc)}, status=500)


class BatchFinancialsSummaryView(APIView):
    """GET /api/accounts/batch-financials/ — per-student payment breakdown for a batch."""
    permission_classes = [IsAuthenticated]

    def get(self, request):
        branch_id = request.query_params.get('branch', '').rstrip('/')
        sport_id = request.query_params.get('sport', '').rstrip('/')
        batch_id = request.query_params.get('batch', '').rstrip('/')

        if not (branch_id and sport_id and batch_id):
            return Response(
                {'detail': 'branch, sport and batch query params are required'},
                status=status.HTTP_400_BAD_REQUEST,
            )

        if not hasattr(request.user, 'academy_admin_profile'):
            return Response({'detail': 'Permission denied'}, status=status.HTTP_403_FORBIDDEN)

        batch = get_object_or_404(Batch, pk=batch_id)
        enrollments = (
            Enrollment.objects
            .filter(batch=batch, is_active=True)
            .select_related('student')
            .prefetch_related('fee_transactions')
        )

        students_data = []
        for enrollment in enrollments:
            student = enrollment.student
            students_data.append(build_student_financial_data(enrollment, student, batch))

        return Response(
            {
                'batch': {
                    'id': batch.pk,
                    'name': batch.name,
                    'payment_policy': batch.payment_policy,
                    'fee_per_session': float(batch.fee_per_session or 0),
                },
                'students': students_data,
            }
        )


class CollectStudentFeeView(APIView):
    """POST /api/accounts/collect-fee/ — record a fee payment for a student."""
    permission_classes = [IsAuthenticated]

    def post(self, request):
        if not hasattr(request.user, 'academy_admin_profile'):
            return Response({'detail': 'Permission denied'}, status=status.HTTP_403_FORBIDDEN)

        student_id = request.data.get('student_id')
        enrollment_id = request.data.get('enrollment_id')
        amount = request.data.get('amount')
        payment_method = request.data.get('payment_method', 'Cash')

        transaction = (
            FeeTransaction.objects
            .filter(student_id=student_id, enrollment_id=enrollment_id, is_paid=False)
            .order_by('id')
            .first()
        )

        if transaction:
            transaction.is_paid = True
            transaction.amount = amount
            transaction.payment_method = payment_method
            transaction.transaction_date = timezone.now().date()
            transaction.paid_date = timezone.now()
            transaction.save()
            logger.info(
                "CollectStudentFeeView: updated FeeTransaction#%s for student_id=%s",
                transaction.pk, student_id,
            )
        else:
            enrollment = get_object_or_404(Enrollment, pk=enrollment_id)
            if enrollment.organization != request.user.academy_admin_profile.organization:
                return Response({'detail': 'Permission denied'}, status=status.HTTP_403_FORBIDDEN)
            transaction = FeeTransaction.objects.create(
                organization=enrollment.organization,
                student_id=student_id,
                enrollment=enrollment,
                amount=amount,
                is_paid=True,
                payment_method=payment_method,
                paid_date=timezone.now(),
            )
            logger.info(
                "CollectStudentFeeView: created FeeTransaction#%s for student_id=%s",
                transaction.pk, student_id,
            )

        return Response(
            {
                'status': 'success',
                'message': 'Payment recorded successfully',
                'transaction_id': transaction.pk,
            }
        )


# ─── Student list & financials ────────────────────────────────────────────────

class StudentListView(APIView):
    """GET /api/accounts/students/ — list all students for the logged-in admin's org."""
    permission_classes = [IsAuthenticated]

    def get(self, request):
        if not hasattr(request.user, 'academy_admin_profile'):
            return Response({'error': 'Access denied'}, status=status.HTTP_403_FORBIDDEN)
        
        org = request.user.academy_admin_profile.organization
        branch_id = request.query_params.get('branch')
        batch_id = request.query_params.get('batch')
        
        queryset = StudentProfile.objects.filter(organization=org).prefetch_related(
            'enrollments', 'enrollments__batch', 'enrollments__batch__branch'
        )
        
        if branch_id:
            queryset = queryset.filter(enrollments__batch__branch_id=branch_id, enrollments__is_active=True)
        if batch_id:
            queryset = queryset.filter(enrollments__batch_id=batch_id, enrollments__is_active=True)
            
        # Ensure we don't get duplicate students if they have multiple active enrollments (though unlikely in this UI flow)
        queryset = queryset.distinct()
        
        serializer = StudentListSerializer(queryset, many=True)
        return Response(serializer.data)


class StudentFinancialsView(APIView):
    """GET /api/accounts/students/<id>/financials/ — payment summary for one student."""
    permission_classes = [IsAuthenticated]

    def get(self, request, student_id):
        if not hasattr(request.user, 'academy_admin_profile'):
            return Response({'error': 'Access denied'}, status=status.HTTP_403_FORBIDDEN)
        student = get_object_or_404(StudentProfile, pk=student_id)
        paid = FeeTransaction.objects.filter(student=student, is_paid=True).aggregate(t=Sum('amount'))['t'] or 0
        due = FeeTransaction.objects.filter(student=student, is_paid=False).aggregate(t=Sum('amount'))['t'] or 0
        serializer = StudentFinancialsSerializer({'total_paid': paid, 'total_due': due})
        return Response(serializer.data)


# ─── Student dashboard (self-serve) ──────────────────────────────────────────

def _student_dupr_payload(student):
    """Build DUPR block for student dashboard responses."""
    from ratings.models import PlayerRatingProfile
    from ratings.fairness import calculate_fairness_index

    dupr_data = {
        'singles_rating': 4.000,
        'doubles_rating': 4.000,
        'matches_played_singles': 0,
        'matches_played_doubles': 0,
        'reliability': 50.00,
    }
    rating_profile = PlayerRatingProfile.objects.filter(
        user=student.user,
        organization=student.organization,
    ).first()
    if rating_profile:
        dupr_data = {
            'singles_rating': float(rating_profile.dupr_rating_singles),
            'doubles_rating': float(rating_profile.dupr_rating_doubles),
            'matches_played_singles': rating_profile.matches_played_singles,
            'matches_played_doubles': rating_profile.matches_played_doubles,
            'reliability': float(rating_profile.reliability),
            'fairness': calculate_fairness_index(rating_profile),
        }
    else:
        dupr_data['fairness'] = {
            'category': 'Insufficient Data',
            'color': 'gray',
            'avg_rating_diff': 0.0,
            'lower_rated_pct': 0.0,
            'blowout_pct': 0.0,
            'close_match_pct': 0.0,
        }
    return dupr_data


def _serialize_recent_attendance(student, limit=10):
    records = (
        Attendance.objects.filter(student=student)
        .select_related('batch', 'enrollment')
        .order_by('-date')[:limit]
    )
    return [
        {
            'id': a.pk,
            'status': 'present',
            'enrollment': a.enrollment_id,
            'batch': a.batch_id,
            'student': a.student_id,
            'organization': a.organization_id,
            'date': a.date.isoformat(),
            'is_present': True,
            'timestamp': a.timestamp.isoformat() if a.timestamp else timezone.now().isoformat(),
        }
        for a in records
    ]


class StudentDashboardView(APIView):
    """GET /api/student/dashboard/ — full student dashboard for Flutter."""
    permission_classes = [IsAuthenticated]

    def get(self, request):
        if request.user.user_type == 'ACADEMY_ADMIN':
            return dashboard_stats(request._request)

        if not hasattr(request.user, 'student_profile'):
            return Response({'error': 'Student profile required'}, status=status.HTTP_403_FORBIDDEN)

        from organizations.serializers import EnrollmentSerializer

        student = request.user.student_profile
        active = (
            Enrollment.objects.filter(student=student, is_active=True)
            .select_related('batch', 'batch__sport', 'batch__branch', 'organization')
        )
        inactive = (
            Enrollment.objects.filter(student=student, is_active=False)
            .select_related('batch', 'batch__sport', 'batch__branch', 'organization')
        )

        primary = active.first()
        sessions_completed = sum(e.sessions_attended or 0 for e in active)
        sessions_remaining = 0
        for e in active:
            if e.total_sessions:
                sessions_remaining += max(0, e.total_sessions - (e.sessions_attended or 0))

        return Response({
            'current_enrollment': primary.batch.name if primary else 'No Active Enrollment',
            'sessions_completed': sessions_completed,
            'sessions_remaining': sessions_remaining,
            'enrollment_cycle': (
                f"{primary.enrollment_type.replace('_', ' ').title()}"
                if primary else 'N/A'
            ),
            'branch_name': primary.batch.branch.name if primary else 'N/A',
            'current_enrollments': EnrollmentSerializer(active, many=True).data,
            'previous_enrollments': EnrollmentSerializer(inactive, many=True).data,
            'recent_attendance': _serialize_recent_attendance(student),
            'dupr': _student_dupr_payload(student),
            # Legacy key for older clients
            'enrollments': EnrollmentSerializer(active, many=True).data,
        })


class StudentAttendanceView(APIView):
    permission_classes = [IsAuthenticated]

    def get(self, request):
        if not hasattr(request.user, 'student_profile'):
            return Response({'error': 'Access denied'}, status=status.HTTP_403_FORBIDDEN)
        student = request.user.student_profile
        records = Attendance.objects.filter(student=student).order_by('-date')
        return Response(
            [
                {
                    'date': a.date.isoformat(),
                    'batch': a.batch.name,
                    'batch_id': a.batch.pk,
                }
                for a in records
            ]
        )


class StudentPaymentsView(APIView):
    permission_classes = [IsAuthenticated]

    def get(self, request):
        if not hasattr(request.user, 'student_profile'):
            return Response({'error': 'Access denied'}, status=status.HTTP_403_FORBIDDEN)
        student = request.user.student_profile
        txns = FeeTransaction.objects.filter(student=student).order_by('-transaction_date')
        data = []
        for t in txns:
            due = t.due_date or t.transaction_date
            data.append({
                'id': t.pk,
                'organization': t.organization_id,
                'student': t.student_id,
                'enrollment': t.enrollment_id or 0,
                'amount': float(t.amount),
                'due_date': due.isoformat() if due else None,
                'transaction_date': t.transaction_date.isoformat(),
                'paid_date': t.paid_date.isoformat() if t.paid_date else None,
                'is_paid': t.is_paid,
                'payment_method': t.payment_method,
                'receipt_number': t.receipt_number,
            })
        return Response(data)


class StudentPaymentSummaryView(APIView):
    permission_classes = [IsAuthenticated]

    def get(self, request):
        if not hasattr(request.user, 'student_profile'):
            return Response({'error': 'Access denied'}, status=status.HTTP_403_FORBIDDEN)
        student = request.user.student_profile
        paid = FeeTransaction.objects.filter(student=student, is_paid=True).aggregate(t=Sum('amount'))['t'] or 0
        due = FeeTransaction.objects.filter(student=student, is_paid=False).aggregate(t=Sum('amount'))['t'] or 0
        next_unpaid = (
            FeeTransaction.objects.filter(student=student, is_paid=False)
            .order_by('due_date', 'transaction_date')
            .first()
        )
        next_due_date = None
        if next_unpaid:
            d = next_unpaid.due_date or next_unpaid.transaction_date
            next_due_date = d.isoformat() if d else None
        return Response({
            'total_paid': float(paid),
            'total_due': float(due),
            'next_due_date': next_due_date,
        })


class StudentEnrollmentsView(APIView):
    permission_classes = [IsAuthenticated]

    def get(self, request):
        if not hasattr(request.user, 'student_profile'):
            return Response({'error': 'Access denied'}, status=status.HTTP_403_FORBIDDEN)
        from organizations.serializers import EnrollmentSerializer

        student = request.user.student_profile
        status_filter = request.query_params.get('status')
        qs = Enrollment.objects.filter(student=student).select_related(
            'batch', 'batch__sport', 'batch__branch', 'organization',
        )
        if status_filter == 'active':
            qs = qs.filter(is_active=True)
        elif status_filter == 'completed':
            qs = qs.filter(is_active=False)
        return Response(EnrollmentSerializer(qs, many=True).data)


class StudentAttendanceSummaryView(APIView):
    permission_classes = [IsAuthenticated]

    def get(self, request):
        if not hasattr(request.user, 'student_profile'):
            return Response({'error': 'Access denied'}, status=status.HTTP_403_FORBIDDEN)
        student = request.user.student_profile
        total = Attendance.objects.filter(student=student).count()
        enrollments = Enrollment.objects.filter(student=student, is_active=True)
        total_sessions = sum(e.total_sessions or 0 for e in enrollments) or total or 1
        attended = sum(e.sessions_attended or 0 for e in enrollments)
        pct = round((attended / total_sessions) * 100, 1) if total_sessions else 0
        return Response({
            'total_records': total,
            'sessions_attended': attended,
            'total_sessions': total_sessions,
            'attendance_percentage': pct,
        })


class StudentStaffView(APIView):
    permission_classes = [IsAuthenticated]

    def get(self, request):
        if not hasattr(request.user, 'student_profile'):
            return Response({'error': 'Access denied'}, status=status.HTTP_403_FORBIDDEN)
        from coaches.models import CoachAssignment

        student = request.user.student_profile
        batch_ids = Enrollment.objects.filter(
            student=student, is_active=True,
        ).values_list('batch_id', flat=True)
        assignments = CoachAssignment.objects.filter(
            batch_id__in=batch_ids,
        ).select_related('coach', 'coach__user', 'batch', 'branch')
        staff = []
        seen = set()
        for a in assignments:
            if a.coach_id in seen:
                continue
            seen.add(a.coach_id)
            u = a.coach.user
            staff.append({
                'id': a.coach_id,
                'full_name': f"{u.first_name} {u.last_name}".strip() or u.username,
                'role': 'Coach',
                'batch': a.batch.name,
                'branch': a.branch.name if a.branch else '',
            })
        return Response(staff)


class StudentNotificationsView(APIView):
    permission_classes = [IsAuthenticated]

    def get(self, request):
        if not hasattr(request.user, 'student_profile'):
            return Response({'error': 'Access denied'}, status=status.HTTP_403_FORBIDDEN)

        from communications.models import Notification
        from academy_contents.models import TrainingVideo
        from django.db.models import Count

        student = request.user.student_profile
        user = request.user
        items = []

        db_notes = Notification.objects.filter(
            organization=student.organization,
        ).filter(
            Q(recipients=user) | Q(sent_to_all_students=True),
        ).order_by('-sent_at')[:10]

        for n in db_notes:
            items.append({
                'icon': 'notifications',
                'title': n.subject,
                'body': n.message,
                'time': n.sent_at.isoformat(),
                'unread': True,
                'color': '#1B3D2F',
            })

        unpaid = FeeTransaction.objects.filter(student=student, is_paid=False).first()
        if unpaid:
            due = unpaid.due_date or unpaid.transaction_date
            items.append({
                'icon': 'payment',
                'title': 'Fee payment due',
                'body': f'You have ₹{unpaid.amount} pending. Due: {due}',
                'time': timezone.now().isoformat(),
                'unread': True,
                'color': '#D32F2F',
            })

        batch_ids = list(
            Enrollment.objects.filter(student=student, is_active=True).values_list('batch_id', flat=True),
        )
        recent_video = (
            TrainingVideo.objects.filter(
                Q(target_students=student) | Q(batch_id__in=batch_ids),
            )
            .annotate(n=Count('target_students'))
            .order_by('-uploaded_at')
            .first()
        )
        if recent_video:
            items.append({
                'icon': 'videocam',
                'title': 'New training video',
                'body': f'"{recent_video.title}" was added to your library.',
                'time': recent_video.uploaded_at.isoformat(),
                'unread': False,
                'color': '#7B1FA2',
            })

        return Response(items)


class StudentEventsView(APIView):
    permission_classes = [IsAuthenticated]

    def get(self, request):
        if not hasattr(request.user, 'student_profile'):
            return Response({'error': 'Access denied'}, status=status.HTTP_403_FORBIDDEN)

        from datetime import timedelta

        student = request.user.student_profile
        events = []
        enrollments = Enrollment.objects.filter(
            student=student, is_active=True,
        ).select_related('batch', 'batch__sport')

        for e in enrollments:
            schedule = e.batch.schedule_details or {}
            days = schedule.get('days', ['Mon', 'Wed', 'Fri'])
            start = schedule.get('start_time', '6:00 PM')
            events.append({
                'title': f'{e.batch.name} Training',
                'type': 'MATCH',
                'sport': e.batch.sport.name,
                'day': days[0] if days else '01',
                'month': 'ONGOING',
                'time': start,
                'venue': e.batch.branch.name if e.batch.branch else student.organization.academy_name,
            })

        # Upcoming academy events (seeded / static-friendly)
        base = timezone.localdate()
        events.extend([
            {
                'title': 'Inter-Batch Tournament',
                'type': 'TOURNAMENT',
                'sport': enrollments[0].batch.sport.name if enrollments else 'Tennis',
                'day': f'{(base + timedelta(days=14)).day:02d}',
                'month': (base + timedelta(days=14)).strftime('%b').upper(),
                'time': '9:00 AM',
                'venue': f'{student.organization.academy_name} Main Court',
            },
            {
                'title': 'Skills Assessment Day',
                'type': 'ASSESSMENT',
                'sport': enrollments[0].batch.sport.name if enrollments else 'Tennis',
                'day': f'{(base + timedelta(days=21)).day:02d}',
                'month': (base + timedelta(days=21)).strftime('%b').upper(),
                'time': '8:00 AM',
                'venue': student.organization.academy_name,
            },
        ])
        return Response(events)


class StudentReportsListView(APIView):
    permission_classes = [IsAuthenticated]

    def get(self, request):
        if not hasattr(request.user, 'student_profile'):
            return Response({'error': 'Access denied'}, status=status.HTTP_403_FORBIDDEN)

        from academy_reports.models import PlayerReport

        student = request.user.student_profile
        reports = PlayerReport.objects.filter(students=student).order_by('-uploaded_at')
        return Response([
            {
                'id': r.pk,
                'title': r.title,
                'batch_name': r.batch.name,
                'uploaded_at': r.uploaded_at.isoformat(),
                'file_url': r.report_file.url if r.report_file else None,
            }
            for r in reports
        ])


# ─── Face recognition (admin only) — thin wrappers, heavy logic in facial_recognition.py

class TrainFaceRecognitionModelView(APIView):
    permission_classes = [IsAuthenticated]

    def post(self, request):
        if request.user.user_type != 'ACADEMY_ADMIN':
            return Response({'error': 'Access denied. Academy admin required.'}, status=status.HTTP_403_FORBIDDEN)
        org = request.user.academy_admin_profile.organization
        try:
            from accounts.facial_recognition import train_model_for_organization
            success = train_model_for_organization(org)
            if success:
                logger.info("TrainFaceRecognitionModelView: model trained for org_id=%s", org.pk)
                return Response({'message': 'Face recognition model trained successfully', 'organization_id': org.pk})
            return Response({'error': 'Training failed. Ensure students have face encodings.'}, status=400)
        except Exception as exc:
            logger.error("TrainFaceRecognitionModelView: error — %s", exc, exc_info=True)
            return Response({'error': str(exc)}, status=400)


class FaceRecognitionAttendanceView(APIView):
    permission_classes = [IsAuthenticated]

    def post(self, request):
        if request.user.user_type != 'ACADEMY_ADMIN':
            return Response({'error': 'Access denied.'}, status=status.HTTP_403_FORBIDDEN)
        org = request.user.academy_admin_profile.organization
        try:
            if 'captured_image' not in request.FILES:
                return Response({'error': 'No captured image provided'}, status=status.HTTP_400_BAD_REQUEST)
            captured_image = request.FILES['captured_image']
            att_date = request.data.get('date')
            if not att_date:
                from datetime import date
                att_date = date.today().isoformat()

            from accounts.facial_recognition import recognize_student_from_image, train_model_for_organization
            student, confidence = recognize_student_from_image(captured_image.read(), org)

            if student is None:
                logger.info("FaceRecognitionAttendanceView: no face matched, attempting auto-train")
                try:
                    train_model_for_organization(org)
                    student, confidence = recognize_student_from_image(captured_image.read(), org)
                except Exception as train_exc:
                    logger.warning("FaceRecognitionAttendanceView: auto-train failed — %s", train_exc)
                if student is None:
                    return Response(
                        {
                            'recognized': False, 'confidence': 0.0,
                            'message': 'No student recognized. Please ensure the student has registered their face.',
                        }
                    )

            attendance_result = self._mark_attendance(student, att_date, request.user)
            if attendance_result:
                return Response(
                    {
                        'recognized': True,
                        'student': {'id': student.pk, 'first_name': student.first_name, 'last_name': student.last_name},
                        'confidence': confidence,
                        'attendance': attendance_result,
                        'message': f'Attendance marked for {student.first_name} {student.last_name}',
                    }
                )
            return Response(
                {
                    'recognized': True,
                    'student': {'id': student.pk, 'first_name': student.first_name, 'last_name': student.last_name},
                    'confidence': confidence,
                    'attendance': None,
                    'message': f'{student.first_name} {student.last_name} has no active enrollments.',
                }
            )
        except Exception as exc:
            logger.error("FaceRecognitionAttendanceView: error — %s", exc, exc_info=True)
            return Response({'error': str(exc)}, status=400)

    def _mark_attendance(self, student, att_date, marked_by):
        from organizations.models import Attendance, Enrollment
        enrollments = Enrollment.objects.filter(student=student, is_active=True)
        if not enrollments.exists():
            return None

        results = []
        for enrollment in enrollments:
            attendance, created = Attendance.objects.get_or_create(
                enrollment=enrollment,
                date=att_date,
                defaults={
                    'batch': enrollment.batch,
                    'student': student,
                    'organization': student.organization,
                    'marked_by': marked_by,
                    'is_session_deducted': False,
                },
            )
            if not created:
                attendance.marked_by = marked_by
                attendance.save()

            results.append(
                {
                    'enrollment_id': enrollment.pk,
                    'batch_name': enrollment.batch.name,
                    'attendance_id': attendance.pk,
                    'created': created,
                }
            )
        return results
