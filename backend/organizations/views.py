# sportsverse/backend/organizations/views.py

from rest_framework import generics, permissions, status
from rest_framework.response import Response
from rest_framework.permissions import IsAuthenticated
from django.shortcuts import get_object_or_404
from .models import Organization, Sport, Branch, Batch, Enrollment, Attendance
from .serializers import (OrganizationSerializer, SportSerializer, BranchSerializer, 
                          BatchSerializer, EnrollmentSerializer, StudentProfileSerializer, 
                          StudentEnrollmentSerializer, AttendanceSerializer)
from accounts.models import StudentProfile

class SportListView(generics.ListAPIView):
    """
    API endpoint to list all available sports.
    Accessible publicly for academy registration.
    """
    queryset = Sport.objects.all()
    serializer_class = SportSerializer
    permission_classes = [permissions.AllowAny] # Allow unauthenticated access for registration form

# Branch Management Views for Academy Admin
class BranchListCreateView(generics.ListCreateAPIView):
    """
    API endpoint for Academy Admin to list and create branches.
    GET: List all branches of the academy
    POST: Create a new branch
    """
    serializer_class = BranchSerializer
    permission_classes = [IsAuthenticated]
    
    def get_queryset(self):
        # Only return branches belonging to the logged-in admin's organization
        if hasattr(self.request.user, 'academy_admin_profile'):
            return Branch.objects.filter(organization=self.request.user.academy_admin_profile.organization)
        return Branch.objects.none()
    
    def perform_create(self, serializer):
        # Automatically set the organization to the logged-in admin's organization
        if hasattr(self.request.user, 'academy_admin_profile'):
            serializer.save(organization=self.request.user.academy_admin_profile.organization)
        else:
            return Response(
                {"detail": "Only Academy Admins can create branches."},
                status=status.HTTP_403_FORBIDDEN
            )

class BranchRetrieveUpdateDestroyView(generics.RetrieveUpdateDestroyAPIView):
    """
    API endpoint for Academy Admin to retrieve, update, or delete a specific branch.
    GET: Retrieve branch details
    PUT/PATCH: Update branch
    DELETE: Delete branch
    """
    serializer_class = BranchSerializer
    permission_classes = [IsAuthenticated]
    
    def get_queryset(self):
        # Only allow access to branches belonging to the logged-in admin's organization
        if hasattr(self.request.user, 'academy_admin_profile'):
            return Branch.objects.filter(organization=self.request.user.academy_admin_profile.organization)
        return Branch.objects.none()


# Batch Management Views for Academy Admin
class BatchListCreateView(generics.ListCreateAPIView):
    """
    API endpoint for Academy Admin to list and create batches.
    GET: List all batches of the academy
    POST: Create a new batch
    """
    serializer_class = BatchSerializer
    permission_classes = [IsAuthenticated]
    
    def get_queryset(self):
        # Only return batches belonging to the logged-in admin's organization
        if hasattr(self.request.user, 'academy_admin_profile'):
            return Batch.objects.filter(organization=self.request.user.academy_admin_profile.organization).select_related('branch', 'sport', 'organization')
        return Batch.objects.none()
    
    def perform_create(self, serializer):
        # Automatically set the organization to the logged-in admin's organization
        if hasattr(self.request.user, 'academy_admin_profile'):
            serializer.save(organization=self.request.user.academy_admin_profile.organization)
        else:
            return Response(
                {"detail": "Only Academy Admins can create batches."},
                status=status.HTTP_403_FORBIDDEN
            )

class BatchRetrieveUpdateDestroyView(generics.RetrieveUpdateDestroyAPIView):
    """
    API endpoint for Academy Admin to retrieve, update, or delete a specific batch.
    GET: Retrieve batch details
    PUT/PATCH: Update batch
    DELETE: Delete batch
    """
    serializer_class = BatchSerializer
    permission_classes = [IsAuthenticated]
    
    def get_queryset(self):
        # Only allow access to batches belonging to the logged-in admin's organization
        if hasattr(self.request.user, 'academy_admin_profile'):
            return Batch.objects.filter(organization=self.request.user.academy_admin_profile.organization).select_related('branch', 'sport', 'organization')
        return Batch.objects.none()


# Enrollment Management Views for Academy Admin
class EnrollmentListCreateView(generics.ListCreateAPIView):
    """
    API endpoint for Academy Admin to list and create student enrollments.
    GET: List all enrollments of the academy
    POST: Enroll a student in a batch
    """
    serializer_class = EnrollmentSerializer
    permission_classes = [IsAuthenticated]
    
    def get_queryset(self):
        # Only return enrollments belonging to the logged-in admin's organization
        if hasattr(self.request.user, 'academy_admin_profile'):
            queryset = Enrollment.objects.filter(organization=self.request.user.academy_admin_profile.organization).select_related('student__user', 'batch', 'organization')
            
            # Optional filtering by batch
            batch_id = self.request.query_params.get('batch', None)
            if batch_id:
                queryset = queryset.filter(batch_id=batch_id)
                
            # Optional filtering by student
            student_id = self.request.query_params.get('student', None)
            if student_id:
                queryset = queryset.filter(student_id=student_id)
                
            return queryset
        return Enrollment.objects.none()
    
    def perform_create(self, serializer):
        # Automatically set the organization to the logged-in admin's organization
        if hasattr(self.request.user, 'academy_admin_profile'):
            serializer.save(organization=self.request.user.academy_admin_profile.organization)
        else:
            return Response(
                {"detail": "Only Academy Admins can create enrollments."},
                status=status.HTTP_403_FORBIDDEN
            )

class EnrollmentRetrieveUpdateDestroyView(generics.RetrieveUpdateDestroyAPIView):
    """
    API endpoint for Academy Admin to retrieve, update, or delete a specific enrollment.
    GET: Retrieve enrollment details
    PUT/PATCH: Update enrollment
    DELETE: Delete enrollment
    """
    serializer_class = EnrollmentSerializer
    permission_classes = [IsAuthenticated]
    
    def get_queryset(self):
        # Only allow access to enrollments belonging to the logged-in admin's organization
        if hasattr(self.request.user, 'academy_admin_profile'):
            return Enrollment.objects.filter(organization=self.request.user.academy_admin_profile.organization).select_related('student__user', 'batch', 'organization')
        return Enrollment.objects.none()


# Student Management Views for Academy Admin
class StudentListCreateView(generics.ListCreateAPIView):
    """
    API endpoint for Academy Admin to list and create students.
    GET: List all students of the academy
    POST: Create a new student
    """
    serializer_class = StudentProfileSerializer
    permission_classes = [IsAuthenticated]
    
    def get_queryset(self):
        # Only return students belonging to the logged-in admin's organization
        if hasattr(self.request.user, 'academy_admin_profile'):
            return StudentProfile.objects.filter(organization=self.request.user.academy_admin_profile.organization)
        return StudentProfile.objects.none()


class StudentRetrieveUpdateDestroyView(generics.RetrieveUpdateDestroyAPIView):
    """
    API endpoint for Academy Admin to retrieve, update, or delete a specific student.
    GET: Retrieve student details
    PUT/PATCH: Update student
    DELETE: Delete student
    """
    serializer_class = StudentProfileSerializer
    permission_classes = [IsAuthenticated]
    
    def get_queryset(self):
        # Only allow access to students belonging to the logged-in admin's organization
        if hasattr(self.request.user, 'academy_admin_profile'):
            return StudentProfile.objects.filter(organization=self.request.user.academy_admin_profile.organization)
        return StudentProfile.objects.none()


# Combined Student + Enrollment Creation
class StudentEnrollmentCreateView(generics.CreateAPIView):
    """
    API endpoint for Academy Admin to create a student with enrollment in one step.
    POST: Create student and enroll them in a batch
    """
    serializer_class = StudentEnrollmentSerializer
    permission_classes = [IsAuthenticated]
    
    def create(self, request, *args, **kwargs):
        if not hasattr(request.user, 'academy_admin_profile'):
            return Response(
                {"detail": "Only Academy Admins can create student enrollments."},
                status=status.HTTP_403_FORBIDDEN
            )
        
        serializer = self.get_serializer(data=request.data)
        if serializer.is_valid():
            result = serializer.save()
            
            # Return combined response with student and enrollment data
            student_data = StudentProfileSerializer(result['student']).data
            enrollment_data = EnrollmentSerializer(result['enrollment']).data
            
            return Response({
                'message': 'Student created and enrolled successfully',
                'student': student_data,
                'enrollment': enrollment_data
            }, status=status.HTTP_201_CREATED)
        
        return Response(serializer.errors, status=status.HTTP_400_BAD_REQUEST)


class AttendanceListView(generics.ListCreateAPIView):
    """
    API endpoint to list attendance records with optional filters.
    Filters:
      - student: student id
      - batch: batch id
      - start_date, end_date: date range
    """
    serializer_class = AttendanceSerializer
    permission_classes = [IsAuthenticated]

    def get_queryset(self):
        if not hasattr(self.request.user, 'academy_admin_profile'):
            return Attendance.objects.none()

        queryset = Attendance.objects.filter(
            organization=self.request.user.academy_admin_profile.organization
        ).select_related('student__user', 'batch', 'enrollment')

        student_id = self.request.query_params.get('student')
        if student_id:
            queryset = queryset.filter(student_id=student_id)

        batch_id = self.request.query_params.get('batch')
        if batch_id:
            queryset = queryset.filter(batch_id=batch_id)

        start_date = self.request.query_params.get('start_date')
        end_date = self.request.query_params.get('end_date')
        if start_date:
            queryset = queryset.filter(date__gte=start_date)
        if end_date:
            queryset = queryset.filter(date__lte=end_date)

        return queryset.order_by('date')

    def perform_create(self, serializer):
        # Only admins of the organization can create
        if not hasattr(self.request.user, 'academy_admin_profile'):
            raise PermissionError("Only Academy Admins can create attendance records.")

        # Expect enrollment id in data; derive related fields
        enrollment_id = self.request.data.get('enrollment')
        if not enrollment_id:
            raise ValueError('enrollment is required')
        enrollment = get_object_or_404(Enrollment, pk=enrollment_id)

        # Ensure enrollment belongs to admin's organization
        organization = self.request.user.academy_admin_profile.organization
        if enrollment.organization != organization:
            raise PermissionError('Cannot mark attendance outside your organization')

        serializer.save(
            organization=organization,
            batch=enrollment.batch,
            student=enrollment.student
        )