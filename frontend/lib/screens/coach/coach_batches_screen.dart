// lib/screens/coach/coach_batches_screen.dart
//
// Detailed view of all batches assigned to this coach,
// showing schedule, sport, branch, and enrolled student count.

import 'package:flutter/material.dart';
import 'package:sportsverse_app/api/coach_api.dart';

import 'package:sportsverse_app/theme/elite_theme.dart';
import 'package:sportsverse_app/widgets/elite_card.dart';
import 'package:sportsverse_app/widgets/glass_header.dart';

class CoachBatchesScreen extends StatefulWidget {
  const CoachBatchesScreen({super.key});

  @override
  State<CoachBatchesScreen> createState() => _CoachBatchesScreenState();
}

class _CoachBatchesScreenState extends State<CoachBatchesScreen> {
  late Future<CoachDashboardData> _dashFuture;
  late Future<List<CoachStudent>> _studentFuture;

  @override
  void initState() {
    super.initState();
    _dashFuture = coachApi.getCoachDashboard();
    _studentFuture = coachApi.getCoachStudents();
  }

  String _formatSchedule(Map<String, dynamic>? schedule) {
    if (schedule == null || schedule.isEmpty) return 'Schedule not set';
    final days = (schedule['days'] as List?)?.join(', ') ?? '—';
    final start = schedule['start_time'] ?? '';
    final end = schedule['end_time'] ?? '';
    return '$days  $start–$end';
  }

  @override
  Widget build(BuildContext context) {
    final theme = EliteTheme.of(context);

    return Scaffold(
      backgroundColor: theme.surface,
      appBar: GlassHeader(
        title: 'My Batches',
        actions: [
          IconButton(
            tooltip: 'Refresh',
            onPressed: () => setState(() {
              _dashFuture = coachApi.getCoachDashboard();
              _studentFuture = coachApi.getCoachStudents();
            }),
            icon: Icon(Icons.refresh, color: theme.primary),
          ),
        ],
      ),
      body: FutureBuilder<List<dynamic>>(
        future: Future.wait([_dashFuture, _studentFuture]),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return Center(child: CircularProgressIndicator(color: theme.primary));
          }
          if (snapshot.hasError) {
            return Center(
              child: Text('Error: ${snapshot.error}',
                  style: theme.body.copyWith(color: theme.error)),
            );
          }

          final data = snapshot.data![0] as CoachDashboardData;
          final students = snapshot.data![1] as List<CoachStudent>;

          // Count students per batch
          final countByBatch = <int, int>{};
          for (final s in students) {
            countByBatch[s.batchId] = (countByBatch[s.batchId] ?? 0) + 1;
          }

          if (data.assignments.isEmpty) {
            return Center(
              child: Text('No batches assigned yet.',
                  style: theme.body.copyWith(color: theme.secondaryText)),
            );
          }

          return ListView.builder(
            padding: const EdgeInsets.all(24),
            itemCount: data.assignments.length,
            itemBuilder: (context, index) {
              final a = data.assignments[index];
              final studentCount = countByBatch[a.batchId] ?? 0;
              final scheduleStr = _formatSchedule(a.schedule);

              return Padding(
                padding: const EdgeInsets.only(bottom: 24),
                child: EliteCard(
                  padding: EdgeInsets.zero,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Header gradient bar
                      Container(
                        padding: const EdgeInsets.fromLTRB(20, 20, 20, 20),
                        decoration: BoxDecoration(
                          color: theme.primary, // Navy header
                          borderRadius: const BorderRadius.only(
                            topLeft: Radius.circular(32),
                            topRight: Radius.circular(32),
                          ),
                        ),
                        child: Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(10),
                              decoration: BoxDecoration(
                                color: theme.surfaceContainerLowest.withOpacity(0.1),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Icon(Icons.sports_tennis, color: theme.surfaceContainerLowest, size: 24)
                            ),
                            const SizedBox(width: 16),
                            Expanded(
                              child: Text(a.batchName,
                                  style: theme.display2.copyWith(color: theme.surfaceContainerLowest)),
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                              decoration: BoxDecoration(
                                color: theme.accent.withOpacity(0.9), // Lime accent
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Text(a.sport,
                                  style: theme.caption.copyWith(
                                      color: theme.primary,
                                      fontWeight: FontWeight.bold)),
                            ),
                          ],
                        ),
                      ),
                      // Body
                      Padding(
                        padding: const EdgeInsets.all(24),
                        child: Column(
                          children: [
                            _infoRow(theme, Icons.location_on_outlined, 'Branch', a.branch),
                            const SizedBox(height: 16),
                            _infoRow(theme, Icons.schedule_outlined, 'Schedule', scheduleStr),
                            const SizedBox(height: 16),
                            _infoRow(
                                theme,
                                Icons.group_outlined,
                                'Students',
                                '$studentCount enrolled'),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }

  Widget _infoRow(EliteTheme theme, IconData icon, String label, String value) {
    return Row(
      children: [
        Icon(icon, size: 20, color: theme.secondaryText),
        const SizedBox(width: 12),
        Text('$label: ', style: theme.body.copyWith(color: theme.secondaryText)),
        Expanded(
          child: Text(value,
              style: theme.body.copyWith(fontWeight: FontWeight.bold),
              overflow: TextOverflow.ellipsis),
        ),
      ],
    );
  }
}
