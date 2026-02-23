"""
ratings/urls.py

URL routing for the DUPR internal rating system.
"""
from django.urls import path
from ratings.views import (
    StudentRatingsView,
    MatchSubmitView,
    MatchListView,
    ForecastView,
    PlayerAuditHistoryView,
)

app_name = "ratings"

urlpatterns = [
    path('students/', StudentRatingsView.as_view(), name='student-ratings'),
    path('matches/', MatchSubmitView.as_view(), name='match-submit'),
    path('matches/list/', MatchListView.as_view(), name='match-list'),
    path('forecast/', ForecastView.as_view(), name='forecast'),
    path('my-history/', PlayerAuditHistoryView.as_view(), name='my-history'),
]
