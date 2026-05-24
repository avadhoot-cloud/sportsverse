from rest_framework import serializers
from .models import TrainingVideo
from accounts.models import StudentProfile

class TrainingVideoSerializer(serializers.ModelSerializer):
    branch_name = serializers.ReadOnlyField(source='branch.name')
    batch_name = serializers.ReadOnlyField(source='batch.name')
    organization = serializers.PrimaryKeyRelatedField(read_only=True)

    class Meta:
        model = TrainingVideo
        fields = [
            'id', 'organization', 'title', 'video_file',
            'branch', 'branch_name', 'batch', 'batch_name',
            'target_students', 'uploaded_at',
        ]