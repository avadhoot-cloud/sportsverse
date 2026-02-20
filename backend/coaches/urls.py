from django.urls import path
from .views import CoachEnrollmentView, CoachListView, CoachAssignmentView, BatchLookupView

urlpatterns = [
    path('enroll/', CoachEnrollmentView.as_view(), name='coach-enroll'),
    path('list/', CoachListView.as_view(), name='coach-list'),
    path('assign/', CoachAssignmentView.as_view(), name='coach-assign'),
path('batches-lookup/', BatchLookupView.as_view(), name='batch-lookup'),
]