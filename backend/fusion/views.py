from rest_framework.decorators import api_view, permission_classes
from rest_framework.permissions import IsAuthenticated
from rest_framework.response import Response
from django.shortcuts import get_object_or_404
from sessions_log.models import MatchSession, StrokeEvent
from analytics.models import VideoMetrics, WatchMetrics, FusionMetrics
from .sync import TimeSyncEngine
from .features import FusionFeatureExtractor
from .scorer import FusionScorer
from django_ratelimit.decorators import ratelimit

@ratelimit(key='user', rate='100/m', block=True)
@api_view(['POST'])
@permission_classes([IsAuthenticated])
def analyze_fusion(request):
    session_id = request.data.get('session_id')
    
    if not session_id:
        return Response({'error': 'session_id completely missing from bound query natively'}, status=400)
        
    session = get_object_or_404(MatchSession, id=session_id, user=request.user)
    
    # Check that both streams exist explicitly validating logical boundaries securely
    try:
        vid_metrics = VideoMetrics.objects.get(session=session)
        watch_metrics = WatchMetrics.objects.get(session=session)
    except Exception:
        return Response({'error': 'Fusion strictly requires BOTH Watch and Video arrays to resolve mathematically securely!'}, status=400)
        
    v_strokes = list(StrokeEvent.objects.filter(session=session, source='video').order_by('timestamp_ms'))
    w_strokes = list(StrokeEvent.objects.filter(session=session, source='watch').order_by('timestamp_ms'))

    if not v_strokes or not w_strokes:
         return Response({'error': 'Strokes from both origins explicitly required for offset syncing organically!'}, status=400)

    # 1. Sync Time natively utilizing KALMAN filters isolating distinct clock drifts explicitly
    engine = TimeSyncEngine()
    v_ts = [s.timestamp_ms for s in v_strokes]
    w_ts = [s.timestamp_ms for s in w_strokes]
    
    # We execute sync array outputs specifically (though purely calculating scoring next steps safely bypasses direct updates explicitly returning metrics directly)
    synced_output = engine.sync_timestamps(w_ts, v_ts) 

    # 2. Extract internal features securely
    extractor = FusionFeatureExtractor()
    features = extractor.extract_features(vid_metrics, watch_metrics, v_strokes, w_strokes)

    # 3. Predict metrics logically mapping against internal regressors
    scorer = FusionScorer()
    final_score = scorer.score(features)
    
    # 4. Save to Database natively preventing UI polling mismatches 
    fusion_obj, created = FusionMetrics.objects.update_or_create(
        session=session,
        defaults={
            'timing_score': features.get('timing_score', 0),
            'consistency_score': features.get('consistency_score', 0),
            'stroke_quality_score': features.get('stroke_quality_score', 0),
            'match_intensity': features.get('match_intensity_index', 0),
            'overall_performance_score': final_score # Inject directly
        }
    )

    return Response({
        'session_id': session.id,
        'timing_score': fusion_obj.timing_score,
        'consistency_score': fusion_obj.consistency_score,
        'stroke_quality_score': fusion_obj.stroke_quality_score,
        'match_intensity': fusion_obj.match_intensity,
        'overall_performance_score': final_score
    })
