"""
WebSocket consumer for real-time video processing status.

Security: The consumer validates that the connecting user owns the session
(via JWT token in the query string). Session IDs are UUIDs, but we enforce
ownership explicitly — if IDs were ever sequential integers, a bare UUID
check would be a data leak.

Connection URL: ws://<host>/ws/video/status/<session_id>/?token=<jwt>
"""
import json
from channels.generic.websocket import AsyncWebsocketConsumer
from channels.db import database_sync_to_async
from django.contrib.auth.models import AnonymousUser


class JobStatusConsumer(AsyncWebsocketConsumer):

    async def connect(self):
        self.session_id = self.scope['url_route']['kwargs']['session_id']
        self.group_name = f"job_{self.session_id}"

        # ── Auth gate ────────────────────────────────────────────────────────
        user = self.scope.get('user', AnonymousUser())
        if user is None or not user.is_authenticated:
            await self.close(code=4001)  # 4001 = unauthorized (custom code)
            return

        # ── Ownership validation ─────────────────────────────────────────────
        owns_session = await self._user_owns_session(user, self.session_id)
        if not owns_session:
            await self.close(code=4003)  # 4003 = forbidden
            return

        await self.channel_layer.group_add(self.group_name, self.channel_name)
        await self.accept()

        # Immediately send current job status so the client doesn't have to wait
        # for the next Celery broadcast if the job is already done
        current = await self._get_current_status(self.session_id)
        if current:
            await self.send(text_data=json.dumps(current))

    async def disconnect(self, close_code):
        if hasattr(self, 'group_name'):
            await self.channel_layer.group_discard(self.group_name, self.channel_name)

    # Called by Celery task via channel_layer.group_send
    async def job_update(self, event):
        await self.send(text_data=json.dumps({
            'status': event['status'],
            'error': event.get('error'),
        }))

    # ── DB helpers ───────────────────────────────────────────────────────────

    @database_sync_to_async
    def _user_owns_session(self, user, session_id):
        from sessions_log.models import MatchSession
        return MatchSession.objects.filter(
            id=session_id, user=user
        ).exists()

    @database_sync_to_async
    def _get_current_status(self, session_id):
        from analytics.models import ProcessingJob
        from sessions_log.models import MatchSession
        try:
            session = MatchSession.objects.get(id=session_id)
            job = ProcessingJob.objects.get(session=session)
            return {'status': job.status, 'error': job.error_message}
        except (MatchSession.DoesNotExist, ProcessingJob.DoesNotExist):
            return None
