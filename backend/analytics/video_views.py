import os
from django.conf import settings
from rest_framework.decorators import api_view, permission_classes, parser_classes
from rest_framework.permissions import IsAuthenticated
from rest_framework.parsers import MultiPartParser
from rest_framework.response import Response
from django.shortcuts import get_object_or_404
from sessions_log.models import MatchSession
from .models import ProcessingJob
from .tasks import process_video_task
from .camera_validator import CameraValidator


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
            
    # VALIDATION BARRIER
    validator = CameraValidator()
    result = validator.validate(video_path)
    if not result.accepted:
        try:
            os.remove(video_path)
        except OSError:
            pass # Fails gracefully if another thread/view locks it
            
        return Response({
            'error': 'validation_failed',
            'alerts': result.alerts
        }, status=400)
            
    # Dispatch to Celery — returns immediately; worker runs in a separate process
    process_video_task.delay(video_path, session.id)

    return Response({
        'session_id': session.id,
        'status': 'processing'
    })

@api_view(['GET'])
@permission_classes([IsAuthenticated])
def video_status(request, session_id):
    # Verify secure context bounds securely
    session = get_object_or_404(MatchSession, id=session_id, user=request.user)
    
    try:
        job = ProcessingJob.objects.get(session=session)
        status_data = {'status': job.status, 'error': job.error_message}
    except ProcessingJob.DoesNotExist:
        status_data = {'status': 'not_found'}
        
    return Response(status_data)
