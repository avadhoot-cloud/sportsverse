# sportsverse/backend/organizations/admin.py

from django.contrib import admin
from .models import Organization, Sport, Branch, Batch, Enrollment, Attendance

@admin.register(Organization)
class OrganizationAdmin(admin.ModelAdmin):
    list_display = ('academy_name', 'full_name', 'email_address', 'mobile_number', 'is_active', 'subscription_plan', 'date_joined')
    search_fields = ('academy_name', 'full_name', 'email_address', 'location', 'slug')
    list_filter = ('is_active', 'subscription_plan', 'date_joined')
    prepopulated_fields = {'slug': ('academy_name',)} # Auto-populate slug from academy_name
    filter_horizontal = ('sports_offered',) # For ManyToMany field

@admin.register(Sport)
class SportAdmin(admin.ModelAdmin):
    list_display = ( 'name', )

    search_fields = ('name',)

@admin.register(Branch)
class BranchAdmin(admin.ModelAdmin):
    list_display = ('name', 'organization', 'is_active')
    search_fields = ('name', 'organization__academy_name', 'address')
    list_filter = ('organization', 'is_active')

@admin.register(Batch)
class BatchAdmin(admin.ModelAdmin):
    list_display = ('name', 'organization', 'branch', 'sport', 'max_students', 'is_active')
    search_fields = ('name', 'organization__academy_name', 'branch__name', 'sport__name')
    list_filter = ('organization', 'branch', 'sport', 'is_active')

@admin.register(Enrollment)
class EnrollmentAdmin(admin.ModelAdmin):
    list_display = ('student', 'batch', 'organization', 'enrollment_type', 'start_date', 'end_date', 'total_sessions', 'sessions_attended', 'is_active')
    search_fields = ('student__first_name', 'student__last_name', 'batch__name', 'organization__academy_name')
    list_filter = ('organization', 'enrollment_type', 'is_active', 'batch__sport')
    raw_id_fields = ('student', 'batch') # For large numbers of students/batches, allows searching by ID
    date_hierarchy = 'date_enrolled'

@admin.register(Attendance)
class AttendanceAdmin(admin.ModelAdmin):
    list_display = ('student', 'batch', 'date', 'marked_by', 'is_session_deducted', 'organization')
    search_fields = ('student__first_name', 'student__last_name', 'batch__name', 'marked_by__username', 'organization__academy_name')
    list_filter = ('organization', 'date', 'batch', 'is_session_deducted')
    date_hierarchy = 'date'
    raw_id_fields = ('enrollment', 'batch', 'student', 'marked_by') # For large numbers of related objects