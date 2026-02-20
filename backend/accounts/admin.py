# sportsverse/backend/accounts/admin.py

from django.contrib import admin
from django.contrib.auth.admin import UserAdmin
from .models import CustomUser, AcademyAdminProfile ,StudentProfile
from organizations.models import Organization, Branch # Required for CoachProfile M2M display

@admin.register(CustomUser)
class CustomUserAdmin(UserAdmin):
    # Customize the fieldsets for adding/changing users in the admin
    fieldsets = UserAdmin.fieldsets + (
        (('User Type & Contact Info', {'fields': ('user_type', 'phone_number', 'gender', 'date_of_birth')}),)
    )
    add_fieldsets = UserAdmin.add_fieldsets + (
        (('User Type & Contact Info', {'fields': ('user_type', 'phone_number', 'gender', 'date_of_birth')}),)
    )
    # Customize the list display and filters in the admin change list
    list_display = ('username', 'email', 'first_name', 'last_name', 'user_type', 'is_staff', 'is_active')
    list_filter = ('user_type', 'is_staff', 'is_active')
    search_fields = ('username', 'email', 'first_name', 'last_name', 'phone_number')
    ordering = ('username',)

@admin.register(AcademyAdminProfile)
class AcademyAdminProfileAdmin(admin.ModelAdmin):
    list_display = ('user', 'organization')
    search_fields = ('user__username', 'user__first_name', 'user__last_name', 'organization__academy_name')
    list_filter = ('organization',)



@admin.register(StudentProfile)
class StudentProfileAdmin(admin.ModelAdmin):
    list_display = ('get_full_name', 'organization', 'date_of_birth', 'email', 'phone_number', 'gender')
    search_fields = ('first_name', 'last_name', 'email', 'phone_number', 'parent_name', 'organization__academy_name')
    list_filter = ('organization', 'gender')
    date_hierarchy = 'date_of_birth' # Allows drilling down by birth date

    def get_full_name(self, obj):
        return f"{obj.first_name} {obj.last_name}"
    get_full_name.short_description = 'Student Name'

