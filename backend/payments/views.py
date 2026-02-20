from django.shortcuts import render
from django.http import HttpResponse
from rest_framework.views import APIView
from rest_framework.response import Response
from rest_framework.permissions import IsAuthenticated
from rest_framework import status
from django.shortcuts import get_object_or_404
from django.db.models import Sum
from rest_framework.decorators import api_view, permission_classes
from django.utils import timezone

from organizations.models import Batch, Branch, Sport, Enrollment
from accounts.models import StudentProfile
from .models import FeeTransaction
from .serializers import StudentFeeSerializer

@api_view(['GET'])
@permission_classes([IsAuthenticated])
def student_payment_history(request):
    try:
        # Link to the student profile via the authenticated user
        student_profile = request.user.studentprofile
        transactions = FeeTransaction.objects.filter(student=student_profile).order_by('-transaction_date')
        serializer = StudentFeeSerializer(transactions, many=True)
        return Response(serializer.data)
    except Exception:
        return Response({"error": "Student profile not found"}, status=404)

def dummy_view(request):
    return HttpResponse("Accounts app is working!")

class BatchFinancialsSummaryView(APIView):
    permission_classes = [IsAuthenticated]

    def get(self, request):
        branch_id = request.query_params.get('branch')
        sport_id = request.query_params.get('sport')
        batch_id = request.query_params.get('batch')

        if not (branch_id and sport_id and batch_id):
            return Response({'detail': 'branch, sport and batch are required'}, status=status.HTTP_400_BAD_REQUEST)

        batch = get_object_or_404(Batch, pk=batch_id)

        # Permission check
        if not hasattr(request.user, 'academy_admin_profile'):
            return Response({'detail': 'Permission denied'}, status=status.HTTP_403_FORBIDDEN)
        
        enrollments = Enrollment.objects.filter(batch=batch, is_active=True).select_related('student')

        students_data = []
        for enrollment in enrollments:
            student = enrollment.student

            # Calculate Sessions for display
            sessions_left = None
            total_sessions = None
            if enrollment.enrollment_type == 'SESSION_BASED':
                total_sessions = enrollment.total_sessions or 0
                sessions_left = max(0, total_sessions - (enrollment.sessions_attended or 0))

            # Count unpaid transactions
            unpaid_count = FeeTransaction.objects.filter(enrollment=enrollment, is_paid=False).count()

            # Payment history for this specific student/enrollment
            transactions = FeeTransaction.objects.filter(student=student, enrollment=enrollment).order_by('-transaction_date')
            payment_history = [
                {
                    'id': t.id,
                    'amount': float(t.amount),
                    'transaction_date': t.transaction_date.isoformat() if t.transaction_date else None,
                    'is_paid': t.is_paid,
                    'payment_method': t.payment_method,
                }
                for t in transactions
            ]

            students_data.append({
                'student_id': student.id,
                'enrollment_id': enrollment.id, # CRITICAL: Needed for the record payment button
                'first_name': student.first_name,
                'last_name': student.last_name,
                'sessions_left': sessions_left,
                'total_sessions': total_sessions,
                'unpaid_sessions': unpaid_count,
                'payment_history': payment_history,
                'policy': batch.payment_policy
            })

        return Response({
            'batch': {
                'id': batch.id,
                'name': batch.name,
                'payment_policy': batch.payment_policy,
                'fee_per_session': float(batch.fee_per_session or 0),
            },
            'students': students_data,
        })

class CollectStudentFeeView(APIView):
    permission_classes = [IsAuthenticated]

    def post(self, request):
        student_id = request.data.get('student_id')
        enrollment_id = request.data.get('enrollment_id')
        amount = request.data.get('amount')
        payment_method = request.data.get('payment_method', 'Cash')
        
        # 1. Look for an existing unpaid transaction record
# This must update the model in the payments folder
        transaction = FeeTransaction.objects.filter(
            student_id=student_id, 
            enrollment_id=enrollment_id
        ).last() # Get the latest due transaction
        if transaction:
            transaction.is_paid = True
            transaction.amount = amount
            transaction.payment_method = payment_method
            transaction.transaction_date = timezone.now()
            transaction.save()
        else:
            # 2. If no unpaid record exists, CREATE ONE (On-the-spot payment)
            enrollment = get_object_or_404(Enrollment, id=enrollment_id)
            transaction = FeeTransaction.objects.create(
                student_id=student_id,
                enrollment=enrollment,
                amount=amount,
                is_paid=True,
                payment_method=payment_method,
                transaction_date=timezone.now()
            )
        
        return Response({
            'status': 'success',
            'message': 'Payment recorded successfully',
            'transaction_id': transaction.id
        })