# backend/accounts/urls.py

from django.urls import path
from .views import student_payment_history
from . import views

urlpatterns = [
    path('', views.dummy_view),
    path('batch-financials/', views.BatchFinancialsSummaryView.as_view(), name='batch-financials-summary'),
    path('my-history/', student_payment_history, name='student-payment-history'),
]
