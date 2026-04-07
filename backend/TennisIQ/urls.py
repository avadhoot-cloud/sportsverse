from django.urls import path, include
from .views import health_check

urlpatterns = [
    path('admin/', admin.site.urls),
    path('api/auth/', include('users.urls')),
    path('api/sessions/', include('sessions_log.urls')),
    path('api/analytics/', include('analytics.urls')),
    path('api/video/', include('analytics.video_urls')),
    path('api/coach/', include('analytics.coach_urls')),
    path('api/fusion/', include('fusion.urls')),
    path('api/health/', health_check, name='health_check'),
]
