from dataclasses import dataclass
from typing import List
from django.shortcuts import get_object_or_404
from sessions_log.models import MatchSession, StrokeEvent
from analytics.models import VideoMetrics, WatchMetrics, FusionMetrics

@dataclass
class CoachingInsight:
    category: str # 'technique', 'fitness', 'movement', 'consistency'
    severity: str # 'info', 'warning', 'critical'
    title: str
    detail_text: str
    drill_suggestion: str

class CoachingEngine:
    def analyze_session(self, session_id: int, user) -> List[dict]:
        session = get_object_or_404(MatchSession, id=session_id, user=user)
        insights = []
        
        # Guard extracts safely
        watch = WatchMetrics.objects.filter(session=session).first()
        video = VideoMetrics.objects.filter(session=session).first()
        fusion = FusionMetrics.objects.filter(session=session).first()
        
        duration_mins = session.duration_seconds / 60.0
        
        dominant_stroke = 'forehand'
        stances = list(StrokeEvent.objects.filter(session=session).values_list('stroke_type', flat=True))
        if stances:
            dominant_stroke = max(set(stances), key=stances.count)
            
        # Example 1: Timing constraint
        if fusion and fusion.timing_score < 50:
            insights.append(CoachingInsight(
                category='technique',
                severity='warning',
                title='Late Contact Point',
                detail_text=f'Your contact point is incredibly late specifically on your {dominant_stroke}.',
                drill_suggestion='Use a wall to drill early ball strikes stepping strictly forward into the shot.'
            ))
            
        # Example 2: Fatigue 
        if watch and watch.fatigue_score > 75 and duration_mins > 60:
            insights.append(CoachingInsight(
                category='fitness',
                severity='critical',
                title='Late-stage Output Collapse',
                detail_text='Fatigue significantly impacted your stroke predictability heavily past the 60-minute cutoff.',
                drill_suggestion='Incorporate HIIT cycling and target cardiovascular sustainability during off-court sessions.'
            ))
            
        # Example 3: Reaction Time
        # Since reaction time resides statically inside Dicts normally or is extracted during Fusion natively,
        # we check the backend mappings securely (it wasn't actively saved directly to a DB column previously, but we mock check evaluating conditions structurally)
        # We can analyze watch metrics directly here evaluating spikes
        if video and video.avg_reaction_time_ms > 800:
            insights.append(CoachingInsight(
                category='movement',
                severity='warning',
                title='Slow Reaction Bounds',
                detail_text='Slow reaction tracking detected across rapid baseline changes.',
                drill_suggestion='Work on split-step timing drills focusing on landing precisely as the opponent strikes.'
            ))
            
        # Example 4: Consistency
        if fusion and fusion.consistency_score < 60: # 60 -> 0.6 logically 
            insights.append(CoachingInsight(
                category='consistency',
                severity='warning',
                title='High Variance Shot Spread',
                detail_text='You have a high variance indicating structural form issues.',
                drill_suggestion='Focus on a consistent ball toss sequentially and maintain eye contact through the stroke.'
            ))
            
        # Example 5: Movement 
        if video and video.movement_distance_m < 200 and video.court_coverage_pct < 30:
            insights.append(CoachingInsight(
                category='movement',
                severity='warning',
                title='Static Court Mapping',
                detail_text='Limited court movement detected. You are remaining strictly planted.',
                drill_suggestion='Practice diagonal footwork patterns hitting across V-drills sequentially.'
            ))
            
        if not insights:
            insights.append(CoachingInsight(
                category='technique',
                severity='info',
                title='Solid Base Maintained',
                detail_text='Your analytics show a very stable structure throughout this session without massive deviations!',
                drill_suggestion='Scale up the intensity on your next run structurally.'
            ))
            
        return [i.__dict__ for i in insights]
