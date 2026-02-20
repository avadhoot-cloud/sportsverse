from django.contrib import admin
from .models import CoachProfile, CoachAssignment

@admin.register(CoachProfile)
class CoachProfileAdmin(admin.ModelAdmin):
    list_display = ('user', 'organization', 'is_active')

@admin.register(CoachAssignment)
class CoachAssignmentAdmin(admin.ModelAdmin):
    list_display = ('coach', 'branch', 'sport', 'batch')