import os
from celery import Celery
from celery.signals import worker_ready

os.environ.setdefault('DJANGO_SETTINGS_MODULE', 'TennisIQ.settings')

app = Celery('TennisIQ')
app.config_from_object('django.conf:settings', namespace='CELERY')
app.autodiscover_tasks()


@worker_ready.connect
def preload_ml_models(sender, **kwargs):
    """
    Triggered once per Celery worker process at startup.
    Loads YOLO + MediaPipe into module-level singletons so the first
    task call doesn't pay the full cold-load cost (3-8 seconds per worker).

    NOTE: AppConfig.ready() loads models in the Django *web* process only.
    This signal handler ensures Celery *worker* processes share the same
    preloaded singletons independently.
    """
    try:
        from analytics.video_analyzer import VideoAnalyzer
        VideoAnalyzer.preload_globals()
        print("[Celery] ML models preloaded in worker process.")
    except Exception as e:
        # Non-fatal — worker will cold-load on first task instead
        print(f"[Celery] WARNING: Model preload failed: {e}")
