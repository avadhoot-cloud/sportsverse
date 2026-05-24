"""Shared helpers for batch financial summaries."""

from decimal import Decimal

from django.db.models import Sum

from payments.models import FeeTransaction


def build_student_financial_data(enrollment, student, batch):
    """Build per-student financial payload for batch financials API."""
    sessions_left = total_sessions = None
    if enrollment.enrollment_type == 'SESSION_BASED':
        total_sessions = enrollment.total_sessions or 0
        sessions_left = max(0, total_sessions - (enrollment.sessions_attended or 0))

    unpaid_count = FeeTransaction.objects.filter(
        enrollment=enrollment, is_paid=False
    ).count()
    transactions = (
        FeeTransaction.objects
        .filter(student=student, enrollment=enrollment)
        .order_by('-transaction_date')
    )
    total_fees_paid = (
        transactions.filter(is_paid=True).aggregate(total=Sum('amount'))['total']
        or Decimal('0')
    )

    is_defaulter = unpaid_count > 0
    if is_defaulter:
        display_status = f'Payment Due ({unpaid_count} unpaid)'
    elif enrollment.enrollment_type == 'SESSION_BASED' and sessions_left == 0:
        display_status = 'Sessions completed'
    else:
        display_status = 'Up to date'

    payment_history = [
        {
            'id': t.pk,
            'amount': float(t.amount),
            'transaction_date': t.transaction_date.isoformat() if t.transaction_date else None,
            'is_paid': t.is_paid,
            'payment_method': t.payment_method,
            'paid_date': t.paid_date.isoformat() if getattr(t, 'paid_date', None) else None,
        }
        for t in transactions
    ]

    return {
        'student_id': student.pk,
        'enrollment_id': enrollment.pk,
        'first_name': student.first_name,
        'last_name': student.last_name,
        'sessions_left': sessions_left,
        'total_sessions': total_sessions,
        'unpaid_sessions': unpaid_count,
        'total_fees_paid': float(total_fees_paid),
        'is_defaulter': is_defaulter,
        'display_status': display_status,
        'payment_history': payment_history,
        'policy': batch.payment_policy,
    }
