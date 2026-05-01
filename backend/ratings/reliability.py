"""
ratings/reliability.py

Updates PlayerRatingProfile reliability scores based on match events.
"""
from decimal import Decimal

def update_reliability(player_profile, action_type: str):
    """
    Update reliability score according to action type.
    action_type expects one of:
      - EXACT_MATCH (+1.0)
      - MINOR_DISCREPANCY (+0.5)
      - MAJOR_DISCREPANCY_FAULT (-2.0)
      - REPEAT_FAULT (-5.0)
      - IGNORED_TIMEOUT (-5.0)
      - INACTIVITY_DECAY (-1.0)
    """
    deltas = {
        "EXACT_MATCH": Decimal('1.00'),
        "MINOR_DISCREPANCY": Decimal('0.50'),
        "MAJOR_DISCREPANCY_FAULT": Decimal('-2.00'),
        "REPEAT_FAULT": Decimal('-5.00'),
        "IGNORED_TIMEOUT": Decimal('-5.00'),
        "INACTIVITY_DECAY": Decimal('-1.00'),
    }
    
    delta = deltas.get(action_type, Decimal('0.00'))
    new_rel = Decimal(str(player_profile.reliability)) + delta  # Cast to Decimal safely
    
    # Cap between 0 and 100
    player_profile.reliability = max(Decimal('0.00'), min(Decimal('100.00'), new_rel))
    player_profile.save(update_fields=['reliability'])
    return player_profile.reliability
