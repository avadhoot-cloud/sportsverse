# sportsverse/backend/accounts/urls.py

from django.urls import path

from .views import (
    # Auth
    RegisterAcademyView,
    LoginView,
    PasswordResetRequestView,
    PasswordResetConfirmView,
    ChangePasswordView,
    MeView,
    # Coach
    CoachDashboardView,
    CoachStudentListView,
    CoachAttendanceView,
    # Admin / financials
    BatchFinancialsSummaryView,
    CollectStudentFeeView,
    dashboard_stats,
    StudentListView,
    StudentFinancialsView,
    # Student self-serve
    StudentDashboardView,
    StudentAttendanceView,
    StudentPaymentsView,
    StudentPaymentSummaryView,
    StudentEnrollmentsView,
    StudentAttendanceSummaryView,
    StudentStaffView,
    StudentNotificationsView,
    StudentEventsView,
    StudentReportsListView,
    # Profile
    StudentProfileUpdateView,
    StudentProfilePhotoUploadView,
    StudentProfileDebugView,
    # Face recognition
    StudentFaceEncodingView,
    TrainFaceRecognitionModelView,
    FaceRecognitionAttendanceView,
)

urlpatterns = [
    # ── Auth ────────────────────────────────────────────────────────────────
    path('register-academy/', RegisterAcademyView.as_view(), name='register-academy'),
    path('login/', LoginView.as_view(), name='login'),
    path('me/', MeView.as_view(), name='me'),
    path('password-reset/', PasswordResetRequestView.as_view(), name='password-reset'),
    path('password-reset-confirm/', PasswordResetConfirmView.as_view(), name='password-reset-confirm'),
    path('change-password/', ChangePasswordView.as_view(), name='change-password'),

    # ── Coach ────────────────────────────────────────────────────────────────
    path('coach-dashboard/', CoachDashboardView.as_view(), name='coach-dashboard'),
    path('coach/students/', CoachStudentListView.as_view(), name='coach-students'),
    path('coach/attendance/', CoachAttendanceView.as_view(), name='coach-attendance'),

    # ── Admin ────────────────────────────────────────────────────────────────
    path('dashboard-stats/', dashboard_stats, name='dashboard-stats'),
    path('collect-fee/', CollectStudentFeeView.as_view(), name='collect-fee'),
    path('batch-financials/', BatchFinancialsSummaryView.as_view(), name='batch-financials'),

    # ── Student management (admin) ───────────────────────────────────────────
    path('students/', StudentListView.as_view(), name='student-list'),
    path('students/<int:student_id>/financials/', StudentFinancialsView.as_view(), name='student-financials'),

    # ── Student self-serve ───────────────────────────────────────────────────
    path('dashboard/', StudentDashboardView.as_view(), name='student-dashboard'),
    path('attendance/', StudentAttendanceView.as_view(), name='student-attendance'),
    path('payments/', StudentPaymentsView.as_view(), name='student-payments'),
    path('payments/summary/', StudentPaymentSummaryView.as_view(), name='student-payment-summary'),
    path('enrollments/', StudentEnrollmentsView.as_view(), name='student-enrollments'),
    path('attendance/summary/', StudentAttendanceSummaryView.as_view(), name='student-attendance-summary'),
    path('staff/', StudentStaffView.as_view(), name='student-staff'),
    path('notifications/', StudentNotificationsView.as_view(), name='student-notifications'),
    path('events/', StudentEventsView.as_view(), name='student-events'),
    path('reports/', StudentReportsListView.as_view(), name='student-reports'),

    # ── Profile ──────────────────────────────────────────────────────────────
    path('profile/', StudentProfileUpdateView.as_view(), name='student-profile'),
    path('profile/photo/', StudentProfilePhotoUploadView.as_view(), name='student-profile-photo'),
    path('profile/debug/', StudentProfileDebugView.as_view(), name='student-profile-debug'),

    # ── Face recognition ─────────────────────────────────────────────────────
    path('face-encoding/', StudentFaceEncodingView.as_view(), name='student-face-encoding'),
    path('train-face-model/', TrainFaceRecognitionModelView.as_view(), name='train-face-model'),
    path('face-attendance/', FaceRecognitionAttendanceView.as_view(), name='face-attendance'),
]