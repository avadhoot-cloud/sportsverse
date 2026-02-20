import 'dart:convert'; // Required for jsonDecode
import 'package:sportsverse_app/api/api_client.dart';

class PaymentApi {
  final ApiClient apiClient;

  PaymentApi(this.apiClient);

  /// Fetches financial summary for a specific batch.
  /// Hits Django View: BatchFinancialsSummaryView
  Future<Map<String, dynamic>?> getBatchFinancials({
    required String branchId,
    required String sportId,
    required String batchId,
  }) async {
    try {
      // Added '/api' prefix and ensured trailing slash '/' before query parameters
      // URL: /api/accounts/batch-financials/?branch=X&sport=Y&batch=Z
      final String url = '/api/accounts/batch-financials/?branch=$branchId&sport=$sportId&batch=$batchId';
      
      print("📡 Requesting Financials: $url");

      final response = await apiClient.get(url);
      
      print("📥 Response Status: ${response.statusCode}");

      if (response.statusCode == 200) {
        // Checking if body is a String or already a Map (depends on your ApiClient implementation)
        final dynamic responseData = response.body;
        
        if (responseData is String) {
          return jsonDecode(responseData);
        } else {
          return responseData as Map<String, dynamic>;
        }
      } else {
        print("❌ Failed to load financials. Status: ${response.statusCode}, Body: ${response.body}");
        return null;
      }
    } catch (e) {
      print("⚠️ Error fetching financials: $e");
      return null;
    }
  }

  /// Optional: Process a session payment for a student
  Future<bool> recordPayment({
    required String studentId,
    required double amount,
    required String method,
  }) async {
    try {
      final response = await apiClient.post(
        '/api/accounts/payments/',
        {
          'student_id': studentId,
          'amount': amount,
          'method': method,
        },
      );
      return response.statusCode == 201 || response.statusCode == 200;
    } catch (e) {
      print("⚠️ Error recording payment: $e");
      return false;
    }
  }
}