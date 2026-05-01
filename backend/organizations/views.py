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
        batch_id = request.query_params.get('batch', '').rstrip('/')
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

    # Get enrollment
    enrollment_id = self.request.data.get('enrollment')
    if not enrollment_id:
        raise ValueError('enrollment is required')

    enrollment = get_object_or_404(Enrollment, pk=enrollment_id)

    # Validate organization
    organization = self.request.user.academy_admin_profile.organization
    if enrollment.organization != organization:
        raise PermissionError('Cannot mark attendance outside your organization')

    # Get date
    attendance_date = self.request.data.get('date')
    if not attendance_date:
        raise ValueError('date is required')

    print(f"🔍 Backend: Creating attendance for enrollment {enrollment_id}, date {attendance_date}")

    # 🚫 SESSION LIMIT CHECK
    if enrollment.enrollment_type == 'SESSION_BASED' and enrollment.total_sessions:
        if enrollment.sessions_attended >= enrollment.total_sessions:
            raise ValueError(
                f'Enrollment has reached its session limit '
                f'({enrollment.sessions_attended}/{enrollment.total_sessions}). '
                f'Please create a new enrollment.'
            )

    # 🔒 LOCK CHECK (IMPORTANT)
    existing_attendance = Attendance.objects.filter(
        enrollment=enrollment,
        date=attendance_date
    ).select_related('marked_by').first()

    if existing_attendance:
        user_type = existing_attendance.marked_by.user_type if existing_attendance.marked_by else "UNKNOWN"

        print(f"🚫 Attendance already marked by {user_type}")

        raise ValueError(
            f"Attendance already marked by {user_type}. You cannot modify it."
        )

    # ✅ CREATE NEW ATTENDANCE
    attendance = Attendance.objects.create(
        enrollment=enrollment,
        date=attendance_date,
        organization=organization,
        batch=enrollment.batch,
        student=enrollment.student,
        marked_by=self.request.user
    )

    print(f"✅ Backend: New attendance record created with ID {attendance.id}")

    # 🎯 CHECK IF ENROLLMENT COMPLETED AFTER THIS
    enrollment.refresh_from_db()  # IMPORTANT to get updated sessions_attended

    if enrollment.enrollment_type == 'SESSION_BASED' and enrollment.total_sessions:
        if enrollment.sessions_attended >= enrollment.total_sessions:
            print(
                f"🎯 Backend: Enrollment {enrollment_id} is now complete "
                f"({enrollment.sessions_attended}/{enrollment.total_sessions})"
            )
            enrollment.is_active = False
            enrollment.save()
            print(f"✅ Backend: Enrollment {enrollment_id} marked as inactive")

    return attendance
from datetime import datetime

class BatchStudentsForAttendanceView(APIView):
    permission_classes = [IsAuthenticated]

def get(self, request):
    batch_id = request.query_params.get('batch', '').rstrip('/')
    date = request.query_params.get('date')  # YYYY-MM-DD

    if not batch_id or not date:
        return Response({"error": "batch and date required"}, status=400)

    batch = get_object_or_404(Batch, id=batch_id)

    # ✅ Check valid day (Mon, Tue etc.)

    enrollments = Enrollment.objects.filter(
        batch=batch,
        is_active=True
    ).select_related('student')

    data = []

    for e in enrollments:
        attendance_obj = Attendance.objects.filter(
            enrollment=e,
            date=date
        ).select_related('marked_by').first()

        data.append({
            "enrollment_id": e.id,
            "student_id": e.student.id,
            "student_name": f"{e.student.first_name} {e.student.last_name}",
            "sessions_left": (
                e.total_sessions - e.sessions_attended
                if e.total_sessions else None
            ),
            "already_marked": attendance_obj is not None,  # ✅ BOOLEAN ONLY
            "marked_by": attendance_obj.marked_by.username if attendance_obj else None
        })

    return Response(data)


from collections import defaultdict
from datetime import datetime

from rest_framework.views import APIView
from rest_framework.response import Response
from rest_framework.permissions import IsAuthenticated
from datetime import datetime, timedelta
from .models import Enrollment, Attendance

class StudentAttendanceView(APIView):
    permission_classes = [IsAuthenticated]

    def get(self, request):
        user = request.user

        # ✅ Only student allowed
        if not hasattr(user, 'student_profile'):
            return Response({"error": "Only students allowed"}, status=403)

        student = user.student_profile
        enrollments = Enrollment.objects.filter(student=student)

        final_data = []

        for e in enrollments:
            attendances = Attendance.objects.filter(
                enrollment=e
            ).select_related('marked_by').order_by('date')

            # ✅ TOTAL SESSIONS
            total_sessions = e.total_sessions if e.total_sessions else attendances.count()

            # ✅ PRESENT COUNT
            present_count = attendances.filter(is_session_deducted=True).count()

            # ✅ PERCENTAGE
            percentage = (present_count / total_sessions * 100) if total_sessions > 0 else 0

            # ✅ BUILD FULL LIST (PRESENT + ABSENT)
            attendance_list = []

            if e.start_date:
                current_date = e.start_date
                today = datetime.today().date()

                while current_date <= today:
                    attendance_obj = attendances.filter(date=current_date).first()

                    if attendance_obj:
                        attendance_list.append({
                            "date": current_date,
                            "status": "Present",
                            "time": attendance_obj.timestamp,
                            "marked_by": attendance_obj.marked_by.username if attendance_obj.marked_by else None
                        })
                    else:
                        attendance_list.append({
                            "date": current_date,
                            "status": "Absent",
                            "time": None,
                            "marked_by": None
                        })

                    current_date += timedelta(days=1)

            final_data.append({
                "batch_name": e.batch.name,
                "attendance_percentage": round(percentage, 1),
                "present_count": present_count,
                "total_sessions": total_sessions,
                "low_attendance": percentage < 75,
                "attendance_details": attendance_list[::-1]  # latest first 🔥
            })

        return Response(final_data)
    
class BulkAttendanceMarkView(APIView):
    permission_classes = [IsAuthenticated]

    def post(self, request):
        attendance_list = request.data.get("attendance")

        if not attendance_list:
            return Response({"error": "attendance list required"}, status=400)

        user = request.user
        results = []

        for item in attendance_list:
            enrollment_id = item.get("enrollment_id")
            date = item.get("date")

            if not enrollment_id or not date:
                results.append({
                    "error": "enrollment_id and date required"
                })
                continue

            enrollment = get_object_or_404(Enrollment, id=enrollment_id)

            # ✅ SECURITY: Ensure same organization
            if enrollment.organization != user.academy_admin_profile.organization:
                results.append({
                    "student": enrollment.student.first_name,
                    "status": "error",
                    "message": "Unauthorized"
                })
                continue

            # ✅ SESSION LIMIT CHECK
            if enrollment.enrollment_type == 'SESSION_BASED' and enrollment.total_sessions:
                if enrollment.sessions_attended >= enrollment.total_sessions:
                    results.append({
                        "student": enrollment.student.first_name,
                        "status": "error",
                        "message": "Session limit reached"
                    })
                    continue

            # ✅ LOCK CHECK (IMPORTANT 🔥)
            existing_attendance = Attendance.objects.filter(
                enrollment=enrollment,
                date=date
            ).first()

            if existing_attendance:
                # If already marked by someone else → LOCK
                if existing_attendance.marked_by != user:
                    results.append({
                        "student": enrollment.student.first_name,
                        "status": "locked",
                        "message": f"Already marked by {existing_attendance.marked_by.username}"
                    })
                    continue

                # If same user → allow update (optional)
                results.append({
                    "student": enrollment.student.first_name,
                    "status": "already marked"
                })
                continue

            # ✅ CREATE NEW ATTENDANCE
            attendance = Attendance.objects.create(
                enrollment=enrollment,
                organization=enrollment.organization,
                batch=enrollment.batch,
                student=enrollment.student,
                date=date,
                marked_by=user
            )

            results.append({
                "student": enrollment.student.first_name,
                "status": "marked"
            })

        return Response({
            "message": "Attendance processed",
            "results": results
        })

from rest_framework.views import APIView
from rest_framework.response import Response
from datetime import datetime

class AttendanceStudentsView(APIView):
    permission_classes = [IsAuthenticated]

    def get(self, request):
        batch_id = request.query_params.get('batch', '').rstrip('/')
        date = request.query_params.get('date', '').rstrip('/')

        if not batch_id or not date:
            return Response({"error": "batch and date required"}, status=400)

        enrollments = Enrollment.objects.filter(
            batch_id=batch_id,
            is_active=True
        ).select_related('student')

        data = []

        for e in enrollments:
            # ✅ ALWAYS BOOLEAN (VERY IMPORTANT)
            already_marked = Attendance.objects.filter(
                enrollment=e,
                date=date
            ).exists()

            # ✅ SAFE CALCULATION
            sessions_left = None
            if e.enrollment_type == 'SESSION_BASED' and e.total_sessions:
                sessions_left = e.total_sessions - e.sessions_attended

            data.append({
                "enrollment_id": e.id,
                "student_id": e.student.id,
                "student_name": f"{e.student.first_name} {e.student.last_name}",
                "already_marked": already_marked,  # ✅ BOOLEAN ONLY
                "sessions_left": sessions_left,
            })

        return Response(data)