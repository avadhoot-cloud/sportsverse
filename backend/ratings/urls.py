"""
ratings/urls.py

URL routing for the DUPR internal rating system.
"""
from django.urls import path
from ratings.views import (
    MatchSubmitView,
    MatchVerificationView,
    PendingMatchesView,
    MatchHistoryView,
)

app_name = "ratings"

urlpatterns = [
    # New Match Lifecycle Flow
    path('matches/history/', MatchHistoryView.as_view(), name='match-history'),
    path('matches/pending/', PendingMatchesView.as_view(), name='pending-matches'),
    path('matches/', MatchSubmitView.as_view(), name='match-submit'),
    path('matches/<int:pk>/verify/', MatchVerificationView.as_view(), name='match-verify'),
    
    # Existing legacy views comment out for now or we would put StudentRatingsView etc back
]
