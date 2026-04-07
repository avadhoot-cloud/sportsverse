import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../auth/providers/auth_provider.dart';

final dashboardStatsProvider = FutureProvider.autoDispose<Map<String, dynamic>>((ref) async {
  final api = ref.watch(apiServiceProvider);
  final response = await api.client.get('/analytics/summary/');
  return response.data;
});

final recentSessionsProvider = FutureProvider.autoDispose<List<dynamic>>((ref) async {
  final api = ref.watch(apiServiceProvider);
  final response = await api.client.get('/sessions/sessions/');
  // limit to last 5 internally or from back end
  final List<dynamic> results = response.data;
  return results.take(5).toList();
});
