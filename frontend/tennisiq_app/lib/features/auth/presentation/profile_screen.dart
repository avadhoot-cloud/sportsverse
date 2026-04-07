import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../providers/auth_provider.dart';
import '../providers/profile_provider.dart';
import '../../dashboard/providers/dashboard_provider.dart';

class ProfileScreen extends ConsumerWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profileAsync = ref.watch(profileProvider);
    final statsAsync = ref.watch(dashboardStatsProvider);

    return Scaffold(
      body: SafeArea(
        child: profileAsync.when(
          data: (user) => Padding(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                const SizedBox(height: 24),
                CircleAvatar(
                  radius: 50,
                  backgroundColor: const Color(0xFF00E5A0),
                  child: Text(
                    user['first_name'] != null && user['first_name'].isNotEmpty 
                        ? user['first_name'][0].toUpperCase()
                        : user['username'][0].toUpperCase(),
                    style: const TextStyle(fontSize: 40, color: Color(0xFF0D1117), fontWeight: FontWeight.bold),
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  '${user['first_name']} ${user['last_name']}',
                  style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Colors.white),
                ),
                const SizedBox(height: 8),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    _Badge(label: user['skill_level'].toString().toUpperCase()),
                    const SizedBox(width: 8),
                    _Badge(label: user['dominant_hand'] == 'left' ? 'LEFT-HANDED' : 'RIGHT-HANDED', color: Colors.blueAccent),
                  ],
                ),
                const SizedBox(height: 32),
                
                // Stats Summary Matrix
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: statsAsync.when(
                      data: (stats) => Column(
                        children: [
                          _StatRow(label: 'Total Sessions', value: stats['total_sessions'].toString()),
                          const Divider(color: Colors.white12),
                          _StatRow(label: 'Total Strokes Recorded', value: stats['total_strokes'].toString()),
                          const Divider(color: Colors.white12),
                          _StatRow(label: 'Avg Fatigue Score', value: stats['avg_fatigue_score'].toString()),
                        ],
                      ),
                      loading: () => const Center(child: CircularProgressIndicator()),
                      error: (e, __) => const Text('Could not load stats'),
                    ),
                  ),
                ),
                
                const Spacer(),
                ElevatedButton.icon(
                  onPressed: () {
                    ref.read(authProvider.notifier).logout();
                  },
                  icon: const Icon(Icons.logout),
                  label: const Text('LOGOUT'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.redAccent,
                    foregroundColor: Colors.white,
                    minimumSize: const Size(double.infinity, 50),
                  ),
                ),
                const SizedBox(height: 24),
              ],
            ),
          ),
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (e, __) => Center(child: Text('Error loading profile: $e', style: const TextStyle(color: Colors.white))),
        ),
      ),
    );
  }
}

class _Badge extends StatelessWidget {
  final String label;
  final Color color;
  const _Badge({required this.label, this.color = const Color(0xFF00E5A0)});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: color.withOpacity(0.2),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color, width: 1),
      ),
      child: Text(label, style: TextStyle(color: color, fontSize: 12, fontWeight: FontWeight.bold)),
    );
  }
}

class _StatRow extends StatelessWidget {
  final String label;
  final String value;
  const _StatRow({required this.label, required this.value});
  
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(color: Colors.white70, fontSize: 16)),
          Text(value, style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }
}
