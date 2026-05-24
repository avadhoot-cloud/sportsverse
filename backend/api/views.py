# backend/api/views.py
from rest_framework.views import APIView
from rest_framework.response import Response
from rest_framework.permissions import IsAuthenticated
from rest_framework.authentication import TokenAuthentication
from rest_framework import status
from .ai_utils import process_bot_request
import logging

logger = logging.getLogger(__name__)


class AIChatBotView(APIView):
    authentication_classes = [TokenAuthentication]
    permission_classes = [IsAuthenticated]

    def post(self, request):
        allowed_types = ('ACADEMY_ADMIN', 'COACH', 'PLATFORM_ADMIN')
        if request.user.user_type not in allowed_types:
            return Response(
                {"error": "Chatbot is available for Academy Admins and Coaches only."},
                status=status.HTTP_403_FORBIDDEN,
            )

        try:
            profile = request.user.academy_admin_profile
            org_id = profile.organization_id
            org_name = profile.organization.academy_name
        except AttributeError:
            try:
                profile = request.user.coach_profile
                org_id = profile.organization_id
                org_name = profile.organization.academy_name
            except AttributeError:
                return Response({"error": "Profile not found."}, status=status.HTTP_400_BAD_REQUEST)

        query = request.data.get('query', '').strip()
        if not query:
            return Response({"error": "No query provided"}, status=status.HTTP_400_BAD_REQUEST)

        if len(query) > 500:
            return Response(
                {"error": "Query too long (max 500 characters)"},
                status=status.HTTP_400_BAD_REQUEST,
            )

        logger.info(f"Chatbot query from org {org_id}: '{query[:50]}...'")

        try:
            bot_message = process_bot_request(query, org_id, org_name)
            return Response({
                "response": bot_message,
                "query": query,
                "org": org_name,
            })
        except Exception as e:
            logger.error(f"Chatbot error: {e}")
            return Response({
                "response": "I encountered an issue processing your request. Please try again.",
                "error": str(e),
            }, status=status.HTTP_200_OK)
