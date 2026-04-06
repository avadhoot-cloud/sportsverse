from rest_framework.views import APIView
from rest_framework.response import Response
from .ai_utils import process_bot_request
from rest_framework.permissions import IsAuthenticated,AllowAny
from rest_framework.authentication import TokenAuthentication


class AIChatBotView(APIView):
    authentication_classes = [TokenAuthentication] # Ensure this is here
    permission_classes = [AllowAny]
    def post(self, request):
        query = request.data.get('query')
        if not query:
            return Response({"error": "No query provided"}, status=400)
            
        bot_message = process_bot_request(query)
        return Response({"response": bot_message})