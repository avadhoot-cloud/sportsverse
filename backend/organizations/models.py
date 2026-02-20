# sportsverse/backend/organizations/models.py

from django.db import models

class Organization(models.Model):
    # This is your main Tenant model
    full_name = models.CharField(max_length=255, help_text="Full legal name of the organization/academy")
    academy_name = models.CharField(max_length=255, help_text="Commonly used display name")
    logo = models.ImageField(upload_to='academy_logos/', blank=True, null=True)
    location = models.TextField(blank=True, help_text="Full physical address of the primary location")
    mobile_number = models.CharField(max_length=20, blank=True)
    email_address = models.EmailField(unique=True)
    # Add a unique identifier for URL/subdomain if you plan that later (e.g., 'slug')
    slug = models.SlugField(max_length=100, unique=True, help_text="Unique identifier for URL, e.g., 'elite-tennis'")

    # --- MISSING LINE ADDED HERE ---
    sports_offered = models.ManyToManyField('Sport', related_name='organizations', blank=True)
    # --- END OF ADDED LINE ---

    # Status/Subscription fields (for future subscription model)
    is_active = models.BooleanField(default=True)
    subscription_plan = models.CharField(max_length=50, default='FREE_TRIAL',
                                         choices=[('FREE_TRIAL', 'Free Trial'), ('BASIC', 'Basic'), ('PREMIUM', 'Premium')])
    subscription_end_date = models.DateField(null=True, blank=True)
    date_joined = models.DateTimeField(auto_now_add=True)

    def __str__(self):
        return self.academy_name

class Sport(models.Model):
    # This model defines global sports types, not specific to an organization
    # Organizations will link to these
    name = models.CharField(max_length=100, unique=True)
   # description = models.TextField(blank=True, null=True)
    icon = models.ImageField(upload_to='sport_icons/', blank=True, null=True) # Optional icon

    def __str__(self):
        return self.name

class Branch(models.Model):
    organization = models.ForeignKey(Organization, on_delete=models.CASCADE, related_name='branches')
    name = models.CharField(max_length=200)
    address = models.TextField()
    is_active = models.BooleanField(default=True)

    def __str__(self):
        return f"{self.name} ({self.organization.academy_name})"

class Batch(models.Model):
    organization = models.ForeignKey(Organization, on_delete=models.CASCADE, related_name='batches')
    branch = models.ForeignKey(Branch, on_delete=models.CASCADE, related_name='batches')
    sport = models.ForeignKey(Sport, on_delete=models.CASCADE, related_name='batches')
    name = models.CharField(max_length=200)
    # Coaches can be assigned to a batch as a primary coach, or multiple via M2M
    # For simplicity, let's assume a main coach or multiple:
    # coach = models.ForeignKey('accounts.CoachProfile', on_delete=models.SET_NULL, null=True, blank=True, related_name='leading_batches')
    # coaches = models.ManyToManyField('accounts.CoachProfile', related_name='batches_assigned', blank=True) # More flexible
    
    # Schedule details: Monday, Wednesday 6 PM - 7 PM
    # A JSONField is flexible for varying schedules. Could also be a separate `Schedule` model.
    schedule_details = models.JSONField(default=dict, help_text="e.g., {'days': ['Mon', 'Wed'], 'start_time': '18:00', 'end_time': '19:00'}")
    max_students = models.IntegerField(default=20)
    is_active = models.BooleanField(default=True)

    # Fee structure
    PAYMENT_POLICY_CHOICES = (
        ('PRE_PAID', 'Pre-paid'),
        ('POST_PAID', 'Post-paid'),
    )
    fee_per_session = models.DecimalField(max_digits=10, decimal_places=2, null=True, blank=True)
    payment_policy = models.CharField(max_length=20, choices=PAYMENT_POLICY_CHOICES, default='POST_PAID')

    def __str__(self):
        return f"{self.name} - {self.sport.name} at {self.branch.name} ({self.organization.academy_name})"

class Enrollment(models.Model):
    ENROLLMENT_TYPE_CHOICES = (
        ('SESSION_BASED', 'Session Based'),
        ('DURATION_BASED', 'Duration Based'), # Monthly, Quarterly, etc.
    )
    student = models.ForeignKey('accounts.StudentProfile', on_delete=models.CASCADE, related_name='enrollments')
    batch = models.ForeignKey(Batch, on_delete=models.CASCADE, related_name='enrollments')
    organization = models.ForeignKey(Organization, on_delete=models.CASCADE, related_name='enrollments') # Denormalized for easier filtering

    enrollment_type = models.CharField(max_length=20, choices=ENROLLMENT_TYPE_CHOICES)

    # Fields for DURATION_BASED enrollment
    start_date = models.DateField(null=True, blank=True) # Will be set when first attendance is taken
    end_date = models.DateField(null=True, blank=True) # Auto-calculated for duration-based

    # Fields for SESSION_BASED enrollment
    total_sessions = models.IntegerField(null=True, blank=True)
    sessions_attended = models.IntegerField(default=0)

    is_active = models.BooleanField(default=True)
    enrollment_started = models.BooleanField(default=False) # True when first attendance is taken
    date_enrolled = models.DateTimeField(auto_now_add=True) # When enrollment record was created
    date_first_attendance = models.DateTimeField(null=True, blank=True) # When enrollment actually started

    def __str__(self):
        return f"{self.student.first_name} in {self.batch.name} - {self.enrollment_type}"

    def save(self, *args, **kwargs):
        # Example: Basic logic to set end_date for duration-based, or error for session-based if no total_sessions
        # You'll refine this in your views/serializers
        if self.enrollment_type == 'SESSION_BASED' and self.total_sessions is None:
            raise ValueError("Total sessions must be provided for session-based enrollment.")
        if self.enrollment_type == 'DURATION_BASED' and self.end_date is None:
            # Example: For a 1-month plan, set end_date to 1 month from start_date
            # This logic might be better in the view/serializer when creating enrollment
            pass # Keep it simple for model, calculate in application logic

        super().save(*args, **kwargs)

class Attendance(models.Model):
    enrollment = models.ForeignKey(Enrollment, on_delete=models.CASCADE, related_name='attendances')
    batch = models.ForeignKey(Batch, on_delete=models.CASCADE, related_name='batch_attendances') # For easy reporting per batch
    student = models.ForeignKey('accounts.StudentProfile', on_delete=models.CASCADE, related_name='student_attendances') # For easy reporting per student
    organization = models.ForeignKey(Organization, on_delete=models.CASCADE, related_name='attendances') # Denormalized for easier filtering

    date = models.DateField()
    marked_by = models.ForeignKey('accounts.CustomUser', on_delete=models.SET_NULL, null=True, blank=True) # User who marked it (Coach or Admin)
    timestamp = models.DateTimeField(auto_now_add=True)
    
    # For session-based, a session is deducted. For duration-based, it's just recorded.
    is_session_deducted = models.BooleanField(default=False) 

    class Meta:
        unique_together = ('enrollment', 'date') # A student can only have attendance marked once per day per enrollment

    def __str__(self):
        return f"Attendance for {self.student.first_name} in {self.batch.name} on {self.date}"

    def save(self, *args, **kwargs):
        is_new = self.pk is None
        super().save(*args, **kwargs)
        
        # If this is the first attendance for this enrollment, start the enrollment
        if is_new and not self.enrollment.enrollment_started:
            from django.utils import timezone
            from datetime import timedelta
            
            self.enrollment.enrollment_started = True
            self.enrollment.start_date = self.date
            self.enrollment.date_first_attendance = timezone.now()
            
            # For duration-based enrollment, calculate end date from start date
            if self.enrollment.enrollment_type == 'DURATION_BASED':
                # Default to 1 month, you can make this configurable
                self.enrollment.end_date = self.enrollment.start_date + timedelta(days=30)
            
            self.enrollment.save()
            
        # Update sessions attended for session-based enrollment
        if is_new and self.enrollment.enrollment_type == 'SESSION_BASED' and not self.is_session_deducted:
            self.enrollment.sessions_attended += 1
            self.enrollment.save()
            self.is_session_deducted = True
            # Update the field in the database
            Attendance.objects.filter(pk=self.pk).update(is_session_deducted=True)

        # For POST_PAID batches, create a fee transaction for each attendance
        if is_new and self.batch.payment_policy == 'POST_PAID' and self.batch.fee_per_session is not None:
            from payments.models import FeeTransaction
            FeeTransaction.objects.create(
                organization=self.organization,
                student=self.student,
                enrollment=self.enrollment,
                amount=self.batch.fee_per_session,
                due_date=self.date, # Or some other logic for due date
                is_paid=False
            )