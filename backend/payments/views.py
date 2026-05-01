from django.shortcuts import render
from django.http import HttpResponse
from rest_framework.views import APIView
from rest_framework.response import Response
from rest_framework.permissions import IsAuthenticated
from rest_framework import status
from django.shortcuts import get_object_or_404
from django.db.models import Sum
from django.db.models.functions import TruncMonth, TruncQuarter, TruncYear
from rest_framework.decorators import api_view, permission_classes
from django.utils import timezone
from django.db.models import F, Sum, Count  # Ensure 'F' is included here
from organizations.models import Batch, Branch, Sport, Enrollment
from accounts.models import StudentProfile
from .models import FeeTransaction, CoachSalaryTransaction, GeneralExpense
from .serializers import StudentFeeSerializer
from rest_framework.decorators import api_view, permission_classes
from rest_framework.permissions import IsAuthenticated
from rest_framework.response import Response
from django.http import HttpResponse
from .models import FeeTransaction
from .serializers import StudentFeeSerializer

@api_view(['GET'])
@permission_classes([IsAuthenticated])
def student_payment_history(request):
    try:
        student_profile = request.user.studentprofile
        transactions = FeeTransaction.objects.filter(
            student=student_profile
        ).order_by('-transaction_date')

        serializer = StudentFeeSerializer(transactions, many=True)
        return Response(serializer.data)

    except Exception:
        return Response({"error": "Student profile not found"}, status=404)


# 🔥 NEW: CREATE PAYMENT WITH PAYMENT METHOD
@api_view(['POST'])
@permission_classes([IsAuthenticated])
def create_fee_transaction(request):
    try:
        student_id = request.data.get('student_id')
        amount = request.data.get('amount')
        payment_method = request.data.get('payment_method', 'cash')
        enrollment_id = request.data.get('enrollment_id')

        transaction = FeeTransaction.objects.create(
            organization=request.user.organization,
            student_id=student_id,
            enrollment_id=enrollment_id,
            amount=amount,
            payment_method=payment_method,
            is_paid=True
        )

        return Response({
            "message": "Payment recorded successfully",
            "id": transaction.id
        })

    except Exception as e:
        return Response({"error": str(e)}, status=400)


def dummy_view(request):
    return HttpResponse("Accounts app is working!")

class BatchFinancialsSummaryView(APIView):
    permission_classes = [IsAuthenticated]

    def get(self, request):
        branch_id = request.query_params.get('branch', '').rstrip('/')
        sport_id = request.query_params.get('sport', '').rstrip('/')
        batch_id = request.query_params.get('batch', '').rstrip('/')

        if not (branch_id and sport_id and batch_id):
            return Response({'detail': 'branch, sport and batch are required'}, status=status.HTTP_400_BAD_REQUEST)

        batch = get_object_or_404(Batch, pk=batch_id)

        if not hasattr(request.user, 'academy_admin_profile'):
            return Response({'detail': 'Permission denied'}, status=status.HTTP_403_FORBIDDEN)
        
        enrollments = Enrollment.objects.filter(batch=batch, is_active=True).select_related('student')

        students_data = []
        for enrollment in enrollments:
            student = enrollment.student
            sessions_left = None
            total_sessions = None
            if enrollment.enrollment_type == 'SESSION_BASED':
                total_sessions = enrollment.total_sessions or 0
                sessions_left = max(0, total_sessions - (enrollment.sessions_attended or 0))

            unpaid_count = FeeTransaction.objects.filter(enrollment=enrollment, is_paid=False).count()
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
                'enrollment_id': enrollment.id,
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
        
        transaction = FeeTransaction.objects.filter(
            student_id=student_id, 
            enrollment_id=enrollment_id
        ).last()

        if transaction:
            transaction.is_paid = True
            transaction.amount = amount
            transaction.payment_method = payment_method
            transaction.transaction_date = timezone.now()
            transaction.save()
        else:
            enrollment = get_object_or_404(Enrollment, id=enrollment_id)
            transaction = FeeTransaction.objects.create(
                student_id=student_id,
                enrollment=enrollment,
                organization=enrollment.batch.branch.organization,
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
@api_view(['GET'])
@permission_classes([IsAuthenticated])
def get_dashboard_analytics(request):
    try:
        organization = request.user.academy_admin_profile.organization
    except Exception:
        return Response({"error": "Academy Admin profile not found"}, status=403)

    from django.utils import timezone
    from django.db.models import Sum, F
    from organizations.models import Branch

    current_year = timezone.now().year

    # =========================
    # 💰 INCOME
    # =========================
    income_qs = FeeTransaction.objects.filter(
        organization=organization,
        is_paid=True,
        transaction_date__year=current_year
    )

    total_income = income_qs.aggregate(total=Sum('amount'))['total'] or 0

    # =========================
    # 💸 EXPENSES
    # =========================
    salary_qs = CoachSalaryTransaction.objects.filter(
        organization=organization,
        transaction_date__year=current_year
    )

    general_qs = GeneralExpense.objects.filter(
        organization=organization,
        date__year=current_year
    )

    total_salary = salary_qs.aggregate(total=Sum('amount'))['total'] or 0
    total_general = general_qs.aggregate(total=Sum('amount'))['total'] or 0

    total_expense = float(total_salary) + float(total_general)
    total_profit = float(total_income) - total_expense

    # =========================
    # 📊 QUARTERLY
    # =========================
    quarters = {
        "Q1": (1, 3),
        "Q2": (4, 6),
        "Q3": (7, 9),
        "Q4": (10, 12),
    }

    quarterly = {}

    for q, (start, end) in quarters.items():
        income = income_qs.filter(
            transaction_date__month__gte=start,
            transaction_date__month__lte=end
        ).aggregate(total=Sum('amount'))['total'] or 0

        salary = salary_qs.filter(
            transaction_date__month__gte=start,
            transaction_date__month__lte=end
        ).aggregate(total=Sum('amount'))['total'] or 0

        expense = general_qs.filter(
            date__month__gte=start,
            date__month__lte=end
        ).aggregate(total=Sum('amount'))['total'] or 0

        quarterly[q] = {
            "income": float(income),
            "expense": float(salary + expense)
        }

    # =========================
    # 📈 MONTHLY
    # =========================
    monthly = []

    for month in range(1, 13):
        income = income_qs.filter(transaction_date__month=month).aggregate(total=Sum('amount'))['total'] or 0
        expense_salary = salary_qs.filter(transaction_date__month=month).aggregate(total=Sum('amount'))['total'] or 0
        expense_general = general_qs.filter(date__month=month).aggregate(total=Sum('amount'))['total'] or 0

        monthly.append({
            "month": month,
            "income": float(income),
            "expense": float(expense_salary + expense_general)
        })

    # =========================
    # 🧾 PAYMENT METHODS (FIXED)
    # =========================
    payment_methods = income_qs.values('payment_method').annotate(total=Sum('amount'))

    total_count = income_qs.count()
    online_count = income_qs.filter(payment_method__iexact='online').count()
    cash_count = income_qs.filter(payment_method__iexact='cash').count()

    online_percentage = (online_count / total_count * 100) if total_count > 0 else 0
    cash_percentage = (cash_count / total_count * 100) if total_count > 0 else 0

    # =========================
    # 🏢 BRANCH
    # =========================
    all_branches = Branch.objects.filter(organization=organization)

    branch_qs = income_qs.values(
        'enrollment__batch__branch'
    ).annotate(
        total=Sum('amount')
    )

    revenue_map = {
        item['enrollment__batch__branch']: float(item['total'])
        for item in branch_qs
    }

    branch_revenue = []
    for branch in all_branches:
        branch_revenue.append({
            "branch": branch.name,
            "total": revenue_map.get(branch.id, 0)
        })

    # =========================
    # 📦 BATCH
    # =========================
    batch_data = income_qs.values(
        name=F('enrollment__batch__name')
    ).annotate(total=Sum('amount'))

    # =========================
    # 🚀 FINAL RESPONSE (UPDATED)
    # =========================
    return Response({
        "summary": {
            "year": current_year,
            "total_income": float(total_income),
            "total_expense": total_expense,
            "total_profit": total_profit,
        },

        "quarterly": quarterly,

        "monthly": monthly,

        "online_percentage": online_percentage,
        "cash_percentage": cash_percentage,

        "branch": branch_revenue,

        "total_amount": float(total_income),
        "total_token_amount": float(total_income) * 0.1,

        "payment_methods": [
            {"method": item['payment_method'], "total": float(item['total'])}
            for item in payment_methods
        ],

        "branch_revenue": branch_revenue,

        "batch_revenue": [
            {"batch": item['name'] or "General", "total": float(item['total'])}
            for item in batch_data
        ]
    })

@api_view(['POST'])
@permission_classes([IsAuthenticated])
def add_general_expense(request):
    try:
        organization = request.user.academy_admin_profile.organization

        title = request.data.get('title')
        amount = request.data.get('amount')
        category = request.data.get('category', '')

        expense = GeneralExpense.objects.create(
            organization=organization,
            title=title,
            amount=amount,
            category=category
        )

        return Response({
            "message": "Expense added",
            "id": expense.id
        })

    except Exception as e:
        return Response({"error": str(e)}, status=400)
    
@api_view(['GET'])
@permission_classes([IsAuthenticated])
def get_all_expenses(request):
    org = request.user.academy_admin_profile.organization

    salaries = CoachSalaryTransaction.objects.filter(organization=org)
    general = GeneralExpense.objects.filter(organization=org)

    data = []

    for s in salaries:
        data.append({
            "type": "Salary",
            "title": f"Coach: {s.coach}",
            "amount": float(s.amount),
            "date": s.transaction_date
        })

    for g in general:
        data.append({
            "type": "Expense",
            "title": g.title,
            "amount": float(g.amount),
            "date": g.date
        })

    return Response(data)

@api_view(['POST'])
@permission_classes([IsAuthenticated])
def add_coach_salary(request):
    try:
        organization = request.user.academy_admin_profile.organization

        coach_id = request.data.get('coach_id')
        amount = request.data.get('amount')
        period = request.data.get('payment_period')

        salary = CoachSalaryTransaction.objects.create(
            organization=organization,
            coach_id=coach_id,
            amount=amount,
            payment_period=period,
            paid_by=request.user
        )

        return Response({
            "message": "Salary recorded",
            "id": salary.id
        })

    except Exception as e:
        return Response({"error": str(e)}, status=400)
    
@api_view(['GET'])
@permission_classes([IsAuthenticated])
def student_payment_dashboard(request):
    try:
        student = request.user.studentprofile

        enrollments = Enrollment.objects.filter(
            student=student,
            is_active=True
        ).select_related('batch')

        result = []

        for enroll in enrollments:
            batch = enroll.batch

            # 🔥 TOTAL SESSIONS
            total_sessions = enroll.total_sessions or 0

            # 🔥 PRICE PER SESSION
            fee_per_session = batch.fee_per_session or 0

            # 🔥 TOTAL AMOUNT
            total_amount = total_sessions * fee_per_session

            # 🔥 PAID AMOUNT
            paid_amount = FeeTransaction.objects.filter(
                enrollment=enroll,
                is_paid=True
            ).aggregate(total=Sum('amount'))['total'] or 0

            # 🔥 PENDING
            pending_amount = total_amount - paid_amount

            # 🔥 STATUS
            if paid_amount == total_amount:
                status = "Paid"
            elif paid_amount == 0:
                status = "Pending"
            else:
                status = "Partial"

            result.append({
                "enrollment_id": enroll.id,
                "batch_name": batch.name,
                "total_sessions": total_sessions,
                "fee_per_session": float(fee_per_session),
                "total_amount": float(total_amount),
                "paid_amount": float(paid_amount),
                "pending_amount": float(pending_amount),
                "status": status
            })

        return Response(result)

    except Exception as e:
        return Response({"error": str(e)}, status=400)