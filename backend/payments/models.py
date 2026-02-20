from django.db import models
from organizations.models import Organization, Enrollment
from accounts.models import StudentProfile, CustomUser
# Import the NEW CoachProfile from the new app
from coaches.models import CoachProfile 

# 1. STUDENT FEE COLLECTION (This stays)
class FeeTransaction(models.Model):
    organization = models.ForeignKey(Organization, on_delete=models.CASCADE, related_name='fee_transactions')
    student = models.ForeignKey(StudentProfile, on_delete=models.CASCADE, related_name='fee_transactions')
    enrollment = models.ForeignKey(Enrollment, on_delete=models.SET_NULL, null=True, blank=True, related_name='fee_transactions')
    amount = models.DecimalField(max_digits=10, decimal_places=2)
    transaction_date = models.DateField(auto_now_add=True)
    due_date = models.DateField(null=True, blank=True)
    is_paid = models.BooleanField(default=False)
    payment_method = models.CharField(max_length=50, choices=[('Cash', 'Cash'), ('Online', 'Online')], default='Cash')
    receipt_number = models.CharField(max_length=100, unique=True, blank=True, null=True)

    class Meta:
        ordering = ['-transaction_date']

# 2. COACH SALARY (Updated to link to the new Coaches app)
class CoachSalaryTransaction(models.Model):
    organization = models.ForeignKey(Organization, on_delete=models.CASCADE, related_name='coach_salary_transactions')
    # This now points to coaches.CoachProfile correctly
    coach = models.ForeignKey(CoachProfile, on_delete=models.CASCADE, related_name='salary_transactions')
    amount = models.DecimalField(max_digits=10, decimal_places=2)
    transaction_date = models.DateField(auto_now_add=True)
    payment_period = models.CharField(max_length=100) 
    is_paid = models.BooleanField(default=True)
    paid_by = models.ForeignKey(CustomUser, on_delete=models.SET_NULL, null=True, related_name='coach_payments_made')

# --- STAFF SALARY DELETED ---
# We removed StaffProfile, so this class would cause errors. 
# If you ever add staff back, we will create a separate app for them.