import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/dashboard_provider.dart';
import '../../auth/providers/profile_provider.dart';

class DashboardScreen extends ConsumerWidget {
  const DashboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profileAsync = ref.watch(profileProvider);
    final statsAsync = ref.watch(dashboardStatsProvider);
    final recentAsync = ref.watch(recentSessionsProvider);

    return Scaffold(
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () {
          // Switch tab handling should be done via navigator or parent 
          // For now, prompt the user. Tab switching handled in home_screen
        },
        backgroundColor: const Color(0xFF00E5A0),
        icon: const Icon(Icons.play_arrow, color: Color(0xFF0D1117)),
        label: const Text('Start Session', style: TextStyle(color: Color(0xFF0D1117), fontWeight: FontWeight.bold)),
      ),
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: () async {
            ref.invalidate(dashboardStatsProvider);
            ref.invalidate(recentSessionsProvider);
            ref.invalidate(profileProvider);
          },
          child: ListView(
            padding: const EdgeInsets.all(16.0),
            children: [
              // Greeting
              profileAsync.when(
                data: (user) => Text(
                  'Hello, ${user['first_name'] ?? user['username']} 👋',
                  style: const TextStyle(fontSize: 28, fontWeight: FontWeight.bold, color: Colors.white),
                ),
                loading: () => const _SkeletonBox(height: 30, width: 200),
                error: (_, __) => const Text('Hello 👋', style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold, color: Colors.white)),
              ),
              const SizedBox(height: 24),
              
              const Text('Quick Stats', style: TextStyle(fontSize: 18, color: Colors.white70, fontWeight: FontWeight.w600)),
              const SizedBox(height: 12),
              
              // Quick Stats Row
              statsAsync.when(
                data: (stats) => Row(
                  children: [
                    Expanded(child: _StatCard(title: 'Sessions', value: stats['total_sessions'].toString())),
                    const SizedBox(width: 12),
                    Expanded(child: _StatCard(title: 'Strokes', value: stats['total_strokes'].toString())),
                    const SizedBox(width: 12),
                    Expanded(child: _StatCard(title: 'Fatigue', value: stats['avg_fatigue_score'].toString())),
                  ],
                ),
                loading: () => const Row(
                  children: [
                    Expanded(child: _SkeletonBox(height: 100)),
                    SizedBox(width: 12),
                    Expanded(child: _SkeletonBox(height: 100)),
                    SizedBox(width: 12),
                    Expanded(child: _SkeletonBox(height: 100)),
                  ],
                ),
                error: (e, __) => Card(child: Padding(padding: const EdgeInsets.all(16), child: Text('Failed to load stats $e'))),
              ),

              const SizedBox(height: 32),
              
              const Text('Recent Sessions', style: TextStyle(fontSize: 18, color: Colors.white70, fontWeight: FontWeight.w600)),
              const SizedBox(height: 12),
              
              // Recent Sessions List
              recentAsync.when(
                data: (sessions) {
                  if (sessions.isEmpty) {
                    return const Padding(
                      padding: EdgeInsets.all(32.0),
                      child: Center(child: Text('No sessions recorded yet.', style: TextStyle(color: Colors.white54))),
                    );
                  }
                  return ListView.builder(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: sessions.length,
                    itemBuilder: (context, index) {
                      final s = sessions[index];
                      // Format date minimally
                      final dateStr = s['date'].toString().split('T')[0];
                      return Card(
                        margin: const EdgeInsets.only(bottom: 8),
                        child: ListTile(
                          leading: Icon(
                            s['mode'] == 'video_only' ? Icons.videocam : (s['mode'] == 'watch_only' ? Icons.watch : Icons.merge_type),
                            color: const Color(0xFF00E5A0),
                          ),
                          title: Text('Date: $dateStr', style: const TextStyle(fontWeight: FontWeight.bold)),
                          subtitle: Text('Duration: ${s['duration_seconds']} sec'),
                          trailing: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(
                              color: const Color(0xFF00E5A0).withOpacity(0.2),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Text(s['mode'].toString().toUpperCase(), style: const TextStyle(color: Color(0xFF00E5A0), fontSize: 10, fontWeight: FontWeight.bold)),
                          ),
                        ),
                      );
                    },
                  );
                },
                loading: () => Column(children: List.generate(3, (index) => const Padding(padding: EdgeInsets.only(bottom: 8.0), child: _SkeletonBox(height: 70)))),
                error: (e, _) => const Center(child: Text('Could not load sessions')),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _StatCard extends StatelessWidget {
  final String title;
  final String value;
  const _StatCard({required this.title, required this.value});

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            Text(value, style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Color(0xFF00E5A0))),
            const SizedBox(height: 8),
            Text(title, style: const TextStyle(fontSize: 12, color: Colors.white70)),
          ],
        ),
      ),
    );
  }
}

class _SkeletonBox extends StatelessWidget {
  final double height;
  final double? width;
  const _SkeletonBox({required this.height, this.width});
  
  @override
  Widget build(BuildContext context) {
    return Container(
      height: height,
      width: width,
      decoration: BoxDecoration(color: const Color(0xFF161B22), borderRadius: BorderRadius.circular(12)),
    );
  }
}
