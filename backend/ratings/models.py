"""
ratings/models.py

Three core models for the internal DUPR-style rating system:
  - PlayerRatingProfile  : per-user, per-sport rating state
  - RatingMatch          : a match submission record
  - RatingAudit          : immutable log of every rating change
"""
import hashlib
import json
import logging

from django.conf import settings
from django.db import models
from django.utils import timezone

from organizations.models import Organization, Sport

logger = logging.getLogger(__name__)


# ─── PlayerRatingProfile ──────────────────────────────────────────────────────

class PlayerRatingProfile(models.Model):
    """
    Stores the *current* DUPR-style rating for one player in one sport.
    One row per (user, sport, organization) triple.
    """
    user = models.ForeignKey(
        settings.AUTH_USER_MODEL,
        on_delete=models.CASCADE,
        related_name="rating_profiles",
    )
    sport = models.ForeignKey(
        Sport,
        on_delete=models.CASCADE,
        related_name="player_ratings",
    )
    organization = models.ForeignKey(
        Organization,
        on_delete=models.CASCADE,
        related_name="player_ratings",
    )

    # Ratings — Decimal(7,3) → range 2.000 – 8.000, 3 decimal places
    dupr_rating_singles = models.DecimalField(
        max_digits=7, decimal_places=3, default=4.000,
        help_text="Current DUPR singles rating (2.000 – 8.000)",
    )
    dupr_rating_doubles = models.DecimalField(
        max_digits=7, decimal_places=3, default=4.000,
        help_text="Current DUPR doubles rating (2.000 – 8.000)",
    )

    matches_played_singles = models.PositiveIntegerField(default=0)
    matches_played_doubles = models.PositiveIntegerField(default=0)

    # Reliability: 0.00–100.00; Baseline is 50.00
    reliability = models.DecimalField(
        max_digits=5, decimal_places=2, default=50.00,
        help_text="0–100; baseline 50.00. Dictates voting power in disputes.",
    )

    last_synced_at = models.DateTimeField(null=True, blank=True)
    created_at = models.DateTimeField(auto_now_add=True)
    updated_at = models.DateTimeField(auto_now=True)

    class Meta:
        unique_together = ("user", "sport", "organization")
        verbose_name = "Player Rating Profile"
        verbose_name_plural = "Player Rating Profiles"
        indexes = [
            models.Index(fields=["organization", "sport"]),
            models.Index(fields=["user", "sport"]),
        ]

    def __str__(self):
        return (
            f"{self.user} | {self.sport.name} | "
            f"S:{self.dupr_rating_singles} D:{self.dupr_rating_doubles}"
        )

    @property
    def is_provisional_singles(self) -> bool:
        return self.matches_played_singles < 10

    @property
    def is_provisional_doubles(self) -> bool:
        return self.matches_played_doubles < 10

    def touch(self):
        """Update last_synced_at to now."""
        self.last_synced_at = timezone.now()
        self.save(update_fields=["last_synced_at", "updated_at"])


# ─── RatingMatch ──────────────────────────────────────────────────────────────

class RatingMatch(models.Model):
    """
    A submitted match record.  Validated matches are processed through the
    rating engine.  Unvalidated matches await confirmation or are rejected.
    """

    FORMAT_SINGLES = "SINGLES"
    FORMAT_DOUBLES = "DOUBLES"
    FORMAT_CHOICES = [
        (FORMAT_SINGLES, "Singles"),
        (FORMAT_DOUBLES, "Doubles"),
    ]

    IMPORTANCE_CASUAL = "CASUAL"
    IMPORTANCE_LEAGUE = "LEAGUE"
    IMPORTANCE_TOURNAMENT = "TOURNAMENT"
    IMPORTANCE_CHOICES = [
        (IMPORTANCE_CASUAL, "Casual"),
        (IMPORTANCE_LEAGUE, "League"),
        (IMPORTANCE_TOURNAMENT, "Tournament"),
    ]

    STATUS_PENDING = "PENDING"
    STATUS_CONFIRMED = "CONFIRMED"
    STATUS_DISPUTED = "DISPUTED"
    STATUS_AUTO_RESOLVED = "AUTO_RESOLVED"
    STATUS_ADMIN_RESOLVED = "ADMIN_RESOLVED"
    STATUS_REJECTED = "REJECTED"
    STATUS_CHOICES = [
        (STATUS_PENDING, "Pending opponent confirmation"),
        (STATUS_CONFIRMED, "Confirmed exactly"),
        (STATUS_DISPUTED, "Major dispute (Admin Review)"),
        (STATUS_AUTO_RESOLVED, "Auto-resolved (Weighted math)"),
        (STATUS_ADMIN_RESOLVED, "Admin resolved"),
        (STATUS_REJECTED, "Rejected/Nullified"),
    ]

    SOURCE_MANUAL = "MANUAL"
    SOURCE_AUTO = "AUTO"
    SOURCE_IMPORT = "IMPORT"
    SOURCE_CHOICES = [
        (SOURCE_MANUAL, "Manual submission"),
        (SOURCE_AUTO, "Auto-generated"),
        (SOURCE_IMPORT, "Bulk import"),
    ]

    organization = models.ForeignKey(
        Organization, on_delete=models.CASCADE, related_name="rating_matches",
    )
    sport = models.ForeignKey(
        Sport, on_delete=models.CASCADE, related_name="rating_matches",
    )
    submitted_by = models.ForeignKey(
        settings.AUTH_USER_MODEL,
        on_delete=models.SET_NULL,
        null=True,
        related_name="submitted_matches",
    )

    date = models.DateField(help_text="Date the match was played")
    format = models.CharField(max_length=10, choices=FORMAT_CHOICES)
    importance = models.CharField(
        max_length=15, choices=IMPORTANCE_CHOICES, default=IMPORTANCE_CASUAL,
    )

    # participants: list of user IDs, e.g. [1, 2] for singles or [1,2,3,4] for doubles
    participants = models.JSONField(
        help_text="List of participant user IDs, ordered: [winner_side..., loser_side...]",
    )

    # score: flexible JSON submitted by reporter, e.g. {"sets": [{"set": 1, "reporter_score": 11, "opponent_score": 9}]}
    score = models.JSONField(help_text="Match score submitted by reporter")
    opponent_score = models.JSONField(null=True, blank=True, help_text="Match score submitted by opponent if differing")
    resolved_score = models.JSONField(null=True, blank=True, help_text="The final, authorized score used for rating calculation")

    # Dedup hash: SHA-256 of (sorted(participants), date, canonical score string)
    dedup_hash = models.CharField(
        max_length=64, unique=True,
        help_text="Collision-resistant hash for duplicate detection",
    )

    status = models.CharField(
        max_length=15, choices=STATUS_CHOICES, default=STATUS_PENDING,
    )
    validated = models.BooleanField(
        default=False,
        help_text="True once match is confirmed and ready for rating processing",
    )

    processed_at = models.DateTimeField(null=True, blank=True)
    source = models.CharField(max_length=10, choices=SOURCE_CHOICES, default=SOURCE_MANUAL)

    # Validation & Evidence
    deadline_at = models.DateTimeField(null=True, blank=True, help_text="Deadline for opponent action")
    evidence_url = models.URLField(max_length=1024, null=True, blank=True)
    is_processed_for_rating = models.BooleanField(default=False, help_text="Flag indicating Celery worker has applied the rating math")
    fraud_score = models.DecimalField(max_digits=4, decimal_places=3, null=True, blank=True, help_text="0.000 to 1.000 (IsolationForest anomaly score)")

    # Dispute / rollback flag
    rolled_back = models.BooleanField(default=False)
    rollback_reason = models.TextField(blank=True)

    created_at = models.DateTimeField(auto_now_add=True)
    updated_at = models.DateTimeField(auto_now=True)

    class Meta:
        verbose_name = "Rating Match"
        verbose_name_plural = "Rating Matches"
        ordering = ["-date", "-created_at"]
        indexes = [
            models.Index(fields=["organization", "sport", "status"]),
            models.Index(fields=["dedup_hash"]),
            models.Index(fields=["date"]),
        ]

    def __str__(self):
        return (
            f"Match #{self.pk} [{self.format}] "
            f"{self.date} ({self.importance}) — {self.status}"
        )

    @staticmethod
    def compute_dedup_hash(participants: list, date, score: dict) -> str:
        """
        Deterministic deduplication hash.
        Uses sorted participant IDs so [1,2] and [2,1] are the same match.
        """
        participants_key = sorted(int(p) for p in participants)
        score_key = json.dumps(score, sort_keys=True)
        raw = f"{participants_key}|{str(date)}|{score_key}"
        return hashlib.sha256(raw.encode()).hexdigest()

    def save(self, *args, **kwargs):
        # Auto-compute dedup_hash if not set
        if not self.dedup_hash:
            self.dedup_hash = self.compute_dedup_hash(
                self.participants, self.date, self.score
            )
        # Auto-set 48-hour deadline for pending matches
        if not self.deadline_at:
            from datetime import timedelta
            self.deadline_at = timezone.now() + timedelta(hours=48)
        super().save(*args, **kwargs)


# ─── RatingAudit ─────────────────────────────────────────────────────────────

class RatingAudit(models.Model):
    """
    Immutable audit trail.  One record per player per match processed.
    Never updated — only created. Use `rolled_back=True` to mark reversions.
    """

    METHOD_LIVE = "LIVE"
    METHOD_BATCH = "BATCH"
    METHOD_ROLLBACK = "ROLLBACK"
    METHOD_CHOICES = [
        (METHOD_LIVE, "Live (per-match async)"),
        (METHOD_BATCH, "Batch recompute"),
        (METHOD_ROLLBACK, "Rollback"),
    ]

    match = models.ForeignKey(
        RatingMatch,
        on_delete=models.CASCADE,
        related_name="audit_entries",
        null=True,
        blank=True,
        help_text="Null for manual admin adjustments",
    )
    player = models.ForeignKey(
        settings.AUTH_USER_MODEL,
        on_delete=models.CASCADE,
        related_name="rating_audit_entries",
    )

    format = models.CharField(
        max_length=10,
        choices=RatingMatch.FORMAT_CHOICES,
        default=RatingMatch.FORMAT_SINGLES,
    )

    old_rating = models.DecimalField(max_digits=7, decimal_places=3)
    new_rating = models.DecimalField(max_digits=7, decimal_places=3)
    delta = models.DecimalField(
        max_digits=7, decimal_places=3,
        help_text="new_rating - old_rating (positive = improvement)",
    )

    method = models.CharField(max_length=10, choices=METHOD_CHOICES, default=METHOD_LIVE)
    note = models.TextField(blank=True, help_text="Human-readable explanation or batch run ID")

    rolled_back = models.BooleanField(default=False)
    created_at = models.DateTimeField(auto_now_add=True)

    class Meta:
        verbose_name = "Rating Audit Entry"
        verbose_name_plural = "Rating Audit Entries"
        ordering = ["-created_at"]
        indexes = [
            models.Index(fields=["player", "-created_at"]),
            models.Index(fields=["match"]),
        ]

    def __str__(self):
        sign = "+" if self.delta >= 0 else ""
        return (
            f"Audit player={self.player_id} match={self.match_id} "
            f"{self.old_rating}→{self.new_rating} ({sign}{self.delta}) [{self.method}]"
        )


# ─── MatchAuditTrail ─────────────────────────────────────────────────────────

class MatchAuditTrail(models.Model):
    """
    Tracks state changes, fraud flags, and admin interventions for a match.
    """
    match = models.ForeignKey(
        RatingMatch, on_delete=models.CASCADE, related_name="status_audits"
    )
    actor = models.ForeignKey(
        settings.AUTH_USER_MODEL, on_delete=models.SET_NULL, null=True, blank=True,
        help_text="User who triggered this change (can be null for system tasks)"
    )
    previous_status = models.CharField(max_length=20, choices=RatingMatch.STATUS_CHOICES, blank=True)
    new_status = models.CharField(max_length=20, choices=RatingMatch.STATUS_CHOICES)
    action_type = models.CharField(
        max_length=50, 
        help_text="e.g. SUBMITTED, COUNTER_SUBMITTED, AUTO_RESOLVED, FRAUD_FLAGGED, ADMIN_RESOLVED"
    )
    note = models.TextField(blank=True)
    created_at = models.DateTimeField(auto_now_add=True)

    class Meta:
        verbose_name = "Match Audit Trail"
        verbose_name_plural = "Match Audit Trails"
        ordering = ["-created_at"]
        indexes = [
            models.Index(fields=["match"]),
            models.Index(fields=["action_type"]),
        ]

    def __str__(self):
        return f"Match {self.match_id} transition: {self.previous_status} -> {self.new_status} ({self.action_type})"
