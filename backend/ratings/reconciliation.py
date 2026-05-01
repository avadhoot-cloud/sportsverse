"""
ratings/reconciliation.py

Weighted reconciliation logic for minor dispute handling in match scores.
"""

def reconcile_scores(reported_score: dict, opponent_score: dict, rel_reporter: float, rel_opponent: float):
    """
    Weighted reconciliation for minor point differences.
    Returns: {"sets": [...]} or None if the difference is too large.
    """
    if not reported_score or not opponent_score or "sets" not in reported_score or "sets" not in opponent_score:
        return None
        
    final_sets = []
    # Assumes both arrays have the same length and order
    for r_set, o_set in zip(reported_score.get("sets", []), opponent_score.get("sets", [])):
        diff_re = abs(r_set["reporter_score"] - o_set["reporter_score"])
        diff_op = abs(r_set["opponent_score"] - o_set["opponent_score"])
        
        # If difference goes beyond 2 points in any metric, escalate to Admin.
        if diff_re > 2 or diff_op > 2:
            return None 

        weight_total = float(rel_reporter) + float(rel_opponent)
        if weight_total == 0:
            weight_total = 1.0 # prevent div zero
            
        final_re_score = round(((r_set["reporter_score"] * float(rel_reporter)) + (o_set["reporter_score"] * float(rel_opponent))) / weight_total)
        final_op_score = round(((r_set["opponent_score"] * float(rel_reporter)) + (o_set["opponent_score"] * float(rel_opponent))) / weight_total)
        
        final_sets.append({
            "set": r_set["set"],
            "reporter_score": final_re_score,
            "opponent_score": final_op_score
        })
    return {"sets": final_sets}
