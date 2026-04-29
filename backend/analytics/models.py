from django.db import models
from sessions_log.models import MatchSession

class WatchMetrics(models.Model):
    session = models.OneToOneField(MatchSession, on_delete=models.CASCADE, related_name='watch_metrics')
    peak_acceleration = models.FloatField(default=0.0)
    angular_velocity = models.FloatField(default=0.0)
    swing_intensity = models.FloatField(default=0.0)
    fatigue_score = models.FloatField(null=True, blank=True)
    hr_avg = models.FloatField(default=0.0)
    hr_max = models.FloatField(default=0.0)
    workout_load = models.FloatField(default=0.0)

    def __str__(self):
        return f"Watch Metrics for {self.session.id}"

class VideoMetrics(models.Model):
    session = models.OneToOneField(MatchSession, on_delete=models.CASCADE, related_name='video_metrics')
    movement_distance_m = models.FloatField(null=True, blank=True)
    court_coverage_pct = models.FloatField(null=True, blank=True)
    avg_reaction_time_ms = models.FloatField(null=True, blank=True)
    shot_accuracy_pct = models.FloatField(null=True, blank=True)
    unforced_errors = models.IntegerField(null=True, blank=True)
    homography_matrix = models.JSONField(null=True, blank=True)
    dominant_court_zone = models.CharField(max_length=50, null=True, blank=True)
    max_ball_speed_kmh = models.FloatField(null=True, blank=True)
    max_rally_length = models.IntegerField(null=True, blank=True)
    avg_rally_length = models.FloatField(null=True, blank=True)
    movement_heatmap = models.JSONField(null=True, blank=True)
    max_serve_speed_kmh = models.FloatField(null=True, blank=True)

    def __str__(self):
        return f"Video Metrics for {self.session.id}"

class ProcessingJob(models.Model):
    STATUS_CHOICES = (
        ('pending', 'Pending'),
        ('processing', 'Processing'),
        ('completed', 'Completed'),
        ('error', 'Error'),
    )
    session = models.OneToOneField(MatchSession, on_delete=models.CASCADE, related_name='processing_job')
    status = models.CharField(max_length=20, choices=STATUS_CHOICES, default='pending')
    error_message = models.TextField(null=True, blank=True)
    created_at = models.DateTimeField(auto_now_add=True)
    updated_at = models.DateTimeField(auto_now=True)

    def __str__(self):
        return f"Job {self.session.id} - {self.status}"

class FusionMetrics(models.Model):
    session = models.OneToOneField(MatchSession, on_delete=models.CASCADE, related_name='fusion_metrics')
    timing_score = models.FloatField(default=0.0)
    consistency_score = models.FloatField(default=0.0)
    stroke_quality_score = models.FloatField(default=0.0)
    match_intensity = models.FloatField(default=0.0)

    def __str__(self):
        return f"Fusion Metrics for {self.session.id}"
