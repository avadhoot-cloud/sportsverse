import sys
import os
from django.apps import AppConfig


class AnalyticsConfig(AppConfig):
    default_auto_field = 'django.db.models.BigAutoField'
    name = 'analytics'

    def ready(self):
        """
        Preload YOLO + MediaPipe into module-level singletons when the
        Django *web* process starts (runserver / daphne).

        Guard against management commands (migrate, makemigrations, shell)
        to avoid loading heavy models unnecessarily.

        NOTE: Celery *worker* processes do NOT call AppConfig.ready() —
        model preloading there is handled by the worker_ready signal in
        TennisIQ/celery.py.
        """
        is_web_server = (
            'runserver' in sys.argv
            or (len(sys.argv) > 0 and 'daphne' in sys.argv[0])
        )
        if not is_web_server:
            return

        # `runserver` with StatReloader executes startup twice.
        # RUN_MAIN=true identifies the child process that serves requests.
        if 'runserver' in sys.argv and os.environ.get('RUN_MAIN') != 'true':
            return

        try:
            from .video_analyzer import VideoAnalyzer
            VideoAnalyzer.preload_globals()
            print("[AnalyticsConfig] ML models preloaded in web process.")
        except Exception as e:
            print(f"[AnalyticsConfig] WARNING: Model preload failed: {e}")
