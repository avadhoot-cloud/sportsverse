# backend/payments/urls.py

from django.urls import path
from .views import student_payment_history,BatchFinancialsSummaryView,get_dashboard_analytics,add_general_expense,add_coach_salary,get_all_expenses,student_payment_dashboard
from . import views


urlpatterns = [
    # Student self-serve payment history
    path('my-history/', student_payment_history, name='student-payment-history'),
    path('batch-financials/', BatchFinancialsSummaryView.as_view()),
    path('collect-fee/', views.CollectStudentFeeView.as_view(), name='collect-fee'),
    path('dashboard/analytics/', get_dashboard_analytics),
    path('add-expense/', add_general_expense),
    path('student/payment-dashboard/', student_payment_dashboard),
path('add-salary/', add_coach_salary),
path('expenses/', get_all_expenses),
]
