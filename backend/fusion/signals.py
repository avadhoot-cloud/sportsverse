import threading
from django.db.models.signals import post_save
from django.dispatch import receiver
from sessions_log.models import MatchSession
from analytics.models import VideoMetrics, WatchMetrics, FusionMetrics
from .sync import TimeSyncEngine
from .features import FusionFeatureExtractor
from .scorer import FusionScorer

def auto_fusion_task(session_id):
    """Background processor checking constraints extracting ML dynamically natively"""
    try:
        session = MatchSession.objects.get(id=session_id)
        
        # Guard checking requirements
        if not VideoMetrics.objects.filter(session=session).exists(): return
        if not WatchMetrics.objects.filter(session=session).exists(): return
        
        # Re-check to avoid repeating arrays infinitely securely
        if FusionMetrics.objects.filter(session=session).exists(): return
        
        v_strokes = list(session.stroke_events.filter(source='video').order_by('timestamp_ms'))
        w_strokes = list(session.stroke_events.filter(source='watch').order_by('timestamp_ms'))
        
        if not v_strokes or not w_strokes: return
        
        # Logic matches exactly what `/analyze/` expects structurally
        vid_metrics = VideoMetrics.objects.get(session=session)
        watch_metrics = WatchMetrics.objects.get(session=session)
        
        engine = TimeSyncEngine()
        engine.sync_timestamps([s.timestamp_ms for s in w_strokes], [s.timestamp_ms for s in v_strokes])
        
        extractor = FusionFeatureExtractor()
        features = extractor.extract_features(vid_metrics, watch_metrics, v_strokes, w_strokes)
        
        scorer = FusionScorer()
        final_score = scorer.score(features)
        
        FusionMetrics.objects.create(
            session=session,
            timing_score=features.get('timing_score', 0),
            consistency_score=features.get('consistency_score', 0),
            stroke_quality_score=features.get('stroke_quality_score', 0),
            match_intensity=features.get('match_intensity_index', 0),
            overall_performance_score=final_score
        )
    except Exception as e:
        # Ignore silent failures holding background threading natively securely 
        pass

@receiver(post_save, sender=VideoMetrics)
def check_video_trigger(sender, instance, **kwargs):
    # If a video metrics completes perfectly on a session, trigger a background evaluation tracking
    thread = threading.Thread(target=auto_fusion_task, args=(instance.session.id,))
    thread.daemon = True
    thread.start()

@receiver(post_save, sender=WatchMetrics)
def check_watch_trigger(sender, instance, **kwargs):
    # Same mechanism securely tracking reverse completion instances logically
    thread = threading.Thread(target=auto_fusion_task, args=(instance.session.id,))
    thread.daemon = True
    thread.start()
