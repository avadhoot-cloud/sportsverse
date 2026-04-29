"""
Celery tasks for async video processing.

Key design decisions:
- Celery manages its own DB connection lifecycle; no manual connection.close() needed.
- After completion/error, broadcasts a WebSocket event via Django Channels so
  the Flutter client gets a push instead of polling.
- shot_accuracy_pct and unforced_errors will return None (serialized as "NA")
  when ball_tracker.pt weights are not present — this is correct per integrity rules,
  NOT a bug. See Phase 3 notes.
"""
from celery import shared_task
from asgiref.sync import async_to_sync
from channels.layers import get_channel_layer


def _broadcast_status(session_id: str, status: str, error: str = None):
    """Push a job status update to the WebSocket group for this session."""
    channel_layer = get_channel_layer()
    if channel_layer is None:
        return  # Redis not running in dev — degrade gracefully, HTTP poll still works
    async_to_sync(channel_layer.group_send)(
        f"job_{session_id}",
        {
            'type': 'job_update',   # maps to JobStatusConsumer.job_update()
            'status': status,
            'error': error,
        }
    )


@shared_task(bind=True, max_retries=0)
def process_video_task(self, video_path: str, session_id: int):
    """
    Runs the full MatchAnalyzer CV pipeline in a Celery worker.
    Replaces the threading.Thread approach from Phase 1.
    """
    from sessions_log.models import MatchSession, StrokeEvent, RallyEvent
    from analytics.models import VideoMetrics, ProcessingJob
    from analytics.video_analyzer import MatchAnalyzer

    session = MatchSession.objects.filter(id=session_id).first()
    if not session:
        return

    job, _ = ProcessingJob.objects.update_or_create(
        session=session, defaults={'status': 'processing'}
    )
    _broadcast_status(str(session_id), 'processing')

    try:
        analyzer = MatchAnalyzer()
        results = analyzer.analyze_video(video_path, session_id)

        VideoMetrics.objects.update_or_create(
            session=session,
            defaults=results.video_metrics
        )

        for stroke in results.stroke_events:
            StrokeEvent.objects.create(
                session=session,
                timestamp_ms=stroke['timestamp_ms'],
                stroke_type=stroke['stroke_type'],
                confidence=stroke['confidence'],
                source='video'
            )
            
        for rally in getattr(results, 'rally_events', []):
            RallyEvent.objects.create(
                session=session,
                start_ms=rally['start_ms'],
                end_ms=rally['end_ms'],
                rally_length=rally['rally_length'],
                winner='unknown'
            )

        session.is_synced = True
        session.save()

        job.status = 'completed'
        job.save()
        _broadcast_status(str(session_id), 'completed')

    except Exception as exc:
        job.status = 'error'
        job.error_message = str(exc)
        job.save()
        _broadcast_status(str(session_id), 'error', str(exc))
        raise  # Re-raise so Celery marks task as FAILURE in the result backend
