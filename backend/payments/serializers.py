from rest_framework import serializers
from .models import FeeTransaction

class StudentFeeSerializer(serializers.ModelSerializer):
    # Pulling the academy name from the linked organization
    academy_name = serializers.CharField(source='organization.academy_name', read_only=True)
    
    class Meta:
        model = FeeTransaction
        fields = [
            'id', 'amount', 'transaction_date', 
            'due_date', 'is_paid', 'payment_method', 
            'receipt_number', 'academy_name'
        ]