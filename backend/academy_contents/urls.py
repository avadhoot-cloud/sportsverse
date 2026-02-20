from django.urls import path, include
from rest_framework.routers import DefaultRouter
from .views import StudentVideoViewSet, VideoUploadViewSet # VideoUploadViewSet for Admin

router = DefaultRouter()
router.register(r'videos', VideoUploadViewSet, basename='admin-videos')
router.register(r'my-training', StudentVideoViewSet, basename='student-videos')

urlpatterns = [
    path('', include(router.urls)),
]