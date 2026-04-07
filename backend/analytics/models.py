from django.db import models
from sessions_log.models import MatchSession

class WatchMetrics(models.Model):
    session = models.OneToOneField(MatchSession, on_delete=models.CASCADE, related_name='watch_metrics')
    peak_acceleration = models.FloatField(default=0.0)
    angular_velocity = models.FloatField(default=0.0)
    swing_intensity = models.FloatField(default=0.0)
    fatigue_score = models.FloatField(default=0.0)
    hr_avg = models.FloatField(default=0.0)
    hr_max = models.FloatField(default=0.0)
    workout_load = models.FloatField(default=0.0)

    def __str__(self):
        return f"Watch Metrics for {self.session.id}"

class VideoMetrics(models.Model):
    session = models.OneToOneField(MatchSession, on_delete=models.CASCADE, related_name='video_metrics')
    movement_distance_m = models.FloatField(default=0.0)
    court_coverage_pct = models.FloatField(default=0.0)
    avg_reaction_time_ms = models.FloatField(default=0.0)
    shot_accuracy_pct = models.FloatField(default=0.0)
    unforced_errors = models.IntegerField(default=0)

    def __str__(self):
        return f"Video Metrics for {self.session.id}"

class FusionMetrics(models.Model):
    session = models.OneToOneField(MatchSession, on_delete=models.CASCADE, related_name='fusion_metrics')
    timing_score = models.FloatField(default=0.0)
    consistency_score = models.FloatField(default=0.0)
    stroke_quality_score = models.FloatField(default=0.0)
    match_intensity = models.FloatField(default=0.0)

    def __str__(self):
        return f"Fusion Metrics for {self.session.id}"
