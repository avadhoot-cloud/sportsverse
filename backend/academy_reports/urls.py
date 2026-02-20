from django.urls import path, include
from rest_framework.routers import DefaultRouter
from .views import  ReportUploadView

router = DefaultRouter()

urlpatterns = [
    path('', include(router.urls)),
path('upload/', ReportUploadView.as_view(), name='report-upload'),]