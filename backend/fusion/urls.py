from django.urls import path
from .views import analyze_fusion

urlpatterns = [
    path('analyze/', analyze_fusion, name='analyze_fusion'),
]
