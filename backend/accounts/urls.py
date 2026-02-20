# sportsverse/backend/accounts/urls.py

from django.urls import path
from rest_framework.authtoken.views import obtain_auth_token

from .views import (
    RegisterAcademyView, 
    LoginView, 
    PasswordResetRequestView,
    PasswordResetConfirmView,
    ChangePasswordView,

    StudentFinancialsView,
    StudentListView,
    StudentDashboardView,
    StudentAttendanceView,
    StudentPaymentsView,
    StudentPaymentSummaryView,
    StudentProfileUpdateView,
    StudentProfilePhotoUploadView,
    StudentProfileDebugView,
    StudentFaceEncodingView,
    TrainFaceRecognitionModelView,
    FaceRecognitionAttendanceView,
    BatchFinancialsSummaryView,
    CollectStudentFeeView
)

urlpatterns = [
    path('register-academy/', RegisterAcademyView.as_view(), name='register-academy'),
    path('login/', LoginView.as_view(), name='login'),
    path('password-reset/', PasswordResetRequestView.as_view(), name='password-reset'),
    path('password-reset-confirm/', PasswordResetConfirmView.as_view(), name='password-reset-confirm'),
    path('change-password/', ChangePasswordView.as_view(), name='change-password'),
    path('collect-fee/', CollectStudentFeeView.as_view(), name='collect-fee'),
    # Coach management endpoints

    # Student endpoints
    path('students/', StudentListView.as_view(), name='student-list'),
    path('students/<int:student_id>/financials/', StudentFinancialsView.as_view(), name='student-financials'),
    
    # Student-specific endpoints (for student dashboard) - these will be accessed via /api/student/
    path('dashboard/', StudentDashboardView.as_view(), name='student-dashboard'),
    path('attendance/', StudentAttendanceView.as_view(), name='student-attendance'),
    path('payments/', StudentPaymentsView.as_view(), name='student-payments'),
    path('payments/summary/', StudentPaymentSummaryView.as_view(), name='student-payment-summary'),
    path('profile/', StudentProfileUpdateView.as_view(), name='student-profile'),
    path('profile/photo/', StudentProfilePhotoUploadView.as_view(), name='student-profile-photo'),
    path('profile/debug/', StudentProfileDebugView.as_view(), name='student-profile-debug'),
    path('face-encoding/', StudentFaceEncodingView.as_view(), name='student-face-encoding'),
    path('batch-financials/', BatchFinancialsSummaryView.as_view(), name='batch-financials'),
    # Academy admin facial recognition endpoints
    path('train-face-model/', TrainFaceRecognitionModelView.as_view(), name='train-face-model'),
    path('face-attendance/', FaceRecognitionAttendanceView.as_view(), name='face-attendance'),
]