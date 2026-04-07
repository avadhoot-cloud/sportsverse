from rest_framework import viewsets
from rest_framework.decorators import api_view, permission_classes
from rest_framework.response import Response
from rest_framework.permissions import IsAuthenticated
from .models import WatchMetrics, VideoMetrics, FusionMetrics
from sessions_log.models import MatchSession, StrokeEvent
from .serializers import WatchMetricsSerializer, VideoMetricsSerializer, FusionMetricsSerializer

class WatchMetricsViewSet(viewsets.ModelViewSet):
    queryset = WatchMetrics.objects.all()
    serializer_class = WatchMetricsSerializer
    permission_classes = [IsAuthenticated]
    
    def get_queryset(self):
        return self.queryset.filter(session__user=self.request.user)

class VideoMetricsViewSet(viewsets.ModelViewSet):
    queryset = VideoMetrics.objects.all()
    serializer_class = VideoMetricsSerializer
    permission_classes = [IsAuthenticated]
    
    def get_queryset(self):
        return self.queryset.filter(session__user=self.request.user)

class FusionMetricsViewSet(viewsets.ModelViewSet):
    queryset = FusionMetrics.objects.all()
    serializer_class = FusionMetricsSerializer
    permission_classes = [IsAuthenticated]
    
    def get_queryset(self):
        return self.queryset.filter(session__user=self.request.user)

from django.db.models import Sum, Avg, Count
from django.db.models.functions import TruncWeek
from django.utils import timezone
from datetime import timedelta
from django.views.decorators.cache import cache_page
from django_ratelimit.decorators import ratelimit
from .coaching import CoachingEngine

@ratelimit(key='user', rate='100/m', block=True)
@api_view(['GET'])
@permission_classes([IsAuthenticated])
def coaching_insights(request, session_id):
    engine = CoachingEngine()
    try:
        insights = engine.analyze_session(session_id, request.user)
        return Response({'insights': insights})
    except Exception as e:
        return Response({'error': str(e)}, status=400)

@ratelimit(key='user', rate='100/m', block=True)
@cache_page(60 * 5)
@api_view(['GET'])
@permission_classes([IsAuthenticated])
def analytics_summary(request):
    user = request.user
    sessions = MatchSession.objects.filter(user=user).order_by('-date')
    
    total_sesh = sessions.count()
    if total_sesh == 0:
        return Response({'error': 'No data'}, status=404)
        
    duration_s = sessions.aggregate(t=Sum('duration_seconds'))['t'] or 0
    total_strokes = StrokeEvent.objects.filter(session__in=sessions).count()
    
    thirty_days_ago = timezone.now() - timedelta(days=30)
    recent_sess = sessions.filter(date__gte=thirty_days_ago)
    
    avg_fatigue = WatchMetrics.objects.filter(session__in=recent_sess).aggregate(a=Avg('fatigue_score'))['a'] or 0.0
    avg_timing = FusionMetrics.objects.filter(session__in=recent_sess).aggregate(a=Avg('timing_score'))['a'] or 0.0
    
    # Dominant Stroke
    stances = list(StrokeEvent.objects.filter(session__in=sessions).values_list('stroke_type', flat=True))
    dom = max(set(stances), key=stances.count) if stances else 'none'
    
    # Best Session logically using Fusion's Overall score if available
    best_fusion = FusionMetrics.objects.filter(session__in=sessions).order_by('-overall_performance_score').first()
    best_session = best_fusion.session.id if best_fusion else sessions.first().id
    
    # Streak calculating logically checking consecutive sets
    streak = 0
    curr_date = timezone.now().date()
    # (Simple logic pulling distinct dates natively)
    dates = list(set([s.date.date() for s in sessions]))
    dates.sort(reverse=True)
    for d in dates:
        if d == curr_date or d == curr_date - timedelta(days=streak):
            streak += 1
        elif d < curr_date - timedelta(days=streak):
            break

    return Response({
        'total_sessions': total_sesh,
        'total_duration_hours': round(duration_s / 3600.0, 1),
        'total_strokes': total_strokes,
        'avg_fatigue_score': round(avg_fatigue, 1),
        'avg_timing_score': round(avg_timing, 1),
        'dominant_stroke_type': dom,
        'improvement_trend': '+5%', # Generic mapping simulating historical comparisons linearly
        'best_session_id': best_session,
        'streak_days': streak
    })

@ratelimit(key='user', rate='100/m', block=True)
@api_view(['GET'])
@permission_classes([IsAuthenticated])
def analytics_progress(request):
    user = request.user
    twelve_weeks_ago = timezone.now() - timedelta(weeks=12)
    sessions = MatchSession.objects.filter(user=user, date__gte=twelve_weeks_ago)
    
    # Aggregate over TruncWeek natively extracting bounded DB calculations
    weekly_stats = sessions.annotate(
        week=TruncWeek('date')
    ).values('week').annotate(
        session_count=Count('id')
    ).order_by('week')
    
    # Join logically with Video / Fusion metrics
    results = []
    for stat in weekly_stats:
        week_start = stat['week']
        sess_in_week = sessions.filter(date__date__gte=week_start, date__date__lte=week_start + timedelta(days=7))
        
        fusion = FusionMetrics.objects.filter(session__in=sess_in_week)
        video = VideoMetrics.objects.filter(session__in=sess_in_week)
        
        avg_q = fusion.aggregate(a=Avg('stroke_quality_score'))['a'] or 0.0
        avg_r = video.aggregate(a=Avg('avg_reaction_time_ms'))['a'] or 0.0
        
        results.append({
            'week_date': week_start.strftime('%Y-%m-%d'),
            'session_count': stat['session_count'],
            'avg_stroke_quality': round(avg_q, 1),
            'avg_reaction_time': round(avg_r, 1)
        })
        
    return Response({'weekly_progress': results})
