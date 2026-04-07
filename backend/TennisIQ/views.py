from rest_framework.decorators import api_view, permission_classes
from rest_framework.permissions import AllowAny
from rest_framework.response import Response
from django.utils import timezone
from django.db import connection

@api_view(['GET'])
@permission_classes([AllowAny])
def health_check(request):
    db_status = 'ok'
    try:
        connection.ensure_connection()
    except Exception:
        db_status = 'offline'

    return Response({
        'status': 'ok',
        'db': db_status,
        'timestamp': timezone.now()
    })
