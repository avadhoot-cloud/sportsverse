import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../providers/history_provider.dart';

class SessionHistoryScreen extends ConsumerStatefulWidget {
  const SessionHistoryScreen({super.key});

  @override
  ConsumerState<SessionHistoryScreen> createState() => _SessionHistoryScreenState();
}

class _SessionHistoryScreenState extends ConsumerState<SessionHistoryScreen> {
  String _selectedFilter = 'All';

  final List<String> _filters = ['All', 'Video Only', 'Watch Only', 'Fusion'];

  @override
  Widget build(BuildContext context) {
    final historyAsync = ref.watch(historyProvider);

    return Scaffold(
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Padding(
              padding: EdgeInsets.fromLTRB(16, 24, 16, 8),
              child: Text('Session History', style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold, color: Colors.white)),
            ),
            
            // Filter Chips
            SizedBox(
              height: 50,
              child: ListView.builder(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 16),
                itemCount: _filters.length,
                itemBuilder: (context, index) {
                  final filter = _filters[index];
                  final isSelected = _selectedFilter == filter;
                  return Padding(
                    padding: const EdgeInsets.only(right: 8.0),
                    child: FilterChip(
                      label: Text(filter),
                      selected: isSelected,
                      onSelected: (selected) {
                        setState(() => _selectedFilter = filter);
                      },
                      selectedColor: const Color(0xFF00E5A0).withValues(alpha: 0.2),
                      checkmarkColor: const Color(0xFF00E5A0),
                      labelStyle: TextStyle(
                        color: isSelected ? const Color(0xFF00E5A0) : Colors.white70,
                        fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                      ),
                      backgroundColor: const Color(0xFF161B22),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                    ),
                  );
                },
              ),
            ),
            
            Expanded(
              child: RefreshIndicator(
                onRefresh: () async => ref.invalidate(historyProvider),
                child: historyAsync.when(
                  data: (sessions) {
                    // Apply filtering logic locally
                    List<dynamic> filtered = sessions;
                    if (_selectedFilter == 'Video Only') {
                      filtered = sessions.where((s) => s['mode'] == 'video_only').toList();
                    } else if (_selectedFilter == 'Watch Only') {
                      filtered = sessions.where((s) => s['mode'] == 'watch_only').toList();
                    } else if (_selectedFilter == 'Fusion') {
                      filtered = sessions.where((s) => s['mode'] == 'fusion').toList();
                    }

                    if (filtered.isEmpty) {
                      return ListView(
                        children: const [
                          SizedBox(height: 100),
                          Center(child: Text('No sessions match this filter.', style: TextStyle(color: Colors.white54))),
                        ],
                      );
                    }

                    return ListView.builder(
                      padding: const EdgeInsets.all(16),
                      itemCount: filtered.length,
                      itemBuilder: (context, index) {
                        final s = filtered[index];
                        final dateStr = s['date'].toString().split('T')[0];
                        
                        return Card(
                          margin: const EdgeInsets.only(bottom: 12),
                          child: InkWell(
                            onTap: () {
                              context.push('/session-detail/${s['id']}');
                            },
                            child: Padding(
                              padding: const EdgeInsets.all(16.0),
                              child: Row(
                                children: [
                                  CircleAvatar(
                                    backgroundColor: const Color(0xFF00E5A0).withValues(alpha: 0.1),
                                    child: Icon(
                                      s['mode'] == 'video_only' ? Icons.videocam : (s['mode'] == 'watch_only' ? Icons.watch : Icons.merge_type),
                                      color: const Color(0xFF00E5A0),
                                    ),
                                  ),
                                  const SizedBox(width: 16),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text('Date: $dateStr', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Colors.white)),
                                        const SizedBox(height: 4),
                                        Text('${s['duration_seconds']} sec • Strokes: ${s['stroke_events']?.length ?? 0}', style: const TextStyle(color: Colors.white70)),
                                      ],
                                    ),
                                  ),
                                  const Icon(Icons.arrow_forward_ios, size: 16, color: Colors.white54),
                                ],
                              ),
                            ),
                          ),
                        );
                      },
                    );
                  },
                  loading: () => ListView.builder(
                    padding: const EdgeInsets.all(16),
                    itemCount: 5,
                    itemBuilder: (context, _) => Padding(
                      padding: const EdgeInsets.only(bottom: 12.0),
                      child: Container(
                        height: 80,
                        decoration: BoxDecoration(color: const Color(0xFF161B22), borderRadius: BorderRadius.circular(16)),
                      ),
                    ),
                  ),
                  error: (e, __) => Center(child: Text('Failed to load history: $e', style: const TextStyle(color: Colors.white54))),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
