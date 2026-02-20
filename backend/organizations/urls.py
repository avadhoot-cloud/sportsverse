# sportsverse/backend/organizations/urls.py

from django.urls import path
from .views import (
    SportListView, 
    BranchListCreateView, 
    BranchRetrieveUpdateDestroyView,
    BatchListCreateView,
    BatchRetrieveUpdateDestroyView,
    EnrollmentListCreateView,
    EnrollmentRetrieveUpdateDestroyView,
    StudentListCreateView,
    StudentRetrieveUpdateDestroyView,
    StudentEnrollmentCreateView,
    AttendanceListView,
    AttendanceRetrieveUpdateDestroyView,
BatchAttendanceSummaryView
)

urlpatterns = [
    # Sports endpoints (public access)
    path('sports/', SportListView.as_view(), name='sport-list'),
    
    # Branch management endpoints (Academy Admin only)
    path('branches/', BranchListCreateView.as_view(), name='branch-list-create'),
    path('branches/<int:pk>/', BranchRetrieveUpdateDestroyView.as_view(), name='branch-detail'),
    
    # Batch management endpoints (Academy Admin only)
    path('batches/', BatchListCreateView.as_view(), name='batch-list-create'),
    path('batches/<int:pk>/', BatchRetrieveUpdateDestroyView.as_view(), name='batch-detail'),
    
    # Student management endpoints (Academy Admin only)
    path('students/', StudentListCreateView.as_view(), name='student-list-create'),
    path('students/<int:pk>/', StudentRetrieveUpdateDestroyView.as_view(), name='student-detail'),
    
    # Enrollment management endpoints (Academy Admin only)
    path('enrollments/', EnrollmentListCreateView.as_view(), name='enrollment-list-create'),
    path('enrollments/<int:pk>/', EnrollmentRetrieveUpdateDestroyView.as_view(), name='enrollment-detail'),
    
    # Combined student + enrollment creation (Academy Admin only)
    path('student-enrollments/', StudentEnrollmentCreateView.as_view(), name='student-enrollment-create'),

    # Attendance reporting (Academy Admin only)
    path('attendance/', AttendanceListView.as_view(), name='attendance-list'),
    path('attendance/<int:pk>/', AttendanceRetrieveUpdateDestroyView.as_view(), name='attendance-detail'),
    path('batch-summary/', BatchAttendanceSummaryView.as_view(), name='batch-summary'),
]