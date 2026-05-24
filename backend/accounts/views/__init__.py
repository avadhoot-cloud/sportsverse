# accounts/views/__init__.py
#
# Re-exports all view symbols so that `accounts/urls.py` can still do:
#   from accounts.views import LoginView, ...
# without any changes to existing import paths.

from .auth_views import (
    MeView,
    RegisterAcademyView,
    LoginView,
    PasswordResetRequestView,
    PasswordResetConfirmView,
    ChangePasswordView,
)

from .profile_views import (
    StudentProfileUpdateView,
    StudentProfilePhotoUploadView,
    StudentProfileDebugView,
    StudentFaceEncodingView,
)

from .admin_views import (
    dashboard_stats,
    BatchFinancialsSummaryView,
    CollectStudentFeeView,
    StudentListView,
    StudentFinancialsView,
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
    TrainFaceRecognitionModelView,
    FaceRecognitionAttendanceView,
)

from .coach_views import CoachDashboardView, CoachStudentListView, CoachAttendanceView

__all__ = [
    # Auth
    'MeView',
    'RegisterAcademyView',
    'LoginView',
    'PasswordResetRequestView',
    'PasswordResetConfirmView',
    'ChangePasswordView',
    # Profile
    'StudentProfileUpdateView',
    'StudentProfilePhotoUploadView',
    'StudentProfileDebugView',
    'StudentFaceEncodingView',
    # Admin
    'dashboard_stats',
    'BatchFinancialsSummaryView',
    'CollectStudentFeeView',
    'StudentListView',
    'StudentFinancialsView',
    'StudentDashboardView',
    'StudentAttendanceView',
    'StudentPaymentsView',
    'StudentPaymentSummaryView',
    'StudentEnrollmentsView',
    'StudentAttendanceSummaryView',
    'StudentStaffView',
    'StudentNotificationsView',
    'StudentEventsView',
    'StudentReportsListView',
    'TrainFaceRecognitionModelView',
    'FaceRecognitionAttendanceView',
    # Coach
    'CoachDashboardView',
    'CoachStudentListView',
    'CoachAttendanceView',
]
