from rest_framework import viewsets
from rest_framework import viewsets, permissions, status # <-- Add 'permissions' here
from .models import TrainingVideo
from .serializers import TrainingVideoSerializer
from rest_framework.response import Response
from django.db import models # Added this for filtering logic

class StudentVideoViewSet(viewsets.ReadOnlyModelViewSet):
    serializer_class = TrainingVideoSerializer

    def get_queryset(self):
        user = self.request.user
        # Assuming the student is logged in
        student = user.student_profile 
        
        # Filter 1: Videos assigned specifically to this student
        # Filter 2: Videos assigned to the student's batch with NO specific students listed (General Batch Video)
        return TrainingVideo.objects.filter(
            models.Q(target_students=student) | 
            models.Q(batch=student.batch, target_students__isnull=True)
        ).distinct()
    

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