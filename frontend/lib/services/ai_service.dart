// lib/services/ai_service.dart
//
// ChatbotService — posts user messages to the Django /api/chatbot/query/ endpoint.
// Uses apiClient (singleton) so the DRF auth token is always injected automatically.
// Throws typed exceptions so ChatbotProvider can surface the right UI state.

import 'dart:async';
import 'dart:convert';
import 'package:sportsverse_app/api/api_client.dart';

// ── Typed Exceptions ──────────────────────────────────────────────────────────

class SessionExpiredException implements Exception {
  const SessionExpiredException();
  @override
  String toString() => 'Session expired. Please log in again.';
}

class ChatbotException implements Exception {
  final String message;
  final int? statusCode;
  const ChatbotException(this.message, {this.statusCode});
  @override
  String toString() => message;
}

// ── Service ───────────────────────────────────────────────────────────────────

class ChatbotService {
  Timer? _debounce;

  /// Sends a query to the backend chatbot endpoint.
  /// Returns the assistant's natural-language response string.
  Future<String> sendQuery(String text) async {
    try {
      final response = await apiClient.post(
        'api/ai-assistant',
        {'query': text},
      );

      switch (response.statusCode) {
        case 200:
          final data = jsonDecode(response.body) as Map<String, dynamic>;
          return data['response'] as String? ?? 'No response received.';

        case 401:
          throw const SessionExpiredException();

        case 403:
          final data = jsonDecode(response.body) as Map<String, dynamic>?;
          throw ChatbotException(
            data?['response'] ?? "You don't have permission to access that.",
            statusCode: 403,
          );

        case 404:
          throw const ChatbotException(
            'No records found for that query.',
            statusCode: 404,
          );

        case 500:
          throw const ChatbotException(
            'Something went wrong on the server. Please try again.',
            statusCode: 500,
          );

        default:
          throw ChatbotException(
            'Unexpected error (HTTP ${response.statusCode}).',
            statusCode: response.statusCode,
          );
      }
    } on SessionExpiredException {
      rethrow;
    } on ChatbotException {
      rethrow;
    } catch (e) {
      throw ChatbotException('The AI assistant is temporarily unavailable. Please try again.');
    }
  }

  void dispose() {
    _debounce?.cancel();
  }
}

/// Global singleton shared with the provider.
final chatbotService = ChatbotService();