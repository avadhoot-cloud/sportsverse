from django.urls import path
from .video_views import upload_video, video_status

urlpatterns = [
    path('upload/', upload_video, name='video_upload'),
    path('status/<int:session_id>/', video_status, name='video_status'),
]
