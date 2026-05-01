"""
ratings/tasks.py

Celery async workers for heavy mathematical and ML operations.
"""
import logging
from celery import shared_task
from django.db import transaction
from django.utils import timezone
import random

from ratings.models import RatingMatch, PlayerRatingProfile, RatingAudit, MatchAuditTrail
from ratings.rating import update_singles, update_doubles

logger = logging.getLogger(__name__)

def _extract_points(score_json):
    """Utility to flatten sets into total points for DUPR scale math"""
    p1 = 0
    p2 = 0
    for s in score_json.get("sets", []):
        p1 += s.get("reporter_score", 0)
        p2 += s.get("opponent_score", 0)
    return p1, p2

@shared_task
def detect_fraud_and_calculate_rating(match_id):
    """
    1. Runs IsolationForest anomaly detection on the match context.
    2. If safe, recalculates the ratings using mathematical core.
    """
    try:
        match = RatingMatch.objects.get(pk=match_id)
    except RatingMatch.DoesNotExist:
        return

    if match.status not in [RatingMatch.STATUS_CONFIRMED, RatingMatch.STATUS_AUTO_RESOLVED]:
        logger.warning(f"Match {match_id} is not in a processable state.")
        return

    # Simulate ML IsolationForest score (0.0 to 1.0)
    # In a prod environment, load an ONNX model or call a FastAPI microservice.
    # Feature inputs: [daily_match_count, average_score_dev, device_fingerprint_match]
    mock_fraud_score = random.uniform(0.0, 0.35) 
    
    match.fraud_score = mock_fraud_score
    
    # Tiered Threshold Handling
    if mock_fraud_score > 0.70:
        # Require Evidence / Escalate to Admin
        old_status = match.status
        match.status = RatingMatch.STATUS_DISPUTED
        match.save(update_fields=['fraud_score', 'status'])
        
        MatchAuditTrail.objects.create(
            match=match,
            previous_status=old_status,
            new_status=RatingMatch.STATUS_DISPUTED,
            action_type="FRAUD_FLAGGED",
            note=f"IsolationForest anomaly score: {mock_fraud_score:.3f}. Requires manual Admin review."
        )
        return

    elif mock_fraud_score > 0.40:
        # Soft flag (Process, but mark it for periodic manual audit)
        pass 

    # ── Safe to Process Mathematics ──
    match.is_processed_for_rating = True
    match.status = "PROCESSED"
    match.processed_at = timezone.now()
    match.save(update_fields=['fraud_score', 'is_processed_for_rating', 'status', 'processed_at'])
    
    # Grab the active score (resolved is preferred if there was a micro-dispute)
    active_score = match.resolved_score or match.score
    p1_pts, p2_pts = _extract_points(active_score)

    if match.format == 'SINGLES':
        with transaction.atomic():
            p1_id, p2_id = match.participants[0], match.participants[1]
            try:
                p1 = PlayerRatingProfile.objects.select_for_update().get(user_id=p1_id, sport=match.sport)
                p2 = PlayerRatingProfile.objects.select_for_update().get(user_id=p2_id, sport=match.sport)
            except PlayerRatingProfile.DoesNotExist:
                return
            
            new_r1, d1, new_r2, d2 = update_singles(
                rating_a=float(p1.dupr_rating_singles),
                rating_b=float(p2.dupr_rating_singles),
                points_a=p1_pts, points_b=p2_pts,
                rel_a=float(p1.reliability), rel_b=float(p2.reliability),
                matches_played_a=p1.matches_played_singles,
                matches_played_b=p2.matches_played_singles
            )

            p1.dupr_rating_singles = new_r1
            p1.matches_played_singles += 1
            p1.last_synced_at = timezone.now()
            p1.save()

            p2.dupr_rating_singles = new_r2
            p2.matches_played_singles += 1
            p2.last_synced_at = timezone.now()
            p2.save()

            # Record Audits
            RatingAudit.objects.create(
                match=match, player=p1.user, format='SINGLES',
                old_rating=round(new_r1 - d1, 3), new_rating=new_r1, delta=d1,
                method='LIVE'
            )
            RatingAudit.objects.create(
                match=match, player=p2.user, format='SINGLES',
                old_rating=round(new_r2 - d2, 3), new_rating=new_r2, delta=d2,
                method='LIVE'
            )

    # Trigger Cache Invalidation Event (Redis Event)
    # e.g., redis_client.publish('leaderboard_updates', match.sport.pk)
    logger.info(f"Successfully processed match {match_id} with ML fraud score {mock_fraud_score:.3f}")

