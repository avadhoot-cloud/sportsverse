import logging
from decimal import Decimal
from ratings.models import RatingMatch

logger = logging.getLogger(__name__)

def calculate_fairness_index(player_profile):
    """
    Calculates the Match Fairness Index for a given player profile based on recent matches.
    """
    # Fetch recent confirmed/resolved singles matches involving the player
    matches = RatingMatch.objects.filter(
        format=RatingMatch.FORMAT_SINGLES,
        participants__contains=player_profile.user.pk,
        status__in=[RatingMatch.STATUS_CONFIRMED, RatingMatch.STATUS_AUTO_RESOLVED, RatingMatch.STATUS_ADMIN_RESOLVED]
    ).order_by('-date')[:20]  # Look at the last 20 matches

    if not matches:
        return {
            "category": "Insufficient Data",
            "avg_rating_diff": 0.0,
            "lower_rated_pct": 0.0,
            "blowout_pct": 0.0,
            "close_match_pct": 0.0
        }

    total_rating_diff = Decimal('0.0')
    lower_rated_count = 0
    blowout_count = 0
    close_match_count = 0
    valid_matches_count = 0
    total_sets = 0

    from ratings.models import PlayerRatingProfile

    for match in matches:
        try:
            # Determine opponent
            participants = list(match.participants)
            if player_profile.user.pk in participants:
                participants.remove(player_profile.user.pk)
            
            if not participants:
                continue

            opponent_pk = participants[0]
            opponent_profile = PlayerRatingProfile.objects.filter(
                user_id=opponent_pk, 
                sport=match.sport, 
                organization=match.organization
            ).first()

            if opponent_profile:
                # Rating diff logic
                diff = player_profile.dupr_rating_singles - opponent_profile.dupr_rating_singles
                total_rating_diff += diff
                if diff > Decimal('0.2'): # Playing significantly lower rated opponent
                    lower_rated_count += 1
                valid_matches_count += 1

            # Score analysis
            score_data = match.resolved_score or match.score
            if not score_data or 'sets' not in score_data:
                continue

            for s in score_data.get('sets', []):
                total_sets += 1
                r_score = int(s.get('reporter_score', 0))
                o_score = int(s.get('opponent_score', 0))

                # If the player is the reporter
                if match.submitted_by_id == player_profile.user.pk:
                    p_score = r_score
                    op_score = o_score
                else:
                    p_score = o_score
                    op_score = r_score

                point_diff = abs(p_score - op_score)
                if point_diff >= 7: # Blowout
                    blowout_count += 1
                elif point_diff <= 2: # Close match
                    close_match_count += 1

        except Exception as e:
            logger.warning(f"Fairness index calculation error for match {match.pk}: {str(e)}")
            continue

    if valid_matches_count == 0 or total_sets == 0:
        return {
            "category": "Insufficient Data",
            "avg_rating_diff": 0.0,
            "lower_rated_pct": 0.0,
            "blowout_pct": 0.0,
            "close_match_pct": 0.0
        }

    avg_diff = float(total_rating_diff / valid_matches_count)
    lower_pct = (lower_rated_count / valid_matches_count) * 100
    blowout_pct = (blowout_count / total_sets) * 100
    close_pct = (close_match_count / total_sets) * 100

    # Categorization Logic
    category = "Balanced Competitor"
    color = "blue"

    if lower_pct >= 80 and blowout_pct >= 50:
        category = "Rating Farmer Risk"
        color = "red"
    elif lower_pct >= 60 or blowout_pct >= 40:
        category = "Selective Competitor"
        color = "yellow"

    return {
        "category": category,
        "color": color,
        "avg_rating_diff": round(avg_diff, 2),
        "lower_rated_pct": round(lower_pct, 1),
        "blowout_pct": round(blowout_pct, 1),
        "close_match_pct": round(close_pct, 1)
    }
