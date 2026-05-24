from rest_framework import viewsets
from rest_framework import viewsets, permissions, status # <-- Add 'permissions' here
from .models import TrainingVideo
from .serializers import TrainingVideoSerializer
from rest_framework.response import Response
from django.db import models # Added this for filtering logic

class StudentVideoViewSet(viewsets.ReadOnlyModelViewSet):
    serializer_class = TrainingVideoSerializer
    permission_classes = [permissions.IsAuthenticated]

    def get_queryset(self):
        from organizations.models import Enrollment
        from django.db.models import Count

        if not hasattr(self.request.user, 'student_profile'):
            return TrainingVideo.objects.none()

        student = self.request.user.student_profile
        batch_ids = list(
            Enrollment.objects.filter(student=student, is_active=True).values_list('batch_id', flat=True),
        )
        general = TrainingVideo.objects.filter(
            organization=student.organization,
            batch_id__in=batch_ids,
        ).annotate(target_count=Count('target_students')).filter(target_count=0)
        targeted = TrainingVideo.objects.filter(target_students=student)
        return (general | targeted).distinct().order_by('-uploaded_at')
    

class VideoUploadViewSet(viewsets.ModelViewSet):
    """
    Used by Academy Admins to upload and assign videos.
    """
    queryset = TrainingVideo.objects.all()
    serializer_class = TrainingVideoSerializer
    permission_classes = [permissions.IsAuthenticated]

    def perform_create(self, serializer):
        # Automatically assign the organization based on the admin's profile
        if hasattr(self.request.user, 'academy_admin_profile'):
            org = self.request.user.academy_admin_profile.organization
            serializer.save(organization=org)
        else:
            # Handle case where user isn't an admin (security check)
            return Response({"detail": "Not an admin profile"}, status=status.HTTP_403_FORBIDDEN)