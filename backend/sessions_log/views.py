from rest_framework import viewsets
from rest_framework.permissions import IsAuthenticated
from .models import MatchSession, StrokeEvent, RallyEvent
from .serializers import MatchSessionSerializer, StrokeEventSerializer, RallyEventSerializer

class MatchSessionViewSet(viewsets.ModelViewSet):
    queryset = MatchSession.objects.all()
    serializer_class = MatchSessionSerializer
    permission_classes = [IsAuthenticated]

    def perform_create(self, serializer):
        serializer.save(user=self.request.user)
        
    def get_queryset(self):
        return self.queryset.filter(user=self.request.user)

class StrokeEventViewSet(viewsets.ModelViewSet):
    queryset = StrokeEvent.objects.all()
    serializer_class = StrokeEventSerializer
    permission_classes = [IsAuthenticated]
    
    def get_queryset(self):
        return self.queryset.filter(session__user=self.request.user)

class RallyEventViewSet(viewsets.ModelViewSet):
    queryset = RallyEvent.objects.all()
    serializer_class = RallyEventSerializer
    permission_classes = [IsAuthenticated]
    
    def get_queryset(self):
        return self.queryset.filter(session__user=self.request.user)

from rest_framework.decorators import api_view, permission_classes
from rest_framework.response import Response
from analytics.ml_models.stroke_classifier import StrokeClassifier
from django.shortcuts import get_object_or_404

# Singleton bounding to keep memory tight on consecutive posts
_classifier = None

@api_view(['POST'])
@permission_classes([IsAuthenticated])
def process_imu_window(request):
    global _classifier
    if _classifier is None:
        _classifier = StrokeClassifier()
        _classifier.load_model()
        
    data = request.data
    session_id = data.get('session_id')
    imu_windows = data.get('imu_windows', []) # List of windows
    
    session = get_object_or_404(MatchSession, id=session_id, user=request.user)
    
    results = []
    
    for window in imu_windows:
        # Expected window to be list of 50 dict sequences
        stroke_type, confidence = _classifier.predict(window)
        
        if stroke_type != 'unknown' and confidence > 0.40:
            ts = window[0].get('timestampMs', 0) if window else 0
            
            # Persist the event to DB
            event = StrokeEvent.objects.create(
                session=session,
                timestamp_ms=ts,
                stroke_type=stroke_type,
                confidence=confidence,
                source='watch'
            )
            
            results.append({
                'id': event.id,
                'stroke_type': stroke_type,
                'confidence': confidence,
                'timestamp_ms': ts
            })

    return Response({'detected_strokes': results})
