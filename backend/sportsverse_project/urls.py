from django.contrib import admin
from django.urls import path, include
from django.conf import settings
from django.conf.urls.static import static
from accounts.views import dashboard_stats # Add this import

urlpatterns = [
    path('admin/', admin.site.urls),
    # Include URLs from your custom apps
    path('api/accounts/', include('accounts.urls')),
    path('api/organizations/', include('organizations.urls')),
    path('api/accounts/dashboard-stats/', dashboard_stats, name='dashboard-stats'),
    path('api/communications/', include('communications.urls')),
    path('api/payments/', include('payments.urls')),
    path('api/content/', include('content.urls')),
path('api/coaches/', include('coaches.urls')),
    path('api/reports/', include('academy_reports.urls')),
    # Student-specific endpoints
    path('api/student/', include('accounts.urls')),
    path('api/academy-contents/', include('academy_contents.urls')),
]

# Serve media files in development. In production, a web server (Nginx/Apache) handles this.
if settings.DEBUG:
    urlpatterns += static(settings.MEDIA_URL, document_root=settings.MEDIA_ROOT)