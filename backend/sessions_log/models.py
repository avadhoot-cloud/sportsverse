from django.db import models
from django.conf import settings

class MatchSession(models.Model):
    MODE_CHOICES = (
        ('video_only', 'Video Only'),
        ('watch_only', 'Watch Only'),
        ('fusion', 'Fusion'),
    )
    user = models.ForeignKey(settings.AUTH_USER_MODEL, on_delete=models.CASCADE, related_name='match_sessions')
    date = models.DateTimeField(auto_now_add=True)
    duration_seconds = models.IntegerField(default=0)
    mode = models.CharField(max_length=20, choices=MODE_CHOICES)
    notes = models.TextField(blank=True, null=True)
    is_synced = models.BooleanField(default=False)

    def __str__(self):
        return f"{self.user.username} - {self.date} ({self.mode})"

class StrokeEvent(models.Model):
    STROKE_TYPE_CHOICES = (
        ('forehand', 'Forehand'),
        ('backhand', 'Backhand'),
        ('serve', 'Serve'),
        ('volley', 'Volley'),
        ('smash', 'Smash'),
        ('unknown', 'Unknown'),
    )
    SOURCE_CHOICES = (
        ('video', 'Video'),
        ('watch', 'Watch'),
        ('fusion', 'Fusion'),
    )
    session = models.ForeignKey(MatchSession, on_delete=models.CASCADE, related_name='stroke_events')
    timestamp_ms = models.BigIntegerField()
    stroke_type = models.CharField(max_length=20, choices=STROKE_TYPE_CHOICES, default='unknown')
    confidence = models.FloatField(default=0.0)
    source = models.CharField(max_length=20, choices=SOURCE_CHOICES)

    def __str__(self):
        return f"{self.stroke_type} at {self.timestamp_ms}ms"

class RallyEvent(models.Model):
    WINNER_CHOICES = (
        ('player', 'Player'),
        ('opponent', 'Opponent'),
        ('net_error', 'Net Error'),
        ('out_error', 'Out Error'),
        ('unknown', 'Unknown'),
    )
    session = models.ForeignKey(MatchSession, on_delete=models.CASCADE, related_name='rally_events')
    start_ms = models.BigIntegerField()
    end_ms = models.BigIntegerField()
    rally_length = models.IntegerField(default=0)
    winner = models.CharField(max_length=20, choices=WINNER_CHOICES, default='unknown')

    def __str__(self):
        return f"Rally {self.start_ms}-{self.end_ms} (Winner: {self.winner})"
