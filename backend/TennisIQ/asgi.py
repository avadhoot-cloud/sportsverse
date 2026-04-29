"""
ASGI config for TennisIQ — handles both HTTP (DRF) and WebSocket (Channels).

WebSocket auth relies on JWTAuthMiddleware wrapping the URL router so that
self.scope['user'] is populated before JobStatusConsumer.connect() runs.
"""
import os
import django
from django.core.asgi import get_asgi_application
from channels.routing import ProtocolTypeRouter, URLRouter
from channels.security.websocket import AllowedHostsOriginValidator

os.environ.setdefault('DJANGO_SETTINGS_MODULE', 'TennisIQ.settings')
django.setup()

# Import routing AFTER django.setup() so models are loaded
from analytics.routing import websocket_urlpatterns
from .jwt_middleware import JWTAuthMiddlewareStack

application = ProtocolTypeRouter({
    # All standard HTTP traffic goes through the normal Django stack unchanged
    'http': get_asgi_application(),

    # WebSocket traffic is wrapped in:
    # 1. AllowedHostsOriginValidator — rejects connections from unexpected origins
    # 2. JWTAuthMiddlewareStack — populates scope['user'] from ?token= query param
    'websocket': AllowedHostsOriginValidator(
        JWTAuthMiddlewareStack(
            URLRouter(websocket_urlpatterns)
        )
    ),
})
