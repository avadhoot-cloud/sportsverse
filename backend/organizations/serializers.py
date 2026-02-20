# sportsverse/backend/organizations/serializers.py

from rest_framework import serializers
from .models import Organization, Sport, Branch, Batch, Enrollment, Attendance
from accounts.models import StudentProfile

class OrganizationSerializer(serializers.ModelSerializer):
    sports_offered = serializers.PrimaryKeyRelatedField(many=True, read_only=True) # Or use a nested serializer if you want full sport objects

    class Meta:
        model = Organization
        fields = '__all__' # Adjust fields as needed for specific endpoints

class SportSerializer(serializers.ModelSerializer):
    class Meta:
        model = Sport
        fields = ['id', 'name',  'icon'] # 'icon' will be the URL of the image

class BranchSerializer(serializers.ModelSerializer):
    """
    Serializer for Branch model.
    Used by Academy Admins to manage their branches/centers.
    """
    organization_name = serializers.CharField(source='organization.academy_name', read_only=True)
    
    class Meta:
        model = Branch
        fields = ['id', 'name', 'address', 'is_active', 'organization_name']
        read_only_fields = ['id', 'organization_name']
    
    def validate_name(self, value):
        # Check if branch name is unique within the organization
        request = self.context.get('request')
        if request and hasattr(request.user, 'academy_admin_profile'):
            organization = request.user.academy_admin_profile.organization
            
            # For updates, exclude the current instance
            queryset = Branch.objects.filter(organization=organization, name=value)
            if self.instance:
                queryset = queryset.exclude(pk=self.instance.pk)
                
            if queryset.exists():
                raise serializers.ValidationError("A branch with this name already exists in your academy.")
        
        return value


class BatchSerializer(serializers.ModelSerializer):
    """
    Serializer for Batch model.
    Used by Academy Admins to manage batches within their organization.
    """
    organization_name = serializers.CharField(source='organization.academy_name', read_only=True)
    branch_name = serializers.CharField(source='branch.name', read_only=True)
    sport_name = serializers.CharField(source='sport.name', read_only=True)
    
    class Meta:
        model = Batch
        fields = ['id', 'name', 'branch', 'sport', 'schedule_details', 'max_students', 'is_active', 
                 'organization_name', 'branch_name', 'sport_name', 'fee_per_session', 'payment_policy']
        read_only_fields = ['id', 'organization_name', 'branch_name', 'sport_name']
    
    def validate_name(self, value):
        # Check if batch name is unique within the branch
        request = self.context.get('request')
        if request and hasattr(request.user, 'academy_admin_profile'):
            organization = request.user.academy_admin_profile.organization
            
            # For updates, exclude the current instance
            queryset = Batch.objects.filter(organization=organization, name=value)
            if self.instance:
                queryset = queryset.exclude(pk=self.instance.pk)
                
            if queryset.exists():
                raise serializers.ValidationError("A batch with this name already exists in your academy.")
        
        return value
    
    def validate_branch(self, value):
        # Ensure branch belongs to the admin's organization
        request = self.context.get('request')
        if request and hasattr(request.user, 'academy_admin_profile'):
            organization = request.user.academy_admin_profile.organization
            if value.organization != organization:
                raise serializers.ValidationError("You can only create batches in your own organization's branches.")
        return value
    
    def validate_schedule_details(self, value):
        # Basic validation for schedule format
        if not isinstance(value, dict):
            raise serializers.ValidationError("Schedule details must be a valid JSON object.")
        
        # Check for required fields
        required_fields = ['days', 'start_time', 'end_time']
        for field in required_fields:
            if field not in value:
                raise serializers.ValidationError(f"Schedule details must include '{field}'.")
        
        # Validate days format
        if not isinstance(value['days'], list) or not value['days']:
            raise serializers.ValidationError("Days must be a non-empty list.")
        
        valid_days = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun']
        for day in value['days']:
            if day not in valid_days:
                raise serializers.ValidationError(f"Invalid day: {day}. Use: {', '.join(valid_days)}")
        
        return value


class EnrollmentSerializer(serializers.ModelSerializer):
    """
    Serializer for Enrollment model.
    Used to enroll students in batches.
    """
    student_name = serializers.CharField(source='student.first_name', read_only=True)
    student_last_name = serializers.CharField(source='student.last_name', read_only=True)
    batch_name = serializers.CharField(source='batch.name', read_only=True)
    branch_name = serializers.CharField(source='batch.branch.name', read_only=True)
    organization_name = serializers.CharField(source='organization.academy_name', read_only=True)
    enrollment_status = serializers.SerializerMethodField()
    progress_display = serializers.SerializerMethodField()
    
    class Meta:
        model = Enrollment
        fields = ['id', 'student', 'batch', 'enrollment_type', 'start_date', 'end_date', 
                 'total_sessions', 'sessions_attended', 'is_active', 'date_enrolled',
                 'enrollment_started', 'date_first_attendance',
                 'student_name', 'student_last_name', 'batch_name', 'branch_name', 'organization_name',
                 'enrollment_status', 'progress_display']
        read_only_fields = ['id', 'sessions_attended', 'date_enrolled', 'organization_name',
                           'student_name', 'student_last_name', 'batch_name', 'branch_name',
                           'enrollment_started', 'date_first_attendance', 'start_date']
    
    def get_enrollment_status(self, obj):
        if not obj.enrollment_started:
            return 'Not Started'
        elif obj.enrollment_type == 'SESSION_BASED':
            if obj.sessions_attended >= obj.total_sessions:
                return 'Completed'
            return 'Active'
        elif obj.enrollment_type == 'DURATION_BASED':
            from datetime import date
            if obj.end_date and obj.end_date < date.today():
                return 'Expired'
            return 'Active'
        return 'Active'
    
    def get_progress_display(self, obj):
        if not obj.enrollment_started:
            return 'Enrollment pending first attendance'
        elif obj.enrollment_type == 'SESSION_BASED':
            return f"{obj.sessions_attended}/{obj.total_sessions} sessions"
        elif obj.enrollment_type == 'DURATION_BASED':
            if obj.start_date and obj.end_date:
                from datetime import date
                total_days = (obj.end_date - obj.start_date).days
                elapsed_days = (date.today() - obj.start_date).days
                return f"{elapsed_days}/{total_days} days"
            return 'Duration-based enrollment'
        return 'N/A'
    
    def validate_student(self, value):
        # Ensure student belongs to the admin's organization
        request = self.context.get('request')
        if request and hasattr(request.user, 'academy_admin_profile'):
            organization = request.user.academy_admin_profile.organization
            if value.organization != organization:
                raise serializers.ValidationError("You can only enroll students from your own organization.")
        return value
    
    def validate_batch(self, value):
        # Ensure batch belongs to the admin's organization
        request = self.context.get('request')
        if request and hasattr(request.user, 'academy_admin_profile'):
            organization = request.user.academy_admin_profile.organization
            if value.organization != organization:
                raise serializers.ValidationError("You can only enroll students in your own organization's batches.")
        return value
    
    def validate(self, attrs):
        # Check for duplicate enrollment
        student = attrs.get('student')
        batch = attrs.get('batch')
        
        if student and batch:
            # Check if student is already enrolled in this batch
            existing = Enrollment.objects.filter(student=student, batch=batch, is_active=True)
            if self.instance:
                existing = existing.exclude(pk=self.instance.pk)
            
            if existing.exists():
                raise serializers.ValidationError("Student is already enrolled in this batch.")
        
        # Validate session-based enrollment
        if attrs.get('enrollment_type') == 'SESSION_BASED':
            if not attrs.get('total_sessions'):
                raise serializers.ValidationError("Total sessions is required for session-based enrollment.")
        
        return attrs


class StudentProfileSerializer(serializers.ModelSerializer):
    """
    Serializer for StudentProfile model.
    Used for managing students within an organization.
    """
    full_name = serializers.SerializerMethodField()
    
    class Meta:
        model = StudentProfile
        fields = ['id', 'first_name', 'last_name', 'email', 'phone_number', 
                 'date_of_birth', 'address', 'gender', 'parent_name', 
                 'parent_phone_number', 'parent_email', 'full_name']
        read_only_fields = ['id', 'full_name']
    
    def get_full_name(self, obj):
        return f"{obj.first_name} {obj.last_name}"
    
    def create(self, validated_data):
        # Set organization from the admin's profile
        request = self.context.get('request')
        if request and hasattr(request.user, 'academy_admin_profile'):
            validated_data['organization'] = request.user.academy_admin_profile.organization
        return super().create(validated_data)


class StudentEnrollmentSerializer(serializers.Serializer):
    """
    Combined serializer for creating student with enrollment in one step.
    """
    # Student fields
    first_name = serializers.CharField(max_length=100)
    last_name = serializers.CharField(max_length=100)
    email = serializers.EmailField(required=False, allow_blank=True)
    phone_number = serializers.CharField(max_length=20, required=False, allow_blank=True)
    date_of_birth = serializers.DateField()
    address = serializers.CharField(required=False, allow_blank=True)
    gender = serializers.ChoiceField(choices=[('M', 'Male'), ('F', 'Female'), ('O', 'Other')], required=False)
    parent_name = serializers.CharField(max_length=200, required=False, allow_blank=True)
    parent_phone_number = serializers.CharField(max_length=20, required=False, allow_blank=True)
    parent_email = serializers.EmailField(required=False, allow_blank=True)
    
    # User account fields
    password = serializers.CharField(write_only=True, style={'input_type': 'password'})
    must_change_password = serializers.BooleanField(default=True)
    
    # Enrollment fields
    batch = serializers.PrimaryKeyRelatedField(queryset=Batch.objects.none())
    enrollment_type = serializers.ChoiceField(choices=Enrollment.ENROLLMENT_TYPE_CHOICES)
    total_sessions = serializers.IntegerField(required=False)
    end_date = serializers.DateField(required=False)
    
    def __init__(self, *args, **kwargs):
        super().__init__(*args, **kwargs)
        # Set queryset for batch field based on user's organization
        request = self.context.get('request')
        if request and hasattr(request.user, 'academy_admin_profile'):
            organization = request.user.academy_admin_profile.organization
            self.fields['batch'].queryset = Batch.objects.filter(organization=organization, is_active=True)
    
    def validate(self, attrs):
        # Validate enrollment type requirements
        if attrs.get('enrollment_type') == 'SESSION_BASED' and not attrs.get('total_sessions'):
            raise serializers.ValidationError("Total sessions is required for session-based enrollment.")
        
        # Validate email uniqueness if provided
        if attrs.get('email'):
            request = self.context.get('request')
            if request and hasattr(request.user, 'academy_admin_profile'):
                organization = request.user.academy_admin_profile.organization
                if StudentProfile.objects.filter(organization=organization, email=attrs['email']).exists():
                    raise serializers.ValidationError("A student with this email already exists in your organization.")
        
        return attrs
    
    def create(self, validated_data):
        from accounts.models import CustomUser
        from django.db import transaction
        
        request = self.context.get('request')
        if not (request and hasattr(request.user, 'academy_admin_profile')):
            raise serializers.ValidationError("Only academy admins can create student enrollments.")
        
        organization = request.user.academy_admin_profile.organization
        
        # Extract user account data
        password = validated_data.pop('password')
        must_change_password = validated_data.pop('must_change_password', True)
        
        # Extract enrollment data
        batch = validated_data.pop('batch')
        enrollment_type = validated_data.pop('enrollment_type')
        total_sessions = validated_data.pop('total_sessions', None)
        end_date = validated_data.pop('end_date', None)
        
        with transaction.atomic():
            # Create user account for student
            username = f"{validated_data['first_name'].lower()}.{validated_data['last_name'].lower()}"
            # Ensure unique username
            counter = 1
            original_username = username
            while CustomUser.objects.filter(username=username).exists():
                username = f"{original_username}{counter}"
                counter += 1
            
            user = CustomUser.objects.create_user(
                username=username,
                email=validated_data.get('email') or '',
                password=password,
                first_name=validated_data['first_name'],
                last_name=validated_data['last_name'],
                phone_number=validated_data.get('phone_number'),
                gender=validated_data.get('gender'),
                date_of_birth=validated_data['date_of_birth'],
                user_type='STUDENT',
                must_change_password=must_change_password
            )
            
            # Create student profile
            validated_data['organization'] = organization
            validated_data['user'] = user
            student = StudentProfile.objects.create(**validated_data)
            
            # Create enrollment (will start when first attendance is taken)
            enrollment_data = {
                'student': student,
                'batch': batch,
                'organization': organization,
                'enrollment_type': enrollment_type,
                'total_sessions': total_sessions,
                'end_date': end_date,
            }
            
            enrollment = Enrollment.objects.create(**enrollment_data)
            
            return {
                'student': student,
                'enrollment': enrollment,
                'user': user
            }


class AttendanceSerializer(serializers.ModelSerializer):
    """
    Serializer for Attendance model for reporting.
    """
    student_name = serializers.CharField(source='student.first_name', read_only=True)
    student_last_name = serializers.CharField(source='student.last_name', read_only=True)
    batch_name = serializers.CharField(source='batch.name', read_only=True)
    marked_by_name = serializers.CharField(source='marked_by.get_full_name', read_only=True)

    is_present = serializers.SerializerMethodField()

    class Meta:
        model = Attendance
        fields = [
            'id', 'date', 'is_present', 'enrollment', 'batch', 'student', 'organization',
            'student_name', 'student_last_name', 'batch_name', 'marked_by', 'marked_by_name',
            'timestamp', 'is_session_deducted'
        ]
        read_only_fields = [
            'id', 'organization', 'student', 'batch', 'marked_by',
            'student_name', 'student_last_name', 'batch_name', 'marked_by_name',
            'timestamp', 'is_session_deducted'
        ]

    def get_is_present(self, obj):
        # Presence is implied by existence of record
        return True