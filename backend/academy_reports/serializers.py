class StudentDashboardSerializer(serializers.ModelSerializer):
    branch_name = serializers.CharField(source='batch.branch.name', read_only=True)
    current_enrollment = serializers.CharField(source='batch.name', read_only=True)
    enrollment_cycle = serializers.CharField(source='session_cycle') # Adjust based on your field name

    class Meta:
        model = StudentProfile
        fields = ['branch_name', 'current_enrollment', 'enrollment_cycle', 'sessions_completed', 'sessions_remaining']