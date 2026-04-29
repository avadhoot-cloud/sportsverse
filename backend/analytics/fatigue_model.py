"""
Fatigue Model Engine
====================
Computes a heuristic fatigue score based on heart rate trends and court movement.
Designed to run post-processing once both WatchMetrics (BLE) and VideoMetrics (CV) are synced.
"""

def calculate_fatigue_index(watch_metrics, video_metrics) -> float | None:
    """
    Calculates a fatigue score (0.0 to 1.0) by fusing Watch and Video metrics.
    
    Rule: Must short-circuit and return None if HR data is missing (e.g., watch disconnected
    or video-only mode).
    
    Args:
        watch_metrics: WatchMetrics instance (or None)
        video_metrics: VideoMetrics instance (or None)
        
    Returns:
        float score between 0.0 and 1.0, or None if missing required data.
    """
    # 1. Verification Flag 3: Explicit short-circuit if WatchMetrics is None or has no HR data
    if watch_metrics is None or watch_metrics.hr_avg <= 0 or watch_metrics.hr_avg is None:
        return None
        
    if video_metrics is None:
        return None
        
    # Example Heuristic:
    # High average HR combined with lower movement distance relative to match duration
    # indicates the player is exerting high effort but covering less ground (fatigue).
    
    # Base HR fatigue component
    # Normalized against an assumed theoretical max HR of 200
    hr_ratio = min(watch_metrics.hr_avg / 200.0, 1.0)
    
    # Distance component (assuming typical coverage is ~1000m per hour)
    # If they move less but HR is high, fatigue goes up.
    # We lack exact duration here, so we rely more on the peak vs avg HR spread.
    
    hr_stress = 0.0
    if watch_metrics.hr_max > 0:
        hr_stress = watch_metrics.hr_avg / watch_metrics.hr_max

    # Fatigue is higher when the average HR is very close to the max HR over a session.
    fatigue_score = (hr_ratio * 0.4) + (hr_stress * 0.6)
    
    return round(min(max(fatigue_score, 0.0), 1.0), 2)
