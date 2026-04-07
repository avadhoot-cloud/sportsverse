from django.urls import path
from .views import coaching_insights

urlpatterns = [
    path('insights/<int:session_id>/', coaching_insights, name='coaching_insights'),
]
