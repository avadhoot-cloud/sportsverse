from django.urls import path, include
from rest_framework.routers import DefaultRouter
from .views import WatchMetricsViewSet, VideoMetricsViewSet, FusionMetricsViewSet, analytics_summary, analytics_progress

router = DefaultRouter()
router.register(r'watch', WatchMetricsViewSet, basename='watchmetrics')
router.register(r'video', VideoMetricsViewSet, basename='videometrics')
router.register(r'fusion', FusionMetricsViewSet, basename='fusionmetrics')

urlpatterns = [
    path('summary/', analytics_summary, name='analytics_summary'),
    path('progress/', analytics_progress, name='analytics_progress'),
    path('', include(router.urls)),
]
