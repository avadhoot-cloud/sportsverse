from rest_framework import serializers
from .models import MatchSession, StrokeEvent, RallyEvent

class StrokeEventSerializer(serializers.ModelSerializer):
    class Meta:
        model = StrokeEvent
        fields = '__all__'

class RallyEventSerializer(serializers.ModelSerializer):
    class Meta:
        model = RallyEvent
        fields = '__all__'

class MatchSessionSerializer(serializers.ModelSerializer):
    stroke_events = StrokeEventSerializer(many=True, read_only=True)
    rally_events = RallyEventSerializer(many=True, read_only=True)

    class Meta:
        model = MatchSession
        fields = '__all__'
        read_only_fields = ['user']
