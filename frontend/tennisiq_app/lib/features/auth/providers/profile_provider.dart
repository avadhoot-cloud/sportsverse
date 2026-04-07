import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'auth_provider.dart';

final profileProvider = FutureProvider.autoDispose<Map<String, dynamic>>((ref) async {
  final api = ref.watch(apiServiceProvider);
  final response = await api.client.get('/auth/me/');
  return response.data;
});
