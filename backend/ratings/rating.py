"""
ratings/rating.py

DUPR-style rating engine using point percentages and margin-of-victory scaling.
All functions are pure and deterministic.
"""
import math
from typing import List, Tuple

# Constants
SCALE_DIVISOR = 0.5  # D in the expected score formula
K_BASE = 0.20
K_PROVISIONAL = 0.40
PROVISIONAL_THRESHOLD = 10

def expected_points_percentage(rating_a: float, rating_b: float) -> float:
    """Expected percentage of total points player A will win."""
    return 1.0 / (1.0 + math.pow(10.0, (rating_b - rating_a) / SCALE_DIVISOR))

def actual_points_percentage(points_a: int, points_b: int) -> float:
    """Actual percentage of total points won by player A."""
    total = points_a + points_b
    if total == 0:
        return 0.5
    return points_a / total

def get_k_factor(matches_played: int) -> float:
    return K_PROVISIONAL if matches_played < PROVISIONAL_THRESHOLD else K_BASE

def margin_of_victory_multiplier(points_a: int, points_b: int) -> float:
    """MOV = ln(1 + |Points_A - Points_B|) + 1"""
    return math.log(1.0 + abs(points_a - points_b)) + 1.0

def reliability_weight(rel_a: float, rel_b: float) -> float:
    """W_Rel = (Rel_A + Rel_B) / 200"""
    return (float(rel_a) + float(rel_b)) / 200.0

def calculate_rating_delta(
    rating_a: float, rating_b: float,
    points_a: int, points_b: int,
    rel_a: float, rel_b: float,
    matches_played_a: int, matches_played_b: int
) -> Tuple[float, float]:
    """
    Returns (delta_a, delta_b)
    """
    ea = expected_points_percentage(rating_a, rating_b)
    sa = actual_points_percentage(points_a, points_b)
    
    mov = margin_of_victory_multiplier(points_a, points_b)
    w_rel = reliability_weight(rel_a, rel_b)
    
    k_a = get_k_factor(matches_played_a)
    delta_a = k_a * mov * w_rel * (sa - ea)
    
    # zero-sum symmetric
    k_b = get_k_factor(matches_played_b)
    eb = 1.0 - ea
    sb = 1.0 - sa
    delta_b = k_b * mov * w_rel * (sb - eb)
    
    return delta_a, delta_b

def update_singles(
    rating_a: float, rating_b: float,
    points_a: int, points_b: int,
    rel_a: float, rel_b: float,
    matches_played_a: int, matches_played_b: int
) -> Tuple[float, float, float, float]:
    """
    Returns (new_rating_a, delta_a, new_rating_b, delta_b)
    """
    delta_a, delta_b = calculate_rating_delta(
        rating_a, rating_b, points_a, points_b, rel_a, rel_b, matches_played_a, matches_played_b
    )
    # Ensure ratings stay between 2.000 and 8.000
    new_a = max(2.0, min(8.0, rating_a + delta_a))
    new_b = max(2.0, min(8.0, rating_b + delta_b))
    return round(new_a, 3), round(delta_a, 3), round(new_b, 3), round(delta_b, 3)

def update_doubles(
    team_a_ratings: List[float], team_b_ratings: List[float],
    points_a: int, points_b: int,
    rel_a: List[float], rel_b: List[float],
    matches_played_a: List[int], matches_played_b: List[int]
) -> Tuple[List[float], List[float], List[float], List[float]]:
    """
    Returns (new_ratings_a, deltas_a, new_ratings_b, deltas_b)
    """
    avg_rating_a = sum(team_a_ratings) / 2.0
    avg_rating_b = sum(team_b_ratings) / 2.0
    avg_rel_a = sum(rel_a) / 2.0
    avg_rel_b = sum(rel_b) / 2.0
    
    ea = expected_points_percentage(avg_rating_a, avg_rating_b)
    sa = actual_points_percentage(points_a, points_b)
    mov = margin_of_victory_multiplier(points_a, points_b)
    w_rel = reliability_weight(avg_rel_a, avg_rel_b)
    
    deltas_a = []
    new_ratings_a = []
    for i, r_a in enumerate(team_a_ratings):
        k = get_k_factor(matches_played_a[i])
        d = k * mov * w_rel * (sa - ea)
        deltas_a.append(round(d, 3))
        new_ratings_a.append(max(2.0, min(8.0, round(r_a + d, 3))))
        
    eb = 1.0 - ea
    sb = 1.0 - sa
    deltas_b = []
    new_ratings_b = []
    for i, r_b in enumerate(team_b_ratings):
        k = get_k_factor(matches_played_b[i])
        d = k * mov * w_rel * (sb - eb)
        deltas_b.append(round(d, 3))
        new_ratings_b.append(max(2.0, min(8.0, round(r_b + d, 3))))
        
    return new_ratings_a, deltas_a, new_ratings_b, deltas_b
