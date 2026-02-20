from rest_framework import serializers
from .models import TrainingVideo
from accounts.models import StudentProfile

class TrainingVideoSerializer(serializers.ModelSerializer):
    # We include these to show names in the frontend, not just IDs
    branch_name = serializers.ReadOnlyField(source='branch.name')
    batch_name = serializers.ReadOnlyField(source='batch.name')

    class ImageSerializer(serializers.ModelSerializer):
        class Meta:
            model = TrainingVideo
            fields = '__all__'

    class Meta:
        model = TrainingVideo
        fields = [
            'id', 'organization', 'title', 'video_file', 
            'branch', 'branch_name', 'batch', 'batch_name', 
            'target_students', 'uploaded_at'
        ]