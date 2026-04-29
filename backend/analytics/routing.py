from django.urls import re_path
from . import consumers

websocket_urlpatterns = [
    re_path(r'ws/video/status/(?P<session_id>[^/]+)/$', consumers.JobStatusConsumer.as_asgi()),
]
