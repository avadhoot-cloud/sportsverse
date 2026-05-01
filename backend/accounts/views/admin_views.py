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
            sessions_left = total_sessions = None
            if enrollment.enrollment_type == 'SESSION_BASED':
                total_sessions = enrollment.total_sessions or 0
                sessions_left = max(0, total_sessions - (enrollment.sessions_attended or 0))

            unpaid_count = FeeTransaction.objects.filter(enrollment=enrollment, is_paid=False).count()
            transactions = (
                FeeTransaction.objects
                .filter(student=student, enrollment=enrollment)
                .order_by('-transaction_date')
            )
            payment_history = [
                {
                    'id': t.pk,
                    'amount': float(t.amount),
                    'transaction_date': t.transaction_date.isoformat() if t.transaction_date else None,
                    'is_paid': t.is_paid,
                    'payment_method': t.payment_method,
                    'paid_date': t.paid_date.isoformat() if t.paid_date else None,
                }
                for t in transactions
            ]

            students_data.append(
                {
                    'student_id': student.pk,
                    'enrollment_id': enrollment.pk,
                    'first_name': student.first_name,
                    'last_name': student.last_name,
                    'sessions_left': sessions_left,
                    'total_sessions': total_sessions,
                    'unpaid_sessions': unpaid_count,
                    'payment_history': payment_history,
                    'policy': batch.payment_policy,
                }
            )

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

class StudentDashboardView(APIView):
    """GET /api/accounts/dashboard/ — student-specific dashboard (matches url pattern)."""
    permission_classes = [IsAuthenticated]

    def get(self, request):
        if request.user.user_type == 'ACADEMY_ADMIN':
            # Re-delegate to admin stats
            return dashboard_stats(request._request)

        if not hasattr(request.user, 'student_profile'):
            return Response({'error': 'Student profile required'}, status=status.HTTP_403_FORBIDDEN)

        student = request.user.student_profile
        
        # ─── Fetch Real DUPR Ratings ───
        from ratings.models import PlayerRatingProfile
        dupr_data = {
            "singles_rating": 4.000,
            "doubles_rating": 4.000,
            "matches_played_singles": 0,
            "matches_played_doubles": 0,
            "reliability": 50.00
        }
        
        # Grab the first available sport profile for this student (we can expand this later to support multi-sport tabs)
        from ratings.fairness import calculate_fairness_index
        rating_profile = PlayerRatingProfile.objects.filter(student=student).first()
        if rating_profile:
            fairness = calculate_fairness_index(rating_profile)
            dupr_data = {
                "singles_rating": float(rating_profile.dupr_rating_singles),
                "doubles_rating": float(rating_profile.dupr_rating_doubles),
                "matches_played_singles": rating_profile.matches_played_singles,
                "matches_played_doubles": rating_profile.matches_played_doubles,
                "reliability": float(rating_profile.reliability),
                "fairness": fairness
            }
        else:
            dupr_data["fairness"] = {
                "category": "Insufficient Data",
                "color": "gray",
                "avg_rating_diff": 0.0,
                "lower_rated_pct": 0.0,
                "blowout_pct": 0.0,
                "close_match_pct": 0.0
            }

        enrollments = (
            Enrollment.objects
            .filter(student=student, is_active=True)
            .select_related('batch', 'batch__sport', 'batch__branch')
            .prefetch_related('attendances', 'fee_transactions')
        )

        enrollment_data = []
        for enrollment in enrollments:
            attendance_records = enrollment.attendances.all().order_by('-date')
            sessions_attended = enrollment.sessions_attended or 0
            total_sessions = enrollment.total_sessions
            sessions_left = (
                max(0, total_sessions - sessions_attended) if total_sessions else None
            )

            fee_summary = {
                'paid': float(
                    enrollment.fee_transactions.filter(is_paid=True).aggregate(t=Sum('amount'))['t'] or 0
                ),
                'due': float(
                    enrollment.fee_transactions.filter(is_paid=False).aggregate(t=Sum('amount'))['t'] or 0
                ),
            }

            enrollment_data.append(
                {
                    'enrollment_id': enrollment.pk,
                    'batch_name': enrollment.batch.name,
                    'batch_id': enrollment.batch.pk,
                    'sport': enrollment.batch.sport.name,
                    'branch': enrollment.batch.branch.name,
                    'enrollment_type': enrollment.enrollment_type,
                    'start_date': enrollment.start_date.isoformat() if enrollment.start_date else None,
                    'end_date': enrollment.end_date.isoformat() if enrollment.end_date else None,
                    'sessions_attended': sessions_attended,
                    'total_sessions': total_sessions,
                    'sessions_left': sessions_left,
                    'attendance': [
                        {'date': a.date.isoformat(), 'present': True}
                        for a in attendance_records
                    ],
                    'fee_summary': fee_summary,
                }
            )

        return Response({'enrollments': enrollment_data, 'dupr': dupr_data})


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
        serializer = StudentFeeSerializer(txns, many=True)
        return Response(serializer.data)


class StudentPaymentSummaryView(APIView):
    permission_classes = [IsAuthenticated]

    def get(self, request):
        if not hasattr(request.user, 'student_profile'):
            return Response({'error': 'Access denied'}, status=status.HTTP_403_FORBIDDEN)
        student = request.user.student_profile
        paid = FeeTransaction.objects.filter(student=student, is_paid=True).aggregate(t=Sum('amount'))['t'] or 0
        due = FeeTransaction.objects.filter(student=student, is_paid=False).aggregate(t=Sum('amount'))['t'] or 0
        return Response({'total_paid': float(paid), 'total_due': float(due)})


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
