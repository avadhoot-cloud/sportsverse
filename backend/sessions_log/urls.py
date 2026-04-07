from django.urls import path, include
from rest_framework.routers import DefaultRouter
from .views import MatchSessionViewSet, StrokeEventViewSet, RallyEventViewSet, process_imu_window

router = DefaultRouter()
router.register(r'sessions', MatchSessionViewSet, basename='matchsession')
router.register(r'strokes', StrokeEventViewSet, basename='strokeevent')
router.register(r'rallies', RallyEventViewSet, basename='rallyevent')

urlpatterns = [
    path('process-imu/', process_imu_window, name='process_imu_window'),
    path('', include(router.urls)),
]
