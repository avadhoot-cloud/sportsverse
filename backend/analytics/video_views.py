import os
import threading
from django.conf import settings
from rest_framework.decorators import api_view, permission_classes, parser_classes
from rest_framework.permissions import IsAuthenticated
from rest_framework.parsers import MultiPartParser
from rest_framework.response import Response
from django.shortcuts import get_object_or_404
from sessions_log.models import MatchSession, StrokeEvent
from .models import VideoMetrics
from .video_analyzer import MatchAnalyzer

# Memory constraint threading boundary tracking explicit ids dynamically
_processing_queue = {}

def process_video_task(video_path: str, session_id: int):
    """Background processor utilizing the explicit MatchAnalyzer CV structure"""
    _processing_queue[session_id] = {'status': 'processing'}
    
    try:
        analyzer = MatchAnalyzer()
        results = analyzer.analyze_video(video_path, session_id)
        
        session = MatchSession.objects.filter(id=session_id).first()
        if session:
            # Generate bounded VideoMetrics
            VideoMetrics.objects.update_or_create(
                session=session,
                defaults=results.video_metrics
            )
            
            # Map Stroke Events strictly dynamically
            for stroke in results.stroke_events:
                StrokeEvent.objects.create(
                    session=session,
                    timestamp_ms=stroke['timestamp_ms'],
                    stroke_type=stroke['stroke_type'],
                    confidence=stroke['confidence'],
                    source='video'
                )
                
            session.is_synced = True
            session.duration_seconds = len(results.frame_annotations) # (Mocks bounding lengths loosely, safely)
            session.save()
            
        _processing_queue[session_id] = {
            'status': 'done',
            'metrics': results.video_metrics,
            'strokes_detected': len(results.stroke_events)
        }
    except Exception as e:
        _processing_queue[session_id] = {'status': 'error', 'error': str(e)}

@api_view(['POST'])
@permission_classes([IsAuthenticated])
@parser_classes([MultiPartParser])
def upload_video(request):
    session_id = request.data.get('session_id')
    video_file = request.FILES.get('video')
    
    if not session_id or not video_file:
        return Response({'error': 'session_id and video file are thoroughly required.'}, status=400)
        
    session = get_object_or_404(MatchSession, id=session_id, user=request.user)
    
    upload_dir = os.path.join(settings.MEDIA_ROOT, 'uploads')
    os.makedirs(upload_dir, exist_ok=True)
    
    video_path = os.path.join(upload_dir, f'session_{session_id}_{video_file.name}')
    
    with open(video_path, 'wb+') as f:
        for chunk in video_file.chunks():
            f.write(chunk)
            
    # Fork threading loop seamlessly executing the local analyzer
    thread = threading.Thread(target=process_video_task, args=(video_path, session.id))
    thread.daemon = True
    thread.start()
    
    return Response({
        'session_id': session.id,
        'status': 'processing'
    })

@api_view(['GET'])
@permission_classes([IsAuthenticated])
def video_status(request, session_id):
    # Verify secure context bounds securely
    get_object_or_404(MatchSession, id=session_id, user=request.user)
    
    status_data = _processing_queue.get(session_id, {'status': 'not_found'})
    return Response(status_data)
