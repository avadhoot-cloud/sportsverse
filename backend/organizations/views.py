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
from rest_framework.views import APIView # <--- THIS WAS MISSING

class BatchAttendanceSummaryView(APIView):
    def get(self, request):
        batch_id = request.query_params.get('batch')
        if not batch_id:
            return Response({"error": "Batch ID required"}, status=400)

        # Fetch all enrollments for this batch
        enrollments = Enrollment.objects.filter(batch_id=batch_id)
        
        summary_data = []
        for emp in enrollments:
            # Calculate stats for this specific student in this batch
            total_sessions = Attendance.objects.filter(student=emp.student, batch_id=batch_id).count()
            # RIGHT (Using enrollment and the correct status field)
            present_count = Attendance.objects.filter(
            student=emp.student, 
            batch_id=batch_id, 
            is_session_deducted=True # Or whatever field you use to mark attendance
            ).count()            
            # Avoid division by zero
            percentage = (present_count / total_sessions * 100) if total_sessions > 0 else 0
            
            summary_data.append({
                "student_id": emp.student.id,
                "student_name": f"{emp.student.first_name} {emp.student.last_name}",
                "attendance_percentage": round(percentage, 1),
                "total_sessions": total_sessions,
                "present_count": present_count,
            })
            
        return Response(summary_data, status=200)

def get_queryset(self):
    user = self.request.user
    if hasattr(user, 'coach_profile'):
        # Coaches ONLY see students in batches assigned to them
        assigned_batches = user.coach_profile.assignments.values_list('batch_id', flat=True)
        return Enrollment.objects.filter(batch_id__in=assigned_batches)
    return Enrollment.objects.all()


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

            # --- Logic for PRE_PAID Fee Transaction ---
            enrollment = result['enrollment']
            batch = enrollment.batch
            if batch.payment_policy == 'PRE_PAID' and batch.fee_per_session is not None and enrollment.total_sessions is not None:
                from payments.models import FeeTransaction
                from decimal import Decimal

                total_fee = Decimal(batch.fee_per_session) * Decimal(enrollment.total_sessions)
                
                FeeTransaction.objects.create(
                    organization=enrollment.organization,
                    student=enrollment.student,
                    enrollment=enrollment,
                    amount=total_fee,
                    due_date=enrollment.date_enrolled.date(), # Or other due date logic
                    is_paid=False
                )
            # --- End of Fee Logic ---
            
            return Response({
                'message': 'Student created and enrolled successfully',
                'student': student_data,
                'enrollment': enrollment_data
            }, status=status.HTTP_201_CREATED)
        
        return Response(serializer.errors, status=status.HTTP_400_BAD_REQUEST)


class AttendanceRetrieveUpdateDestroyView(generics.RetrieveUpdateDestroyAPIView):
    """
    API endpoint to retrieve, update, or delete a specific attendance record.
    """
    serializer_class = AttendanceSerializer
    permission_classes = [IsAuthenticated]

    def get_queryset(self):
        if not hasattr(self.request.user, 'academy_admin_profile'):
            return Attendance.objects.none()

        return Attendance.objects.filter(
            organization=self.request.user.academy_admin_profile.organization
        ).select_related('student__user', 'batch', 'enrollment')

    def perform_update(self, serializer):
        # Only admins of the organization can update
        if not hasattr(self.request.user, 'academy_admin_profile'):
            raise PermissionError("Only Academy Admins can update attendance records.")

        # Ensure attendance belongs to admin's organization
        organization = self.request.user.academy_admin_profile.organization
        if serializer.instance.organization != organization:
            raise PermissionError('Cannot update attendance outside your organization')

        serializer.save(marked_by=self.request.user)

    def perform_destroy(self, instance):
        # Only admins of the organization can delete
        if not hasattr(self.request.user, 'academy_admin_profile'):
            raise PermissionError("Only Academy Admins can delete attendance records.")

        # Ensure attendance belongs to admin's organization
        organization = self.request.user.academy_admin_profile.organization
        if instance.organization != organization:
            raise PermissionError('Cannot delete attendance outside your organization')

        instance.delete()


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

        # Use get_or_create to handle duplicates gracefully
        attendance_date = self.request.data.get('date')
        if not attendance_date:
            raise ValueError('date is required')

        print(f"🔍 Backend: Creating attendance for enrollment {enrollment_id}, date {attendance_date}")

        # Check if enrollment is session-based and has reached its limit
        if enrollment.enrollment_type == 'SESSION_BASED' and enrollment.total_sessions:
            if enrollment.sessions_attended >= enrollment.total_sessions:
                # Enrollment is complete, check if we should create a new one
                print(f"⚠️ Backend: Enrollment {enrollment_id} has reached its session limit ({enrollment.sessions_attended}/{enrollment.total_sessions})")
                
                # Option 1: Prevent over-marking (recommended for sports academies)
                raise ValueError(f'Enrollment has reached its session limit ({enrollment.sessions_attended}/{enrollment.total_sessions}). Please create a new enrollment for this student.')
                
                # Option 2: Auto-create new enrollment (uncomment if you want this behavior)
                # print(f"🔄 Backend: Auto-creating new enrollment for student {enrollment.student.id}")
                # new_enrollment = Enrollment.objects.create(
                #     student=enrollment.student,
                #     batch=enrollment.batch,
                #     organization=organization,
                #     enrollment_type=enrollment.enrollment_type,
                #     total_sessions=enrollment.total_sessions,
                #     sessions_attended=0,
                #     is_active=True,
                # )
                # print(f"✅ Backend: New enrollment created with ID {new_enrollment.id}")
                # enrollment = new_enrollment

        # Use get_or_create to handle duplicates gracefully
        attendance, created = Attendance.objects.get_or_create(
            enrollment=enrollment,
            date=attendance_date,
            defaults={
                'organization': organization,
                'batch': enrollment.batch,
                'student': enrollment.student,
                'marked_by': self.request.user,
            }
        )
        
        # If attendance already existed, update the marked_by field
        if not created:
            print(f"🔄 Backend: Attendance already existed with ID {attendance.id}, updating marked_by")
            attendance.marked_by = self.request.user
            attendance.save()
        else:
            print(f"✅ Backend: New attendance record created with ID {attendance.id}")
            
            # Check if enrollment is now complete after this attendance
            if enrollment.enrollment_type == 'SESSION_BASED' and enrollment.total_sessions:
                if enrollment.sessions_attended >= enrollment.total_sessions:
                    print(f"🎯 Backend: Enrollment {enrollment_id} is now complete ({enrollment.sessions_attended}/{enrollment.total_sessions})")
                    # Mark enrollment as inactive when complete
                    enrollment.is_active = False
                    enrollment.save()
                    print(f"✅ Backend: Enrollment {enrollment_id} marked as inactive")
        
        return attendance