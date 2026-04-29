import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:go_router/go_router.dart';
import '../../auth/providers/auth_provider.dart';
import '../providers/history_provider.dart';
import '../providers/session_detail_provider.dart';

class SessionDetailScreen extends ConsumerStatefulWidget {
  final String sessionId;
  
  const SessionDetailScreen({super.key, required this.sessionId});

  @override
  ConsumerState<SessionDetailScreen> createState() => _SessionDetailScreenState();
}

class _SessionDetailScreenState extends ConsumerState<SessionDetailScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 5, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _deleteSession() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF161B22),
        title: const Text('Delete Session', style: TextStyle(color: Colors.white)),
        content: const Text('Are you sure you want to delete this session? This action cannot be undone.', style: TextStyle(color: Colors.white70)),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('CANCEL', style: TextStyle(color: Colors.white54)),
          ),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('DELETE', style: TextStyle(color: Colors.redAccent)),
          ),
        ],
      ),
    );

    if (confirm == true) {
      try {
        final api = ref.read(apiServiceProvider);
        await api.client.delete('/sessions/sessions/${widget.sessionId}/');
        if (mounted) {
          ref.invalidate(historyProvider);
          context.pop();
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Failed to delete session: $e')));
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final sessionAsync = ref.watch(sessionDetailProvider(widget.sessionId));

    return Scaffold(
      appBar: AppBar(
        title: Text('Session #${widget.sessionId}'),
        actions: [
          IconButton(
            icon: const Icon(Icons.delete, color: Colors.white54),
            onPressed: _deleteSession,
          ),
        ],
        bottom: TabBar(
          controller: _tabController,
          isScrollable: true,
          indicatorColor: const Color(0xFF00E5A0),
          tabs: const [
            Tab(text: "Overview"),
            Tab(text: "Strokes"),
            Tab(text: "Movement"),
            Tab(text: "Insights"),
            Tab(text: "FUSION INTELLIGENCE"),
          ],
        ),
      ),
      body: sessionAsync.when(
        data: (data) => TabBarView(
          controller: _tabController,
          children: [
            _buildOverviewTab(data),
            _buildStrokesTab(data),
            _buildMovementTab(data),
            _buildInsightsTab(data),
            _buildFusionTab(data),
          ],
        ),
        loading: () => const Center(child: CircularProgressIndicator(color: Color(0xFF00E5A0))),
        error: (e, __) => Center(child: Text('Error loading session: $e', style: const TextStyle(color: Colors.red))),
      ),
    );
  }

  Widget _buildOverviewTab(Map<String, dynamic> data) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text('Match Data', style: TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.bold)),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
              decoration: BoxDecoration(color: const Color(0xFF00E5A0).withValues(alpha: 0.2), borderRadius: BorderRadius.circular(16)),
              child: const Text('VIDEO ONLY', style: TextStyle(color: Color(0xFF00E5A0), fontWeight: FontWeight.bold, fontSize: 10)),
            )
          ],
        ),
        const SizedBox(height: 24),
        GridView.count(
          crossAxisCount: 2,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          mainAxisSpacing: 16,
          crossAxisSpacing: 16,
          childAspectRatio: 1.5,
          children: [
            _StatCard(title: 'Total Strokes', value: data['stroke_count'].toString()),
            _StatCard(title: 'Accuracy', value: data['shot_accuracy_pct'] == 'NA' ? 'NA' : '${data['shot_accuracy_pct']}%'),
            _StatCard(title: 'Distance (m)', value: data['distance_m'].toString()),
            _StatCard(title: 'Unforced Errs', value: data['unforced_errors'].toString()),
            _StatCard(title: 'Max Rally Length', value: data['max_rally_length'].toString()),
            _StatCard(title: 'Fatigue Score', value: data['fatigue_score'] == 'NA' ? 'NA' : data['fatigue_score'].toString()),
            _StatCard(
              title: 'Max Ball Speed',
              value: data['max_ball_speed_kmh'] == 'NA'
                  ? 'NA'
                  : '${data['max_ball_speed_kmh']} km/h',
              subtitle: 'Server-computed',
            ),
            _StatCard(
              title: 'Dominant Zone',
              value: (data['dominant_court_zone'] ?? 'NA').toString().replaceAll('_', ' ').toUpperCase(),
            ),
          ],
        )
      ],
    );
  }

  Widget _buildStrokesTab(Map<String, dynamic> data) {
    final dist = data['stroke_distribution'] as Map<String, dynamic>? ?? {};
    final fh = dist['forehand'] == 'NA' ? 0.0 : (dist['forehand'] ?? 0).toDouble();
    final bh = dist['backhand'] == 'NA' ? 0.0 : (dist['backhand'] ?? 0).toDouble();
    final srv = dist['serve'] == 'NA' ? 0.0 : (dist['serve'] ?? 0).toDouble();
    final vol = dist['volley'] == 'NA' ? 0.0 : (dist['volley'] ?? 0).toDouble();
    final unk = dist['unknown'] == 'NA' ? 0.0 : (dist['unknown'] ?? 0).toDouble();

    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text('Stroke Distribution', style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
          const SizedBox(height: 24),
          SizedBox(
            height: 200,
            child: BarChart(
              BarChartData(
                alignment: BarChartAlignment.spaceAround,
                maxY: [fh, bh, srv, vol, unk].fold(0.0, (a, b) => a > b ? a : b).clamp(1.0, double.infinity),
                barTouchData: BarTouchData(enabled: false),
                titlesData: FlTitlesData(
                  show: true,
                  bottomTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      getTitlesWidget: (val, meta) {
                        const style = TextStyle(color: Colors.white70, fontSize: 10, fontWeight: FontWeight.bold);
                        switch (val.toInt()) {
                          case 0: return const Text('Fh', style: style);
                          case 1: return const Text('Bh', style: style);
                          case 2: return const Text('Srv', style: style);
                          case 3: return const Text('Vol', style: style);
                          case 4: return const Text('Unk', style: style);
                          default: return const Text('');
                        }
                      },
                    ),
                  ),
                  leftTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                ),
                gridData: const FlGridData(show: false),
                borderData: FlBorderData(show: false),
                barGroups: [
                  BarChartGroupData(x: 0, barRods: [BarChartRodData(toY: fh, color: Colors.green, width: 20, borderRadius: BorderRadius.circular(4))]),
                  BarChartGroupData(x: 1, barRods: [BarChartRodData(toY: bh, color: Colors.blue, width: 20, borderRadius: BorderRadius.circular(4))]),
                  BarChartGroupData(x: 2, barRods: [BarChartRodData(toY: srv, color: Colors.amber, width: 20, borderRadius: BorderRadius.circular(4))]),
                  BarChartGroupData(x: 3, barRods: [BarChartRodData(toY: vol, color: Colors.purple, width: 20, borderRadius: BorderRadius.circular(4))]),
                  BarChartGroupData(x: 4, barRods: [BarChartRodData(toY: unk, color: Colors.grey, width: 20, borderRadius: BorderRadius.circular(4))]),
                ],
              ),
            ),
          ),
          const SizedBox(height: 32),
          const Text('Recent Tracking Events', style: TextStyle(color: Colors.white, fontSize: 16)),
          const SizedBox(height: 16),
          const Expanded(
            child: Center(child: Text("Detailed array logs suppressed. Waiting on Stage 6.", style: TextStyle(color: Colors.white54))),
          )
        ],
      ),
    );
  }

  Widget _buildMovementTab(Map<String, dynamic> data) {
    final zone = (data['dominant_court_zone'] ?? 'NA').toString();
    final distM = data['distance_m'];
    final ballSpeed = data['max_ball_speed_kmh'];

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        const Text('Court Positioning', style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
        const SizedBox(height: 20),
        _CourtPositionWidget(dominantZone: zone),
        const SizedBox(height: 28),
        const Text('Movement Metrics', style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
        const SizedBox(height: 16),
        Row(
          children: [
            Expanded(child: _StatCard(title: 'Total Distance', value: distM == 'NA' ? 'NA' : '${distM}m')),
            const SizedBox(width: 16),
            Expanded(child: _StatCard(
              title: 'Max Ball Speed',
              value: ballSpeed == 'NA' ? 'NA' : '${ballSpeed} km/h',
            )),
          ],
        ),
        const SizedBox(height: 16),
        Row(
          children: [
            Expanded(child: _StatCard(title: 'Max Serve Speed', value: data['max_serve_speed_kmh'] == 'NA' ? 'NA' : '${data['max_serve_speed_kmh']} km/h')),
            const SizedBox(width: 16),
            Expanded(child: _StatCard(title: 'Avg Rally Length', value: data['avg_rally_length'].toString())),
          ],
        ),
      ],
    );
  }

  Widget _buildInsightsTab(Map<String, dynamic> data) {
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(color: const Color(0xFF161B22), borderRadius: BorderRadius.circular(16)),
            child: Row(
              children: [
                const Icon(Icons.smart_toy, size: 48, color: Color(0xFF00E5A0)),
                const SizedBox(width: 16),
                Expanded(
                  child: Text(
                    (data['coaching_insights'] as List).isNotEmpty ? data['coaching_insights'].first.toString() : "No insights available currently. Gathering more data.",
                    style: const TextStyle(color: Colors.white, fontSize: 14, height: 1.5),
                  ),
                )
              ],
            ),
          )
        ],
      ),
    );
  }

  Widget _buildFusionTab(Map<String, dynamic> data) {
    final quality = data['stroke_quality_score'] == 'NA' ? 0.0 : (data['stroke_quality_score'] as num).toDouble();
    final timing = data['timing_score'] == 'NA' ? 0.0 : (data['timing_score'] as num).toDouble();
    final tempoSeries = (data['stroke_tempo_series'] as List<dynamic>?) ?? [];
    
    final spots = <FlSpot>[];
    for (int i = 0; i < tempoSeries.length; i++) {
      spots.add(FlSpot(i.toDouble(), (tempoSeries[i] as num).toDouble()));
    }
    if (spots.isEmpty) {
      spots.add(const FlSpot(0, 0));
    }

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        const Text('Performance Matrix', style: TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.bold)),
        const SizedBox(height: 24),
        Row(
          children: [
            Expanded(child: _FusionArcGauge(title: 'Quality', val: quality, color: Colors.blueAccent)),
            const SizedBox(width: 16),
            Expanded(child: _FusionArcGauge(title: 'Timing', val: timing, color: const Color(0xFF00E5A0))),
          ],
        ),
        const SizedBox(height: 32),
        const Text('Stroke Tempo (Strokes/Min)', style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
        const SizedBox(height: 24),
        Container(
          height: 200,
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(color: const Color(0xFF161B22), borderRadius: BorderRadius.circular(16)),
          child: LineChart(
            LineChartData(
              gridData: const FlGridData(show: false),
              titlesData: const FlTitlesData(show: false),
              borderData: FlBorderData(show: false),
              lineBarsData: [
                LineChartBarData(
                  isCurved: true,
                  color: Colors.redAccent,
                  barWidth: 4,
                  dotData: const FlDotData(show: false),
                  belowBarData: BarAreaData(show: true, color: Colors.redAccent.withValues(alpha: 0.2)),
                  spots: spots
                )
              ]
            )
          ),
        ),
        const SizedBox(height: 24),
        if (data['match_intensity_score'] != 'NA')
          _InsightCard(title: 'Match Intensity', text: 'Score: ${data['match_intensity_score']}', state: 'green'),
        if (data['fatigue_score'] != 'NA')
          _InsightCard(title: 'Fatigue Model', text: 'Score: ${data['fatigue_score']} (0.0=Fresh, 1.0=Exhausted)', state: 'amber'),
      ],
    );
  }
}

class _StatCard extends StatelessWidget {
  final String title;
  final String value;
  final String? subtitle;
  const _StatCard({required this.title, required this.value, this.subtitle});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(color: const Color(0xFF161B22), borderRadius: BorderRadius.circular(16)),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(value, style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Color(0xFF00E5A0))),
          const SizedBox(height: 4),
          Text(title, style: const TextStyle(color: Colors.white54, fontSize: 12)),
          if (subtitle != null) ...
            [const SizedBox(height: 2), Text(subtitle!, style: const TextStyle(color: Colors.white24, fontSize: 10))]
        ],
      ),
    );
  }
}

class _FusionArcGauge extends StatelessWidget {
  final String title;
  final double val;
  final Color color;
  
  const _FusionArcGauge({required this.title, required this.val, required this.color});
  
  @override
  Widget build(BuildContext context) {
    return Container(
      height: 120,
      decoration: BoxDecoration(color: const Color(0xFF161B22), borderRadius: BorderRadius.circular(16)),
      child: Stack(
         alignment: Alignment.center,
         children: [
            SizedBox(
              height: 70, width: 70,
              child: CircularProgressIndicator(
                value: val / 100.0,
                strokeWidth: 8,
                backgroundColor: Colors.white12,
                color: color,
              )
            ),
            Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text('${val.toInt()}', style: TextStyle(color: color, fontSize: 18, fontWeight: FontWeight.bold)),
                Text(title, style: const TextStyle(color: Colors.white54, fontSize: 10)),
              ]
            )
         ],
      )
    );
  }
}

class _InsightCard extends StatelessWidget {
  final String title, text, state;
  const _InsightCard({required this.title, required this.text, required this.state});
  
  @override
  Widget build(BuildContext context) {
    Color c = state == 'green' ? const Color(0xFF00E5A0) : (state == 'amber' ? Colors.amber : Colors.redAccent);
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: c.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: c.withValues(alpha: 0.3))
      ),
      child: Row(
        children: [
           Icon(state == 'green' ? Icons.check_circle : Icons.warning, color: c),
           const SizedBox(width: 16),
           Expanded(
             child: Column(
               crossAxisAlignment: CrossAxisAlignment.start,
               children: [
                 Text(title, style: TextStyle(color: c, fontWeight: FontWeight.bold)),
                 const SizedBox(height: 4),
                 Text(text, style: const TextStyle(color: Colors.white, fontSize: 12)),
               ]
             )
           )
        ]
      )
    );
  }
}

/// Schematic top-down court view highlighting the player's dominant zone.
class _CourtPositionWidget extends StatelessWidget {
  final String dominantZone;
  const _CourtPositionWidget({required this.dominantZone});

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 220,
      decoration: BoxDecoration(
        color: const Color(0xFF161B22),
        borderRadius: BorderRadius.circular(16),
      ),
      padding: const EdgeInsets.all(12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Dominant zone: ${dominantZone.replaceAll('_', ' ').toUpperCase()}',
            style: const TextStyle(color: Color(0xFF00E5A0), fontSize: 12, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          Expanded(
            child: CustomPaint(
              painter: _CourtSchemaPainter(dominantZone: dominantZone),
              child: const SizedBox.expand(),
            ),
          ),
        ],
      ),
    );
  }
}

class _CourtSchemaPainter extends CustomPainter {
  final String dominantZone;
  const _CourtSchemaPainter({required this.dominantZone});

  @override
  void paint(Canvas canvas, Size size) {
    final linePaint = Paint()
      ..color = Colors.white24
      ..strokeWidth = 1.5
      ..style = PaintingStyle.stroke;

    final highlightPaint = Paint()
      ..color = const Color(0xFF00E5A0).withValues(alpha: 0.35)
      ..style = PaintingStyle.fill;

    final w = size.width;
    final h = size.height;

    // Court outline
    canvas.drawRect(Rect.fromLTWH(0, 0, w, h), linePaint);
    // Net
    canvas.drawLine(Offset(0, h / 2), Offset(w, h / 2), linePaint);
    // Service boxes
    canvas.drawLine(Offset(0, h * 0.25), Offset(w, h * 0.25), linePaint);
    canvas.drawLine(Offset(0, h * 0.75), Offset(w, h * 0.75), linePaint);
    canvas.drawLine(Offset(w / 2, h * 0.25), Offset(w / 2, h * 0.75), linePaint);

    // Highlight dominant zone
    Rect? highlightRect;
    switch (dominantZone) {
      case 'near_baseline':
        highlightRect = Rect.fromLTWH(0, h * 0.75, w, h * 0.25);
        break;
      case 'near_service':
        highlightRect = Rect.fromLTWH(0, h * 0.5, w, h * 0.25);
        break;
      case 'net_zone':
        highlightRect = Rect.fromLTWH(0, h * 0.25, w, h * 0.25);
        break;
      default:
        break;
    }

    if (highlightRect != null) {
      canvas.drawRect(highlightRect, highlightPaint);
    }

    // Zone labels
    const style = TextStyle(color: Colors.white54, fontSize: 9);
    void drawLabel(String text, Offset position) {
      final tp = TextPainter(
        text: TextSpan(text: text, style: style),
        textDirection: ui.TextDirection.ltr,
      )..layout();
      tp.paint(canvas, position);
    }

    drawLabel('NET ZONE', Offset(4, h * 0.28));
    drawLabel('SERVICE', Offset(4, h * 0.53));
    drawLabel('BASELINE', Offset(4, h * 0.78));
  }

  @override
  bool shouldRepaint(covariant _CourtSchemaPainter old) => old.dominantZone != dominantZone;
}
