# sportsverse/backend/accounts/views.py

from rest_framework import status, generics
from rest_framework.response import Response
from rest_framework.views import APIView
from rest_framework.permissions import AllowAny, IsAuthenticated
from rest_framework.authtoken.models import Token # For token-based authentication
from django.contrib.auth import login # For session-based login if preferred
from django.contrib.auth.tokens import default_token_generator
from django.core.mail import send_mail
from django.template.loader import render_to_string
from django.utils.http import urlsafe_base64_encode, urlsafe_base64_decode
from django.utils.encoding import force_bytes, force_str
from django.conf import settings
from django.db.models import Sum, Q, DecimalField
from django.shortcuts import get_object_or_404
import json
import logging

logger = logging.getLogger(__name__)

from .serializers import (RegisterAcademySerializer, LoginSerializer, 
                           UserSerializer, 
                           StudentFinancialsSerializer, StudentListSerializer,StudentFeeSerializer)
from .models import CustomUser, AcademyAdminProfile, StudentProfile
from organizations.models import Organization,Enrollment, Attendance,Batch, Branch, Sport
from payments.models import FeeTransaction
from coaches.models import CoachProfile
from django.shortcuts import render
from django.http import HttpResponse
from django.db.models import Sum
from rest_framework.decorators import api_view, permission_classes
from django.utils import timezone

from accounts.models import StudentProfile
from payments .models import FeeTransaction
from .serializers import StudentFeeSerializer

class DashboardStatsView(APIView):
    permission_classes = [IsAuthenticated]

    def get(self, request):
        # Filter by the logged-in admin's organization
        org = request.user.academy_admin_profile.organization
        
        return Response({
            "total_students": StudentProfile.objects.filter(organization=org).count(),
            "total_coaches": CoachProfile.objects.filter(organization=org).count(),
            "total_branches": Branch.objects.filter(organization=org).count(),
            "total_batches": Batch.objects.filter(organization=org).count(),
        })
    
@api_view(['GET'])
@permission_classes([IsAuthenticated])
def dashboard_stats(request):
    try:
        org = request.user.academy_admin_profile.organization
        return Response({
            'total_students': StudentProfile.objects.filter(organization=org).count(),
            'total_coaches': CoachProfile.objects.filter(organization=org).count(),
            'total_branches': Branch.objects.filter(organization=org).count(),
            'total_batches': Batch.objects.filter(organization=org).count(),
        }, status=200)
    except Exception as e:
        return Response({'error': str(e)}, status=500)

@api_view(['GET'])
@permission_classes([IsAuthenticated])
def student_payment_history(request):
    try:
        # Link to the student profile via the authenticated user
        student_profile = request.user.studentprofile
        transactions = FeeTransaction.objects.filter(student=student_profile).order_by('-transaction_date')
        serializer = StudentFeeSerializer(transactions, many=True)
        return Response(serializer.data)
    except Exception:
        return Response({"error": "Student profile not found"}, status=404)

def dummy_view(request):
    return HttpResponse("Accounts app is working!")

class BatchFinancialsSummaryView(APIView):
    permission_classes = [IsAuthenticated]

    def get(self, request):
        branch_id = request.query_params.get('branch')
        sport_id = request.query_params.get('sport')
        batch_id = request.query_params.get('batch')

        if not (branch_id and sport_id and batch_id):
            return Response({'detail': 'branch, sport and batch are required'}, status=status.HTTP_400_BAD_REQUEST)

        batch = get_object_or_404(Batch, pk=batch_id)

        # Permission check
        if not hasattr(request.user, 'academy_admin_profile'):
            return Response({'detail': 'Permission denied'}, status=status.HTTP_403_FORBIDDEN)
        
        enrollments = Enrollment.objects.filter(batch=batch, is_active=True).select_related('student')

        students_data = []
        for enrollment in enrollments:
            student = enrollment.student

            # Calculate Sessions for display
            sessions_left = None
            total_sessions = None
            if enrollment.enrollment_type == 'SESSION_BASED':
                total_sessions = enrollment.total_sessions or 0
                sessions_left = max(0, total_sessions - (enrollment.sessions_attended or 0))

            # Count unpaid transactions
            unpaid_count = FeeTransaction.objects.filter(enrollment=enrollment, is_paid=False).count()

            # Payment history for this specific student/enrollment
            transactions = FeeTransaction.objects.filter(student=student, enrollment=enrollment).order_by('-transaction_date')
            payment_history = [
                {
                    'id': t.id,
                    'amount': float(t.amount),
                    'transaction_date': t.transaction_date.isoformat() if t.transaction_date else None,
                    'is_paid': t.is_paid,
                    'payment_method': t.payment_method,
                }
                for t in transactions
            ]

            students_data.append({
                'student_id': student.id,
                'enrollment_id': enrollment.id, # CRITICAL: Needed for the record payment button
                'first_name': student.first_name,
                'last_name': student.last_name,
                'sessions_left': sessions_left,
                'total_sessions': total_sessions,
                'unpaid_sessions': unpaid_count,
                'payment_history': payment_history,
                'policy': batch.payment_policy
            })

        return Response({
            'batch': {
                'id': batch.id,
                'name': batch.name,
                'payment_policy': batch.payment_policy,
                'fee_per_session': float(batch.fee_per_session or 0),
            },
            'students': students_data,
        })

class CollectStudentFeeView(APIView):
    permission_classes = [IsAuthenticated]

    def post(self, request):
        student_id = request.data.get('student_id')
        enrollment_id = request.data.get('enrollment_id')
        amount = request.data.get('amount')
        payment_method = request.data.get('payment_method', 'Cash')
        
        # 1. Look for an existing unpaid transaction record
        transaction = FeeTransaction.objects.filter(
            student_id=student_id, 
            enrollment_id=enrollment_id, 
            is_paid=False
        ).order_by('id').first()

        if transaction:
            transaction.is_paid = True
            transaction.amount = amount
            transaction.payment_method = payment_method
            transaction.transaction_date = timezone.now()
            transaction.save()
        else:
            enrollment = get_object_or_404(Enrollment, id=enrollment_id)

            transaction = FeeTransaction.objects.create(
                organization=enrollment.organization,   # ✅ FIXED
                student_id=student_id,
                enrollment=enrollment,
                amount=amount,
                is_paid=True,
                payment_method=payment_method,
                transaction_date=timezone.now()
            )

        
        return Response({
            'status': 'success',
            'message': 'Payment recorded successfully',
            'transaction_id': transaction.id
        })

class RegisterAcademyView(APIView):
    """
    API endpoint for a Platform Admin (or public) to register a new Academy/Organization.
    """
    permission_classes = [AllowAny] # Allow anyone to register a new academy

    def post(self, request):
        # Log the incoming data for debugging
        logger.info(f"Registration request data: {request.data}")
        
        # Convert QueryDict to regular dict for easier manipulation
        data = dict(request.data.lists())  # This preserves lists for fields that have multiple values
        
        # Convert single-value lists to single values for most fields
        for key, value_list in data.items():
            if not key.startswith('sports_offered_ids[') and len(value_list) == 1:
                data[key] = value_list[0]
        
        # Handle sports_offered_ids if sent as individual multipart fields
        if any(key.startswith('sports_offered_ids[') for key in data.keys()):
            sports_ids = []
            for key in list(data.keys()):
                if key.startswith('sports_offered_ids['):
                    try:
                        # Extract the value from the list
                        value = data[key][0] if isinstance(data[key], list) else data[key]
                        sports_ids.append(int(value))
                        # Remove the individual field
                        del data[key]
                    except (ValueError, TypeError, IndexError):
                        logger.error(f"Invalid sports ID: {data[key]}")
                        return Response({
                            'sports_offered_ids': [f'Invalid sports ID: {data[key]}']
                        }, status=status.HTTP_400_BAD_REQUEST)
            data['sports_offered_ids'] = sports_ids
            logger.info(f"Converted sports_offered_ids to: {sports_ids}")
        
        # Handle sports_offered_ids if sent as JSON string
        elif 'sports_offered_ids' in data and isinstance(data['sports_offered_ids'], str):
            try:
                data['sports_offered_ids'] = json.loads(data['sports_offered_ids'])
            except json.JSONDecodeError:
                logger.error(f"Failed to parse sports_offered_ids: {data['sports_offered_ids']}")
                return Response({
                    'sports_offered_ids': ['Invalid JSON format for sports_offered_ids']
                }, status=status.HTTP_400_BAD_REQUEST)
        
        logger.info(f"Final data being sent to serializer: {data}")
        
        serializer = RegisterAcademySerializer(data=data)
        if serializer.is_valid():
            organization = serializer.save()
            return Response({
                "message": "Academy registered successfully. Academy Admin user created.",
                "academy_id": organization.id,
                "academy_name": organization.academy_name,
                "admin_username": serializer.validated_data['admin_username']
            }, status=status.HTTP_201_CREATED)
        
        logger.error(f"Registration validation errors: {serializer.errors}")
        return Response(serializer.errors, status=status.HTTP_400_BAD_REQUEST)
    

class LoginView(APIView):
    """
    API endpoint for all user types to log in.
    Returns user details and an authentication token.
    """
    permission_classes = [AllowAny] # Allow anyone to attempt login

    def post(self, request):
        # 1. Print incoming data to terminal for debugging
        print(f"--- Login Attempt ---")
        print(f"DEBUG: Data received from Flutter: {request.data}") 
        
        serializer = LoginSerializer(data=request.data, context={'request': request})
        
        if serializer.is_valid():
            user = serializer.validated_data['user']
            print(f"DEBUG: Serializer Valid. User: {user.username}, Type: {user.user_type}")

            # Generate or Retrieve Token
            token, created = Token.objects.get_or_create(user=user)

            # Get associated profile details based on user_type
            profile_data = {}
            if user.user_type == 'ACADEMY_ADMIN':
                if hasattr(user, 'academy_admin_profile'):
                    profile_data = {
                        'organization_id': user.academy_admin_profile.organization.id,
                        'organization_name': user.academy_admin_profile.organization.academy_name,
                        'slug': user.academy_admin_profile.organization.slug
                    }
            elif user.user_type == 'COACH':
                if hasattr(user, 'coach_profile'):
                    profile_data = {
                        'organization_id': user.coach_profile.organization.id,
                        'organization_name': user.coach_profile.organization.academy_name,
                        'assigned_branches': [branch.id for branch in user.coach_profile.branches.all()]
                    }
            elif user.user_type == 'STUDENT':
                if hasattr(user, 'student_profile'):
                    student = user.student_profile
                    profile_data = {
                        'organization_id': student.organization.id,
                        'organization_name': student.organization.academy_name,
                        'student_id': student.id
                    }
            elif user.user_type == 'STAFF':
                if hasattr(user, 'staff_profile'):
                    profile_data = {
                        'organization_id': user.staff_profile.organization.id,
                        'organization_name': user.staff_profile.organization.academy_name
                    }
            
            # Prepare User Data for Response
            if user.user_type == 'STUDENT' and hasattr(user, 'student_profile'):
                student = user.student_profile
                user_data = {
                    'id': student.id,
                    'username': user.username,
                    'email': student.email,
                    'first_name': student.first_name,
                    'last_name': student.last_name,
                    'phone_number': student.phone_number,
                    'gender': student.gender,
                    'date_of_birth': student.date_of_birth.isoformat() if student.date_of_birth else None,
                    'user_type': user.user_type,
                    'address': student.address,
                    'parent_name': student.parent_name,
                    'parent_phone_number': student.parent_phone_number,
                    'parent_email': student.parent_email,
                    'profile_photo': f"{request.build_absolute_uri('/')[:-1]}{student.profile_photo.url}" if student.profile_photo else None,
                }
            else:
                user_data = UserSerializer(user).data
            
            return Response({
                "token": token.key,
                "user": user_data,
                "profile_details": profile_data,
                "must_change_password": user.must_change_password
            }, status=status.HTTP_200_OK)

        # 2. If login fails, print the EXACT error to the terminal
        print(f"❌ DEBUG: Serializer Errors: {serializer.errors}")
        return Response(serializer.errors, status=status.HTTP_400_BAD_REQUEST)


class PasswordResetRequestView(APIView):
    """
    API endpoint to request password reset via email.
    """
    permission_classes = [AllowAny]

    def post(self, request):
        email = request.data.get('email')
        
        if not email:
            return Response({
                'error': 'Email is required'
            }, status=status.HTTP_400_BAD_REQUEST)

        try:
            user = CustomUser.objects.get(email=email)
        except CustomUser.DoesNotExist:
            # For security, don't reveal if email exists or not
            return Response({
                'message': 'If your email is registered, you will receive a password reset link.'
            }, status=status.HTTP_200_OK)

        # Generate token
        token = default_token_generator.make_token(user)
        uid = urlsafe_base64_encode(force_bytes(user.pk))

        # Create reset link
        reset_link = f"http://localhost:3000/reset-password/{uid}/{token}/"

        # For testing purposes, let's just return the reset link
        # In production, you would send an email
        try:
            # Attempt to send email (this might fail if email settings are not configured)
            subject = 'Password Reset - SportsVerse'
            message = f'''
Hello {user.first_name},

You requested a password reset for your SportsVerse account.

Click the link below to reset your password:
{reset_link}

If you did not request this reset, please ignore this email.

The SportsVerse Team
            '''
            
            # Try to send email, but don't fail if it doesn't work
            try:
                send_mail(
                    subject,
                    message,
                    settings.DEFAULT_FROM_EMAIL,
                    [email],
                    fail_silently=False,
                )
                email_sent = True
            except Exception as e:
                logger.warning(f"Failed to send email: {e}")
                email_sent = False

            return Response({
                'message': 'If your email is registered, you will receive a password reset link.',
                'reset_link': reset_link if not email_sent else None,  # Only return link if email failed
                'note': 'Since email is not configured, use the reset_link above' if not email_sent else None
            }, status=status.HTTP_200_OK)

        except Exception as e:
            logger.error(f"Password reset error: {e}")
            return Response({
                'error': 'An error occurred while processing your request'
            }, status=status.HTTP_500_INTERNAL_SERVER_ERROR)


class PasswordResetConfirmView(APIView):
    """
    API endpoint to confirm password reset with token.
    """
    permission_classes = [AllowAny]

    def post(self, request):
        uid = request.data.get('uid')
        token = request.data.get('token')
        new_password = request.data.get('new_password')

        if not all([uid, token, new_password]):
            return Response({
                'error': 'UID, token, and new password are required'
            }, status=status.HTTP_400_BAD_REQUEST)

        # Validate password strength
        if len(new_password) < 8:
            return Response({
                'error': 'Password must be at least 8 characters long'
            }, status=status.HTTP_400_BAD_REQUEST)

        try:
            # Decode the user ID
            user_id = force_str(urlsafe_base64_decode(uid))
            user = CustomUser.objects.get(pk=user_id)

            # Verify the token
            if default_token_generator.check_token(user, token):
                # Set the new password
                user.set_password(new_password)
                user.save()

                return Response({
                    'message': 'Password has been reset successfully. You can now log in with your new password.'
                }, status=status.HTTP_200_OK)
            else:
                return Response({
                    'error': 'Invalid or expired token'
                }, status=status.HTTP_400_BAD_REQUEST)

        except (TypeError, ValueError, OverflowError, CustomUser.DoesNotExist):
            return Response({
                'error': 'Invalid reset link'
            }, status=status.HTTP_400_BAD_REQUEST)


class ChangePasswordView(APIView):
    """
    API endpoint for authenticated users to change their password.
    """
    permission_classes = [IsAuthenticated]

    def post(self, request):
        current_password = request.data.get('current_password')
        new_password = request.data.get('new_password')

        if not all([current_password, new_password]):
            return Response({
                'error': 'Current password and new password are required'
            }, status=status.HTTP_400_BAD_REQUEST)

        # Validate current password
        if not request.user.check_password(current_password):
            return Response({
                'error': 'Current password is incorrect'
            }, status=status.HTTP_400_BAD_REQUEST)

        # Validate new password strength
        if len(new_password) < 8:
            return Response({
                'error': 'New password must be at least 8 characters long'
            }, status=status.HTTP_400_BAD_REQUEST)

        # Check if new password is different from current
        if current_password == new_password:
            return Response({
                'error': 'New password must be different from current password'
            }, status=status.HTTP_400_BAD_REQUEST)

        # Set the new password and reset must_change_password flag
        request.user.set_password(new_password)
        request.user.must_change_password = False
        request.user.save()

        return Response({
            'message': 'Password changed successfully'
        }, status=status.HTTP_200_OK)


class StudentFinancialsView(generics.RetrieveAPIView):
    """
    API endpoint to retrieve financial summary for a specific student.
    """
    serializer_class = StudentFinancialsSerializer
    permission_classes = [IsAuthenticated]

    def get_object(self):
        student_id = self.kwargs.get('student_id')
        student = get_object_or_404(StudentProfile, id=student_id)

        # Security check: Ensure the requesting admin belongs to the same organization as the student
        if hasattr(self.request.user, 'academy_admin_profile'):
            if student.organization != self.request.user.academy_admin_profile.organization:
                raise PermissionError("You do not have permission to view this student's financials.")
        else:
            # Add other permission checks if necessary (e.g., for parents, staff)
            raise PermissionError("You do not have permission to view this student's financials.")

        # Calculate total paid and total due amounts
        transactions = FeeTransaction.objects.filter(student=student)
        
        total_paid = transactions.filter(is_paid=True).aggregate(total=Sum('amount', output_field=DecimalField()))['total'] or 0.00
        total_due = transactions.filter(is_paid=False).aggregate(total=Sum('amount', output_field=DecimalField()))['total'] or 0.00

        return {'total_paid': total_paid, 'total_due': total_due}

class StudentListView(generics.ListAPIView):
    """
    API endpoint to list all students for the logged-in academy admin.
    """
    serializer_class = StudentListSerializer
    permission_classes = [IsAuthenticated]

    def get_queryset(self):
        if hasattr(self.request.user, 'academy_admin_profile'):
            organization = self.request.user.academy_admin_profile.organization
            return StudentProfile.objects.filter(organization=organization).order_by('first_name', 'last_name')
        return StudentProfile.objects.none()


# Student-specific views for student dashboard
class StudentDashboardView(APIView):
    """
    API endpoint for student dashboard data.
    Returns enrollment details, attendance summary, and payment information.
    """
    permission_classes = [IsAuthenticated]

    def get(self, request):
        # Ensure user is a student
        if not hasattr(request.user, 'student_profile'):
            return Response({'error': 'Access denied. Student profile required.'}, status=status.HTTP_403_FORBIDDEN)
        
        student = request.user.student_profile
        
        # Get current and previous enrollments
        current_enrollments = []
        previous_enrollments = []
        
        enrollments = student.enrollments.all().order_by('-date_enrolled')
        
        for enrollment in enrollments:
            # Get attendance records for this enrollment
            attendance_records = enrollment.attendances.all().order_by('-date')
            
            enrollment_data = {
                'id': enrollment.id,
                'batch_name': enrollment.batch.name,
                'sport_name': enrollment.batch.sport.name,
                'enrollment_type': enrollment.enrollment_type,
                'total_sessions': enrollment.total_sessions or 0,
                'sessions_attended': enrollment.sessions_attended or 0,
                'sessions_remaining': (enrollment.total_sessions or 0) - (enrollment.sessions_attended or 0),
                'start_date': enrollment.start_date.isoformat() if enrollment.start_date else None,
                'end_date': enrollment.end_date.isoformat() if enrollment.end_date else None,
                'date_enrolled': enrollment.date_enrolled.isoformat() if enrollment.date_enrolled else None,
                'is_active': enrollment.is_active,
                'enrollment_started': enrollment.enrollment_started,
                'payment_policy': enrollment.batch.payment_policy,
                'fee_per_session': float(enrollment.batch.fee_per_session) if enrollment.batch.fee_per_session else None,
                'enrollment_cycle': {
                    'start': enrollment.start_date.isoformat() if enrollment.start_date else 'Not Started',
                    'end': enrollment.end_date.isoformat() if enrollment.end_date else 'Ongoing',
                    'status': 'Active' if enrollment.is_active else 'Inactive'
                },
                'session_records': [
                    {
                        'id': att.id,
                        'date': att.date.isoformat(),
                        'marked_by': str(att.marked_by) if att.marked_by else 'Unknown',
                        'timestamp': att.timestamp.isoformat() if att.timestamp else None,
                    }
                    for att in attendance_records
                ]
            }
            
            if enrollment.is_active:
                current_enrollments.append(enrollment_data)
            else:
                previous_enrollments.append(enrollment_data)
        
        # Calculate dashboard summary
        total_current_sessions = sum(e['total_sessions'] for e in current_enrollments)
        total_attended_sessions = sum(e['sessions_attended'] for e in current_enrollments)
        total_remaining_sessions = sum(e['sessions_remaining'] for e in current_enrollments)
        
        # Create enrollment cycle string
        enrollment_cycle = 'N/A'
        if current_enrollments:
            first_enrollment = current_enrollments[0]
            start_date = first_enrollment.get('start_date', 'Not Started')
            end_date = first_enrollment.get('end_date', 'Ongoing')
            enrollment_cycle = f"{start_date} to {end_date}"
        
        # Create current enrollment string
        current_enrollment = 'No Active Enrollment'
        if current_enrollments:
            first_enrollment = current_enrollments[0]
            current_enrollment = f"{first_enrollment['batch_name']} ({first_enrollment['sport_name']})"
        
        dashboard_data = {
            'current_enrollment': current_enrollment,
            'sessions_completed': total_attended_sessions,
            'sessions_remaining': total_remaining_sessions,
            'enrollment_cycle': enrollment_cycle,
            'current_enrollments': current_enrollments,
            'previous_enrollments': previous_enrollments,
            'recent_attendance': [],  # We'll populate this separately if needed
            'summary': {
                'total_current_enrollments': len(current_enrollments),
                'total_sessions': total_current_sessions,
                'sessions_attended': total_attended_sessions,
                'sessions_remaining': total_remaining_sessions,
                'completion_percentage': (total_attended_sessions / total_current_sessions * 100) if total_current_sessions > 0 else 0,
            }
        }
        
        return Response(dashboard_data, status=status.HTTP_200_OK)


class StudentAttendanceView(APIView):
    """
    API endpoint for student attendance records.
    """
    permission_classes = [IsAuthenticated]

    def get(self, request):
        # Ensure user is a student
        if not hasattr(request.user, 'student_profile'):
            return Response({'error': 'Access denied. Student profile required.'}, status=status.HTTP_403_FORBIDDEN)
        
        student = request.user.student_profile
        
        # Get attendance records as a flat list
        attendance_records = []
        
        for enrollment in student.enrollments.all():
            attendances = enrollment.attendances.all().order_by('-date')
            for att in attendances:
                attendance_records.append({
                    'id': att.id,
                    'enrollment': enrollment.id,
                    'batch': enrollment.batch.id,
                    'student': student.id,
                    'organization': student.organization.id,
                    'date': att.date.isoformat(),
                    'is_present': True,  # All attendance records are present by default
                    'timestamp': att.timestamp.isoformat() if att.timestamp else None,
                    'marked_by': str(att.marked_by) if att.marked_by else 'Unknown',
                })
        
        return Response(attendance_records, status=status.HTTP_200_OK)


class StudentPaymentsView(APIView):
    """
    API endpoint for student payment information.
    """
    permission_classes = [IsAuthenticated]

    def get(self, request):
        # Ensure user is a student
        if not hasattr(request.user, 'student_profile'):
            return Response({'error': 'Access denied. Student profile required.'}, status=status.HTTP_403_FORBIDDEN)
        
        student = request.user.student_profile
        
        # Get payment transactions
        from payments.models import FeeTransaction
        transactions = FeeTransaction.objects.filter(student=student).order_by('-transaction_date')
        
        payment_data = {
            'transactions': [
                {
                    'id': txn.id,
                    'amount': float(txn.amount),
                    'is_paid': txn.is_paid,
                    'due_date': txn.due_date,
                    'transaction_date': txn.transaction_date,
                    'payment_method': txn.payment_method,
                    'receipt_number': txn.receipt_number,
                    'enrollment_id': txn.enrollment.id if txn.enrollment else None,
                    'batch_name': txn.enrollment.batch.name if txn.enrollment else 'N/A',
                }
                for txn in transactions
            ],
            'summary': {
                'total_paid': float(transactions.filter(is_paid=True).aggregate(total=Sum('amount'))['total'] or 0),
                'total_due': float(transactions.filter(is_paid=False).aggregate(total=Sum('amount'))['total'] or 0),
                'total_transactions': transactions.count(),
            }
        }
        
        return Response(payment_data, status=status.HTTP_200_OK)


class StudentPaymentSummaryView(APIView):
    """
    API endpoint for student payment summary.
    """
    permission_classes = [IsAuthenticated]

    def get(self, request):
        # Ensure user is a student
        if not hasattr(request.user, 'student_profile'):
            return Response({'error': 'Access denied. Student profile required.'}, status=status.HTTP_403_FORBIDDEN)
        
        student = request.user.student_profile
        
        # Get payment summary
        from payments.models import FeeTransaction
        from django.db.models import Sum
        
        transactions = FeeTransaction.objects.filter(student=student)
        
        summary = {
            'total_paid': float(transactions.filter(is_paid=True).aggregate(total=Sum('amount'))['total'] or 0),
            'total_due': float(transactions.filter(is_paid=False).aggregate(total=Sum('amount'))['total'] or 0),
            'total_transactions': transactions.count(),
            'paid_transactions': transactions.filter(is_paid=True).count(),
            'pending_transactions': transactions.filter(is_paid=False).count(),
        }
        
        return Response(summary, status=status.HTTP_200_OK)


class StudentProfileUpdateView(APIView):
    """
    API endpoint for updating student profile information.
    """
    permission_classes = [IsAuthenticated]

    def get(self, request):
        # Ensure user is a student
        if not hasattr(request.user, 'student_profile'):
            return Response({'error': 'Access denied. Student profile required.'}, status=status.HTTP_403_FORBIDDEN)
        
        student = request.user.student_profile
        
        profile_data = {
            'id': student.id,
            'username': request.user.username,  # From CustomUser (for authentication)
            'first_name': student.first_name,
            'last_name': student.last_name,
            'email': student.email,
            'phone_number': student.phone_number,
            'date_of_birth': student.date_of_birth.isoformat() if student.date_of_birth else None,
            'gender': student.gender,
            'user_type': request.user.user_type,  # From CustomUser (for authentication)
            'address': student.address,
            'parent_name': student.parent_name,
            'parent_phone_number': student.parent_phone_number,
            'parent_email': student.parent_email,
            'profile_photo': f"{request.build_absolute_uri('/')[:-1]}{student.profile_photo.url}" if student.profile_photo else None,
            'organization': {
                'id': student.organization.id,
                'academy_name': student.organization.academy_name,
            } if student.organization else None,
        }
        
        return Response(profile_data, status=status.HTTP_200_OK)

    def put(self, request):
        # Ensure user is a student
        if not hasattr(request.user, 'student_profile'):
            return Response({'error': 'Access denied. Student profile required.'}, status=status.HTTP_403_FORBIDDEN)
        
        student = request.user.student_profile
        
        print(f"🔧 Backend: Updating profile for student {student.id}")
        print(f"🔧 Backend: Received data: {request.data}")
        print(f"🔧 Backend: Current student data before update:")
        print(f"🔧 Backend: - first_name: {student.first_name}")
        print(f"🔧 Backend: - last_name: {student.last_name}")
        print(f"🔧 Backend: - email: {request.user.email}")
        
        try:
            # Update only StudentProfile fields (single source of truth)
            if 'first_name' in request.data:
                print(f"🔧 Backend: Updating first_name from {student.first_name} to {request.data['first_name']}")
                student.first_name = request.data['first_name']
            if 'last_name' in request.data:
                print(f"🔧 Backend: Updating last_name from {student.last_name} to {request.data['last_name']}")
                student.last_name = request.data['last_name']
            if 'email' in request.data:
                print(f"🔧 Backend: Updating email from {student.email} to {request.data['email']}")
                student.email = request.data['email']
            if 'phone_number' in request.data:
                print(f"🔧 Backend: Updating phone_number from {student.phone_number} to {request.data['phone_number']}")
                student.phone_number = request.data['phone_number']
            if 'date_of_birth' in request.data:
                from datetime import datetime
                print(f"🔧 Backend: Updating date_of_birth from {student.date_of_birth} to {request.data['date_of_birth']}")
                student.date_of_birth = datetime.strptime(request.data['date_of_birth'], '%Y-%m-%d').date()
            if 'address' in request.data:
                print(f"🔧 Backend: Updating address from {student.address} to {request.data['address']}")
                student.address = request.data['address']
            if 'gender' in request.data:
                print(f"🔧 Backend: Updating gender from {student.gender} to {request.data['gender']}")
                student.gender = request.data['gender']
            if 'parent_name' in request.data:
                print(f"🔧 Backend: Updating parent_name from {student.parent_name} to {request.data['parent_name']}")
                student.parent_name = request.data['parent_name']
            if 'parent_phone_number' in request.data:
                print(f"🔧 Backend: Updating parent_phone_number from {student.parent_phone_number} to {request.data['parent_phone_number']}")
                student.parent_phone_number = request.data['parent_phone_number']
            if 'parent_email' in request.data:
                print(f"🔧 Backend: Updating parent_email from {student.parent_email} to {request.data['parent_email']}")
                student.parent_email = request.data['parent_email']
            
            print(f"🔧 Backend: Saving StudentProfile...")
            student.save()
            print(f"🔧 Backend: StudentProfile saved successfully")
            
            # Verify the update
            student.refresh_from_db()
            print(f"🔧 Backend: After save verification:")
            print(f"🔧 Backend: StudentProfile - first_name: {student.first_name}")
            print(f"🔧 Backend: StudentProfile - last_name: {student.last_name}")
            print(f"🔧 Backend: StudentProfile - email: {student.email}")
            
            # Return updated profile data (using only StudentProfile data)
            profile_data = {
                'id': student.id,
                'username': request.user.username,  # From CustomUser (for authentication)
                'first_name': student.first_name,
                'last_name': student.last_name,
                'email': student.email,
                'phone_number': student.phone_number,
                'date_of_birth': student.date_of_birth.isoformat() if student.date_of_birth else None,
                'gender': student.gender,
                'user_type': request.user.user_type,  # From CustomUser (for authentication)
                'address': student.address,
                'parent_name': student.parent_name,
                'parent_phone_number': student.parent_phone_number,
                'parent_email': student.parent_email,
                'profile_photo': f"{request.build_absolute_uri('/')[:-1]}{student.profile_photo.url}" if student.profile_photo else None,
                'organization': {
                    'id': student.organization.id,
                    'academy_name': student.organization.academy_name,
                } if student.organization else None,
            }
            
            print(f"🔧 Backend: Returning profile data: {profile_data}")
            return Response(profile_data, status=status.HTTP_200_OK)
            
        except Exception as e:
            print(f"🔧 Backend: Error updating profile: {str(e)}")
            return Response({'error': f'Error updating profile: {str(e)}'}, status=status.HTTP_400_BAD_REQUEST)


class StudentProfileDebugView(APIView):
    """
    Debug endpoint to check current student profile data in database
    """
    permission_classes = [IsAuthenticated]

    def get(self, request):
        # Ensure user is a student
        if not hasattr(request.user, 'student_profile'):
            return Response({'error': 'Access denied. Student profile required.'}, status=status.HTTP_403_FORBIDDEN)
        
        student = request.user.student_profile
        
        # Get fresh data from database
        from django.db import connection
        with connection.cursor() as cursor:
            cursor.execute("SELECT first_name, last_name, email, phone_number, address, gender, parent_name, parent_phone_number, parent_email FROM accounts_studentprofile WHERE id = %s", [student.id])
            db_data = cursor.fetchone()
        
        debug_data = {
            'student_id': student.id,
            'django_orm_data': {
                'first_name': student.first_name,
                'last_name': student.last_name,
                'email': request.user.email,
                'phone_number': student.phone_number,
                'address': student.address,
                'gender': student.gender,
                'parent_name': student.parent_name,
                'parent_phone_number': student.parent_phone_number,
                'parent_email': student.parent_email,
            },
            'raw_db_data': {
                'first_name': db_data[0] if db_data else None,
                'last_name': db_data[1] if db_data else None,
                'email': db_data[2] if db_data else None,
                'phone_number': db_data[3] if db_data else None,
                'address': db_data[4] if db_data else None,
                'gender': db_data[5] if db_data else None,
                'parent_name': db_data[6] if db_data else None,
                'parent_phone_number': db_data[7] if db_data else None,
                'parent_email': db_data[8] if db_data else None,
            }
        }
        
        return Response(debug_data, status=status.HTTP_200_OK)


class StudentProfilePhotoUploadView(APIView):
    """
    API endpoint for uploading student profile photo.
    """
    permission_classes = [IsAuthenticated]

    def post(self, request):
        # Ensure user is a student
        if not hasattr(request.user, 'student_profile'):
            return Response({'error': 'Access denied. Student profile required.'}, status=status.HTTP_403_FORBIDDEN)
        
        student = request.user.student_profile
        
        print(f"📸 Backend: Photo upload request for student {student.id}")
        print(f"📸 Backend: Request FILES: {request.FILES}")
        print(f"📸 Backend: Request data: {request.data}")
        
        try:
            if 'profile_photo' not in request.FILES:
                print("📸 Backend: No profile_photo in request.FILES")
                return Response({'error': 'No profile photo provided'}, status=status.HTTP_400_BAD_REQUEST)
            
            profile_photo = request.FILES['profile_photo']
            print(f"📸 Backend: Received file: {profile_photo.name}")
            print(f"📸 Backend: File size: {profile_photo.size} bytes")
            print(f"📸 Backend: File content type: {profile_photo.content_type}")
            
            # Validate file type
            allowed_types = ['image/jpeg', 'image/png', 'image/gif', 'application/octet-stream']
            file_extension = profile_photo.name.lower().split('.')[-1] if '.' in profile_photo.name else ''
            allowed_extensions = ['jpg', 'jpeg', 'png', 'gif']
            
            print(f"📸 Backend: File extension: {file_extension}")
            
            # Check both content type and file extension
            if (profile_photo.content_type not in allowed_types and 
                file_extension not in allowed_extensions):
                print(f"📸 Backend: Invalid file type: {profile_photo.content_type}, extension: {file_extension}")
                return Response({'error': 'Invalid file type. Only JPEG, PNG, and GIF are allowed.'}, status=status.HTTP_400_BAD_REQUEST)
            
            # Validate file size (max 5MB)
            if profile_photo.size > 5 * 1024 * 1024:
                print(f"📸 Backend: File too large: {profile_photo.size} bytes")
                return Response({'error': 'File too large. Maximum size is 5MB.'}, status=status.HTTP_400_BAD_REQUEST)
            
            print(f"📸 Backend: Current profile_photo before save: {student.profile_photo}")
            
            # Save the photo
            print(f"📸 Backend: Setting profile_photo to: {profile_photo}")
            student.profile_photo = profile_photo
            print(f"📸 Backend: About to save student profile...")
            student.save()
            
            print(f"📸 Backend: Profile saved successfully")
            
            # Refresh from database to get the latest data
            student.refresh_from_db()
            print(f"📸 Backend: New profile_photo after save: {student.profile_photo}")
            print(f"📸 Backend: Profile photo URL: {student.profile_photo.url if student.profile_photo else 'None'}")
            
            # Check if file actually exists
            if student.profile_photo:
                import os
                file_path = student.profile_photo.path
                print(f"📸 Backend: File path: {file_path}")
                print(f"📸 Backend: File exists: {os.path.exists(file_path)}")
                if os.path.exists(file_path):
                    print(f"📸 Backend: File size on disk: {os.path.getsize(file_path)} bytes")
                else:
                    print(f"📸 Backend: ERROR - File does not exist on disk!")
            else:
                print(f"📸 Backend: ERROR - profile_photo is None after save!")
            
            # Get the full URL for the profile photo
            photo_url = None
            if student.profile_photo:
                # Build the full URL
                photo_url = f"{request.build_absolute_uri('/')[:-1]}{student.profile_photo.url}"
                print(f"📸 Backend: Full photo URL: {photo_url}")
            
            return Response({
                'profile_photo': photo_url,
                'message': 'Profile photo uploaded successfully'
            }, status=status.HTTP_200_OK)
            
        except Exception as e:
            print(f"📸 Backend: Error uploading photo: {str(e)}")
            import traceback
            print(f"📸 Backend: Traceback: {traceback.format_exc()}")
            return Response({'error': f'Error uploading photo: {str(e)}'}, status=status.HTTP_400_BAD_REQUEST)


class StudentFaceEncodingView(APIView):
    """
    API endpoint for students to generate and store their face encoding.
    """
    permission_classes = [IsAuthenticated]

    def post(self, request):
        # Ensure user is a student
        if not hasattr(request.user, 'student_profile'):
            return Response({'error': 'Access denied. Student profile required.'}, status=status.HTTP_403_FORBIDDEN)
        
        student = request.user.student_profile
        
        try:
            if 'face_image' not in request.FILES:
                return Response({'error': 'No face image provided'}, status=status.HTTP_400_BAD_REQUEST)
            
            face_image = request.FILES['face_image']
            
            print(f"🔍 Backend: Generating face encoding for student {student.first_name} {student.last_name}")
            
            # Extract face encoding
            from .facial_recognition import extract_embedding_from_bytes
            face_encoding = extract_embedding_from_bytes(face_image.read())
            
            if face_encoding is None:
                return Response({'error': 'No face detected in image. Please ensure your face is clearly visible.'}, status=status.HTTP_400_BAD_REQUEST)
            
            # Store encoding as JSON string
            import json
            student.face_encoding = json.dumps(face_encoding.tolist())
            student.save()
            
            print(f"🔍 Backend: Face encoding generated and stored for student {student.id}")
            
            return Response({
                'message': 'Face encoding generated successfully',
                'encoding_length': len(face_encoding),
                'student_id': student.id,
                'student_name': f"{student.first_name} {student.last_name}"
            }, status=status.HTTP_200_OK)
            
        except Exception as e:
            print(f"🔍 Backend: Face encoding error: {str(e)}")
            import traceback
            print(f"🔍 Backend: Traceback: {traceback.format_exc()}")
            return Response({'error': f'Face encoding error: {str(e)}'}, status=status.HTTP_400_BAD_REQUEST)


class TrainFaceRecognitionModelView(APIView):
    """
    API endpoint for academy admins to train the face recognition model.
    """
    permission_classes = [IsAuthenticated]

    def post(self, request):
        # Ensure user is an academy admin
        if request.user.user_type != 'ACADEMY_ADMIN':
            return Response({'error': 'Access denied. Academy admin required.'}, status=status.HTTP_403_FORBIDDEN)
        
        admin_profile = request.user.academy_admin_profile
        organization = admin_profile.organization
        
        try:
            print(f"🧠 Backend: Training face recognition model for organization {organization.id}")
            
            from .facial_recognition import train_model_for_organization
            success = train_model_for_organization(organization)
            
            if success:
                return Response({
                    'message': 'Face recognition model trained successfully',
                    'organization_id': organization.id,
                    'organization_name': organization.academy_name
                }, status=status.HTTP_200_OK)
            else:
                return Response({'error': 'Failed to train model. Ensure students have face encodings.'}, status=status.HTTP_400_BAD_REQUEST)
                
        except Exception as e:
            print(f"🧠 Backend: Model training error: {str(e)}")
            import traceback
            print(f"🧠 Backend: Traceback: {traceback.format_exc()}")
            return Response({'error': f'Model training error: {str(e)}'}, status=status.HTTP_400_BAD_REQUEST)
        


class FaceRecognitionAttendanceView(APIView):
    """
    API endpoint for academy admins to mark attendance using face recognition.
    """
    permission_classes = [IsAuthenticated]

    def post(self, request):
        # Ensure user is an academy admin
        if request.user.user_type != 'ACADEMY_ADMIN':
            return Response({'error': 'Access denied. Academy admin required.'}, status=status.HTTP_403_FORBIDDEN)
        
        admin_profile = request.user.academy_admin_profile
        organization = admin_profile.organization
        
        try:
            if 'captured_image' not in request.FILES:
                return Response({'error': 'No captured image provided'}, status=status.HTTP_400_BAD_REQUEST)
            
            captured_image = request.FILES['captured_image']
            date = request.data.get('date')  # Optional, defaults to today
            
            if not date:
                from datetime import date
                date = date.today().isoformat()
            
            print(f"📸 Backend: Face recognition attendance for organization {organization.id} on {date}")
            
            # Recognize student from image
            from .facial_recognition import recognize_student_from_image, train_model_for_organization
            student, confidence = recognize_student_from_image(captured_image.read(), organization)
            
            if student is None:
                # If no student recognized, try auto-training and retry
                print(f"📸 Backend: No student recognized. Attempting auto-training...")
                
                try:
                    # Auto-train the model
                    train_result = train_model_for_organization(organization)
                    print(f"📸 Backend: Auto-training result: {train_result}")
                    
                    # Try recognition again after training
                    student, confidence = recognize_student_from_image(captured_image.read(), organization)
                    
                    if student is None:
                        return Response({
                            'recognized': False,
                            'confidence': 0.0,
                            'message': 'No student recognized even after auto-training. Please ensure the student has registered their face using the "Face Attendance" option in the student app, then try again.'
                        }, status=status.HTTP_200_OK)
                    else:
                        print(f"📸 Backend: Student recognized after auto-training: {student.first_name} {student.last_name}")
                
                except Exception as train_error:
                    print(f"📸 Backend: Auto-training failed: {str(train_error)}")
                    return Response({
                        'recognized': False,
                        'confidence': 0.0,
                        'message': 'No student recognized. Please ensure face is clearly visible and student has registered their face.'
                    }, status=status.HTTP_200_OK)
            
            # Mark attendance for the recognized student
            attendance_result = self._mark_attendance_for_student(student, date, request.user)
            
            if attendance_result:
                return Response({
                    'recognized': True,
                    'student': {
                        'id': student.id,
                        'first_name': student.first_name,
                        'last_name': student.last_name,
                        'email': student.email,
                    },
                    'confidence': confidence,
                    'attendance': attendance_result,
                    'message': f'✅ Attendance automatically marked for {student.first_name} {student.last_name}'
                }, status=status.HTTP_200_OK)
            else:
                return Response({
                    'recognized': True,
                    'student': {
                        'id': student.id,
                        'first_name': student.first_name,
                        'last_name': student.last_name,
                        'email': student.email,
                    },
                    'confidence': confidence,
                    'attendance': None,
                    'message': f'Student {student.first_name} {student.last_name} recognized but has no active enrollments. Please enroll the student in a batch first.'
                }, status=status.HTTP_200_OK)
                
        except Exception as e:
            print(f"📸 Backend: Face recognition attendance error: {str(e)}")
            import traceback
            print(f"📸 Backend: Traceback: {traceback.format_exc()}")
            return Response({'error': f'Face recognition attendance error: {str(e)}'}, status=status.HTTP_400_BAD_REQUEST)
    
    def _mark_attendance_for_student(self, student, date, marked_by):
        """
        Mark attendance for the recognized student using the existing attendance system.
        """
        try:
            from organizations.models import Attendance, Enrollment
            from datetime import datetime
            
            # Get active enrollments for this student
            enrollments = Enrollment.objects.filter(
                student=student,
                organization=student.organization,
                is_active=True
            )
            
            if not enrollments.exists():
                print(f"📸 Backend: No active enrollments found for student {student.id}")
                # Check if student has any enrollments at all
                all_enrollments = Enrollment.objects.filter(
                    student=student,
                    organization=student.organization
                )
                if all_enrollments.exists():
                    print(f"📸 Backend: Student {student.id} has {all_enrollments.count()} enrollments but none are active")
                else:
                    print(f"📸 Backend: Student {student.id} has no enrollments at all")
                return None
            
            attendance_results = []
            
            for enrollment in enrollments:
                # Use the existing attendance system - create attendance record
                # The presence is implied by the existence of the record
                attendance, created = Attendance.objects.get_or_create(
                    enrollment=enrollment,
                    date=date,
                    defaults={
                        'batch': enrollment.batch,
                        'student': student,
                        'organization': student.organization,
                        'marked_by': marked_by,
                        'is_session_deducted': False  # Will be set to True by the save() method
                    }
                )
                
                if not created:
                    # Update existing attendance - just update who marked it
                    attendance.marked_by = marked_by
                    attendance.save()
                
                # The save() method in Attendance model will handle:
                # - Session deduction for SESSION_BASED enrollments
                # - Fee transaction creation for POST_PAID batches
                # - Enrollment completion checking
                
                attendance_results.append({
                    'enrollment_id': enrollment.id,
                    'batch_name': enrollment.batch.name if enrollment.batch else 'N/A',
                    'attendance_id': attendance.id,
                    'is_present': True,  # Always true since we're creating the record
                    'created': created,
                    'sessions_attended': enrollment.sessions_attended,
                    'total_sessions': enrollment.total_sessions
                })
            
            return attendance_results
            
        except Exception as e:
            print(f"📸 Backend: Error marking attendance: {str(e)}")
            import traceback
            print(f"📸 Backend: Traceback: {traceback.format_exc()}")
            return None