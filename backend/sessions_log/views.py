from rest_framework import viewsets
from rest_framework.permissions import IsAuthenticated
from .models import MatchSession, StrokeEvent, RallyEvent
from .serializers import MatchSessionSerializer, StrokeEventSerializer, RallyEventSerializer

from rest_framework.decorators import action
from django.db.models import Count

class MatchSessionViewSet(viewsets.ModelViewSet):
    queryset = MatchSession.objects.all()
    serializer_class = MatchSessionSerializer
    permission_classes = [IsAuthenticated]

    def perform_create(self, serializer):
        serializer.save(user=self.request.user)
        
    def get_queryset(self):
        return self.queryset.filter(user=self.request.user)
        
    @action(detail=True, methods=['get'])
    def details_ui(self, request, pk=None):
        session = self.get_object()
        strokes = session.stroke_events.all()
        
        # Calculate distribution safely
        distribution = {}
        for s in strokes:
            t = s.stroke_type
            distribution[t] = distribution.get(t, 0) + 1
            
        # Get VideoMetrics if they exist
        video_metrics = getattr(session, 'video_metrics', None)
        fusion_metrics = getattr(session, 'fusion_metrics', None)
        watch_metrics = getattr(session, 'watch_metrics', None)
        
        # Task 30: Stroke Tempo Time-Series
        tempo_series = []
        if strokes.exists():
            max_ms = max([s.timestamp_ms for s in strokes])
            minutes = int(max_ms // 60000) + 1
            bins = [0] * minutes
            for s in strokes:
                min_idx = int(s.timestamp_ms // 60000)
                if 0 <= min_idx < minutes:
                    bins[min_idx] += 1
            tempo_series = bins
            
        # Task 31: Fatigue Score Computation
        if watch_metrics and watch_metrics.fatigue_score is None:
            from analytics.fatigue_model import calculate_fatigue_index
            fatigue = calculate_fatigue_index(watch_metrics, video_metrics)
            if fatigue is not None:
                watch_metrics.fatigue_score = fatigue
                watch_metrics.save()
        
        return Response({
            "session_id": str(session.id),
            "stroke_count": strokes.count() if strokes.exists() else "NA",
            "distance_m": video_metrics.movement_distance_m if video_metrics and video_metrics.movement_distance_m is not None else "NA",
            "stroke_distribution": {
                "forehand": distribution.get('forehand', "NA"),
                "backhand": distribution.get('backhand', "NA"),
                "serve": distribution.get('serve', "NA"),
                "volley": distribution.get('volley', "NA"),
                "unknown": distribution.get('unknown', "NA"),
            },
            "shot_accuracy_pct": video_metrics.shot_accuracy_pct if video_metrics and video_metrics.shot_accuracy_pct is not None else "NA",
            "avg_reaction_time_ms": video_metrics.avg_reaction_time_ms if video_metrics and video_metrics.avg_reaction_time_ms is not None else "NA",
            "unforced_errors": video_metrics.unforced_errors if video_metrics and video_metrics.unforced_errors is not None else "NA",
            # Phase 3 fields — server-only (ball_tracker.pt not on Flutter edge)
            "max_ball_speed_kmh": video_metrics.max_ball_speed_kmh if video_metrics and video_metrics.max_ball_speed_kmh is not None else "NA",
            "dominant_court_zone": video_metrics.dominant_court_zone if video_metrics and video_metrics.dominant_court_zone is not None else "NA",
            "match_intensity_score": fusion_metrics.match_intensity if fusion_metrics and fusion_metrics.match_intensity is not None else "NA",
            "timing_score": fusion_metrics.timing_score if fusion_metrics and fusion_metrics.timing_score is not None else "NA",
            "consistency_score": fusion_metrics.consistency_score if fusion_metrics and fusion_metrics.consistency_score is not None else "NA",
            "stroke_quality_score": fusion_metrics.stroke_quality_score if fusion_metrics and fusion_metrics.stroke_quality_score is not None else "NA",
            "max_rally_length": video_metrics.max_rally_length if video_metrics and video_metrics.max_rally_length is not None else "NA",
            "avg_rally_length": video_metrics.avg_rally_length if video_metrics and video_metrics.avg_rally_length is not None else "NA",
            "movement_heatmap": video_metrics.movement_heatmap if video_metrics and video_metrics.movement_heatmap is not None else "NA",
            "max_serve_speed_kmh": video_metrics.max_serve_speed_kmh if video_metrics and video_metrics.max_serve_speed_kmh is not None else "NA",
            "fatigue_score": watch_metrics.fatigue_score if watch_metrics and watch_metrics.fatigue_score is not None else "NA",
            "stroke_tempo_series": tempo_series,
            "coaching_insights": []
        })

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
