import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../auth/providers/auth_provider.dart';

// Provider to fetch all session history (pagination simulation via filtering for now)
final historyProvider = FutureProvider.autoDispose<List<dynamic>>((ref) async {
  final api = ref.watch(apiServiceProvider);
  final response = await api.client.get('/sessions/sessions/');
  return response.data as List<dynamic>;
});
