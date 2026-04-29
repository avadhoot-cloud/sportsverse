import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../auth/providers/auth_provider.dart';

final sessionDetailProvider = FutureProvider.family<Map<String, dynamic>, String>((ref, sessionId) async {
  final api = ref.read(apiServiceProvider);
  try {
    final response = await api.client.get('/sessions/sessions/$sessionId/details_ui/');
    return response.data as Map<String, dynamic>;
  } catch (e) {
    throw Exception('Failed to load session details: $e');
  }
});
