from django.urls import path
from .views import AIChatBotView

urlpatterns = [
    path('ai-assistant/', AIChatBotView.as_view(), name='ai_assistant'),
    # Backward-compatible alias
    path('chatbot/query/', AIChatBotView.as_view(), name='chatbot-query'),
]
