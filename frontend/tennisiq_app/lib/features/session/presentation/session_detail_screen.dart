import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:fl_chart/fl_chart.dart';

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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Session #${widget.sessionId}'),
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
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildOverviewTab(),
          _buildStrokesTab(),
          _buildMovementTab(),
          _buildInsightsTab(),
          _buildFusionTab(),
        ],
      ),
    );
  }

  Widget _buildOverviewTab() {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text('Match Data', style: TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.bold)),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
              decoration: BoxDecoration(color: const Color(0xFF00E5A0).withOpacity(0.2), borderRadius: BorderRadius.circular(16)),
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
          children: const [
            _StatCard(title: 'Total Strokes', value: '142'),
            _StatCard(title: 'Rallies', value: '28'),
            _StatCard(title: 'Distance', value: '1.2 km'),
            _StatCard(title: 'Fatigue', value: '--'), # Placeholder syncing watch metrics organically later
          ],
        )
      ],
    );
  }

  Widget _buildStrokesTab() {
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
                maxY: 80,
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
                  BarChartGroupData(x: 0, barRods: [BarChartRodData(toY: 65, color: Colors.green, width: 20, borderRadius: BorderRadius.circular(4))]),
                  BarChartGroupData(x: 1, barRods: [BarChartRodData(toY: 42, color: Colors.blue, width: 20, borderRadius: BorderRadius.circular(4))]),
                  BarChartGroupData(x: 2, barRods: [BarChartRodData(toY: 20, color: Colors.amber, width: 20, borderRadius: BorderRadius.circular(4))]),
                  BarChartGroupData(x: 3, barRods: [BarChartRodData(toY: 15, color: Colors.purple, width: 20, borderRadius: BorderRadius.circular(4))]),
                ],
              ),
            ),
          ),
          const SizedBox(height: 32),
          const Text('Recent Tracking Events', style: TextStyle(color: Colors.white, fontSize: 16)),
          const SizedBox(height: 16),
          Expanded(
            child: ListView(
              children: [
                _StrokeTile(type: 'Forehand', conf: 98, color: Colors.green, time: '12:04'),
                _StrokeTile(type: 'Backhand', conf: 85, color: Colors.blue, time: '12:08'),
                _StrokeTile(type: 'Serve', conf: 92, color: Colors.amber, time: '12:25'),
              ],
            ),
          )
        ],
      ),
    );
  }

  Widget _buildMovementTab() {
    return const Center(child: Text("Movement heatmaps bounding localized coordinates coming soon", style: TextStyle(color: Colors.white54)));
  }

  Widget _buildInsightsTab() {
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(color: const Color(0xFF161B22), borderRadius: BorderRadius.circular(16)),
            child: const Row(
              children: [
                Icon(Icons.smart_toy, size: 48, color: Color(0xFF00E5A0)),
                SizedBox(width: 16),
                Expanded(
                  child: Text(
                    "AI Coach: Your forehand consistency is dropping heavily late in the match. Try maintaining deeper knee bends.",
                    style: TextStyle(color: Colors.white, fontSize: 14, height: 1.5),
                  ),
                )
              ],
            ),
          )
        ],
      ),
    );
  }

  Widget _buildFusionTab() {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        const Text('Performance Matrix', style: TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.bold)),
        const SizedBox(height: 24),
        Row(
          children: [
            Expanded(child: _FusionArcGauge(title: 'Quality', val: 78, color: Colors.blueAccent)),
            const SizedBox(width: 16),
            Expanded(child: _FusionArcGauge(title: 'Timing', val: 92, color: const Color(0xFF00E5A0))),
          ],
        ),
        const SizedBox(height: 32),
        const Text('Match Intensity Sequence', style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
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
                  belowBarData: BarAreaData(show: true, color: Colors.redAccent.withOpacity(0.2)),
                  spots: const [
                    FlSpot(0, 40), FlSpot(1, 60), FlSpot(2, 75), FlSpot(3, 40), FlSpot(4, 95), FlSpot(5, 50)
                  ]
                )
              ]
            )
          ),
        ),
        const SizedBox(height: 24),
        _InsightCard(title: 'Footwork Efficiency', text: 'You scored 8.2m per rally, which is excellent structurally.', state: 'green'),
        _InsightCard(title: 'Reaction Variance', text: 'Your backend split step is tracking 0.5s delayed against average models.', state: 'amber'),
      ],
    );
  }
}

class _StatCard extends StatelessWidget {
  final String title;
  final String value;
  const _StatCard({required this.title, required this.value});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(color: const Color(0xFF161B22), borderRadius: BorderRadius.circular(16)),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(value, style: const TextStyle(fontSize: 28, fontWeight: FontWeight.bold, color: Color(0xFF00E5A0))),
          const SizedBox(height: 4),
          Text(title, style: const TextStyle(color: Colors.white54, fontSize: 12)),
        ],
      ),
    );
  }
}

class _StrokeTile extends StatelessWidget {
  final String type;
  final int conf;
  final Color color;
  final String time;

  const _StrokeTile({required this.type, required this.conf, required this.color, required this.time});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(color: const Color(0xFF161B22), borderRadius: BorderRadius.circular(8)),
      child: Row(
        children: [
          Icon(Icons.sports_tennis, color: color),
          const SizedBox(width: 16),
          Expanded(child: Text(type, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold))),
          Text('$conf% confidence', style: TextStyle(color: Colors.white.withOpacity(0.5), fontSize: 12)),
          const SizedBox(width: 16),
          Text(time, style: const TextStyle(color: Color(0xFF00E5A0))),
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
        color: c.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: c.withOpacity(0.3))
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
