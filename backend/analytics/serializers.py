from rest_framework import serializers
from .models import WatchMetrics, VideoMetrics, FusionMetrics

class WatchMetricsSerializer(serializers.ModelSerializer):
    class Meta:
        model = WatchMetrics
        fields = '__all__'

class VideoMetricsSerializer(serializers.ModelSerializer):
    class Meta:
        model = VideoMetrics
        fields = '__all__'

class FusionMetricsSerializer(serializers.ModelSerializer):
    class Meta:
        model = FusionMetrics
        fields = '__all__'
