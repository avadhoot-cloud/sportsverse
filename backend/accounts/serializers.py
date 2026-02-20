# sportsverse/backend/accounts/serializers.py

from rest_framework import serializers
from django.db import transaction
from django.contrib.auth import authenticate
from django.contrib.auth.password_validation import validate_password
from django.core.exceptions import ValidationError as DjangoValidationError
from payments.models import FeeTransaction
from .models import CustomUser, AcademyAdminProfile,  StudentProfile
from organizations.models import Organization, Sport, Branch, Batch, Enrollment # Import necessary models

class StudentFeeSerializer(serializers.ModelSerializer):
    class Meta:
        model = FeeTransaction
        fields = '__all__'

class UserSerializer(serializers.ModelSerializer):
    """Serializer for the CustomUser model."""
    class Meta:
        model = CustomUser
        fields = ['id', 'username', 'email', 'first_name', 'last_name', 'phone_number', 'gender', 'date_of_birth', 'user_type']
        read_only_fields = ['id', 'user_type'] # User type is set during creation, not by user directly

class StudentFinancialsSerializer(serializers.Serializer):
    """
    Serializer for summarizing a student's financial status.
    """
    total_paid = serializers.DecimalField(max_digits=10, decimal_places=2)
    total_due = serializers.DecimalField(max_digits=10, decimal_places=2)

class StudentListSerializer(serializers.ModelSerializer):
    """
    Serializer for listing students in the academy.
    """
    full_name = serializers.CharField(source='get_full_name', read_only=True)

    class Meta:
        model = StudentProfile
        fields = ['id', 'full_name']

class RegisterAcademySerializer(serializers.Serializer):
    """
    Serializer for registering a new Organization and its Academy Admin.
    This is used by the Platform Admin or a public registration page.
    """
    # Organization fields
    organization_full_name = serializers.CharField(max_length=255, write_only=True, help_text="Legal name of the academy/organization")
    organization_academy_name = serializers.CharField(max_length=255, write_only=True, help_text="Display name for the academy")
    organization_location = serializers.CharField(style={'base_template': 'textarea.html'}, write_only=True, help_text="Physical address of the academy")
    organization_mobile_number = serializers.CharField(max_length=20, write_only=True, help_text="Official contact number for the academy")
    organization_email_address = serializers.EmailField(write_only=True, help_text="Official business email for the academy (e.g., info@youracademy.com)")
    organization_slug = serializers.SlugField(max_length=100, write_only=True, help_text="URL identifier (e.g., 'elite-tennis' for elite-tennis.sportsverse.com)")
    sports_offered_ids = serializers.ListField(
        child=serializers.IntegerField(), write_only=True,
        help_text="List of Sport IDs that this organization offers."
    )
    # Admin user fields for the new academy
    admin_username = serializers.CharField(max_length=150, write_only=True, help_text="Username for the academy admin to login")
    admin_email = serializers.EmailField(write_only=True, required=False, allow_blank=True, help_text="Personal email of the admin user (optional - if not provided, organization email will be used)")
    admin_first_name = serializers.CharField(max_length=150, write_only=True, help_text="First name of the admin user")
    admin_last_name = serializers.CharField(max_length=150, write_only=True, help_text="Last name of the admin user")
    admin_password = serializers.CharField(write_only=True, style={'input_type': 'password'}, help_text="Password for the admin user account")

    def validate_organization_email_address(self, value):
        if Organization.objects.filter(email_address=value).exists():
            raise serializers.ValidationError("An organization with this email already exists.")
        return value

    def validate_organization_slug(self, value):
        if Organization.objects.filter(slug=value).exists():
            raise serializers.ValidationError("This academy URL identifier is already taken.")
        return value

    def validate_admin_username(self, value):
        if CustomUser.objects.filter(username=value).exists():
            raise serializers.ValidationError("This username is already taken.")
        return value

    def validate_admin_email(self, value):
        # If admin email is provided and not empty
        if value:
            # Get organization email from the data
            org_email = self.initial_data.get('organization_email_address')
            
            # Allow admin email to be the same as organization email
            if value != org_email and CustomUser.objects.filter(email=value).exists():
                raise serializers.ValidationError("A user with this email already exists.")
        return value

    def validate_admin_password(self, value):
        try:
            validate_password(value)
        except DjangoValidationError as e:
            raise serializers.ValidationError(list(e.messages))
        return value

    def create(self, validated_data):
        with transaction.atomic():
            # Create Organization
            organization = Organization.objects.create(
                full_name=validated_data['organization_full_name'],
                academy_name=validated_data['organization_academy_name'],
                location=validated_data['organization_location'],
                mobile_number=validated_data['organization_mobile_number'],
                email_address=validated_data['organization_email_address'],
                slug=validated_data['organization_slug'],
                is_active=True, # New academies are active by default
                subscription_plan='FREE_TRIAL' # Default to free trial
            )
            # Add sports offered
            sports_ids = validated_data.get('sports_offered_ids', [])
            sports = Sport.objects.filter(id__in=sports_ids)
            organization.sports_offered.set(sports)

            # Create Academy Admin User
            # Use organization email if admin email is not provided
            admin_email = validated_data.get('admin_email') or validated_data['organization_email_address']
            
            admin_user = CustomUser.objects.create_user(
                username=validated_data['admin_username'],
                email=admin_email,
                password=validated_data['admin_password'],
                first_name=validated_data['admin_first_name'],
                last_name=validated_data['admin_last_name'],
                user_type='ACADEMY_ADMIN',
                is_staff=True # Academy admins can access their part of Django admin
            )
            # Create Academy Admin Profile
            AcademyAdminProfile.objects.create(user=admin_user, organization=organization)

        return organization

from rest_framework import serializers
from django.contrib.auth import authenticate
from django.contrib.auth import get_user_model

User = get_user_model()

class LoginSerializer(serializers.Serializer):
    username = serializers.CharField()
    password = serializers.CharField(write_only=True)

    def validate(self, data):
        username_input = data.get('username')
        password = data.get('password')

        if username_input and password:
            # 1. Look for the user in the database
            user_obj = User.objects.filter(email=username_input).first()
            if not user_obj:
                user_obj = User.objects.filter(username=username_input).first()

            if user_obj:
                # DEBUG: Check if user was found
                print(f"DEBUG: Found User in DB: {user_obj.username}")
                
                # 2. Check if the password is correct
                user = authenticate(username=user_obj.username, password=password)
                
                if not user:
                    # DEBUG: Password failed
                    print(f"DEBUG: Password authentication failed for: {user_obj.username}")
                    raise serializers.ValidationError("Invalid password.")
            else:
                # DEBUG: Email/Username not found
                print(f"DEBUG: No user found with email/username: {username_input}")
                raise serializers.ValidationError("User does not exist.")

            # If user is inactive, they can't login
            if not user.is_active:
                raise serializers.ValidationError("This account is disabled.")
        else:
            raise serializers.ValidationError("Must include both username and password.")

        data['user'] = user
        return data

