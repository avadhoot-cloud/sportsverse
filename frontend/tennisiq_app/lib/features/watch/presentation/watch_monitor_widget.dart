import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:fl_chart/fl_chart.dart';
import '../providers/watch_connection_provider.dart';
import '../models/imu_sample.dart';

class WatchMonitorWidget extends ConsumerStatefulWidget {
  const WatchMonitorWidget({super.key});

  @override
  ConsumerState<WatchMonitorWidget> createState() => _WatchMonitorWidgetState();
}

class _WatchMonitorWidgetState extends ConsumerState<WatchMonitorWidget> {
  final List<FlSpot> _spots = [];
  double _xValue = 0;

  @override
  Widget build(BuildContext context) {
    final watchState = ref.watch(watchConnectionProvider);
    final imuAsync = ref.watch(imuStreamProvider);

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Icon(
                  Icons.bluetooth,
                  color: watchState.status == WatchConnectionState.connected ? const Color(0xFF00E5A0) : Colors.white54,
                ),
                const SizedBox(width: 8),
                Text(
                  watchState.status == WatchConnectionState.connected ? 'Watch Connected' : 'No Watch Paired',
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                ),
                const Spacer(),
                if (watchState.status == WatchConnectionState.connected)
                  imuAsync.when(
                    data: (sample) => Row(
                      children: [
                        const Icon(Icons.favorite, color: Colors.redAccent, size: 16),
                        const SizedBox(width: 4),
                        Text('${sample.hrBpm} BPM', style: const TextStyle(fontWeight: FontWeight.bold)),
                      ],
                    ),
                    loading: () => const Text('Reading...'),
                    error: (_, __) => const Text('Error'),
                  )
              ],
            ),
            const SizedBox(height: 24),
            
            // FLChart Live IMU Graph
            if (watchState.status == WatchConnectionState.connected)
              SizedBox(
                height: 150,
                child: imuAsync.when(
                  data: (sample) {
                    _xValue += 0.1; // Simulated delta interval for simplicity
                    _spots.add(FlSpot(_xValue, sample.accelerationMagnitude));
                    
                    // Keep last 50 spots for scrolling feel
                    if (_spots.length > 50) {
                      _spots.removeAt(0);
                    }

                    return LineChart(
                      LineChartData(
                        minY: 0,
                        titlesData: const FlTitlesData(show: false),
                        borderData: FlBorderData(show: false),
                        gridData: const FlGridData(show: false),
                        lineBarsData: [
                          LineChartBarData(
                            spots: _spots,
                            isCurved: true,
                            color: const Color(0xFF00E5A0),
                            barWidth: 2,
                            dotData: const FlDotData(show: false),
                            belowBarData: BarAreaData(
                              show: true,
                              color: const Color(0xFF00E5A0).withOpacity(0.1),
                            ),
                          ),
                        ],
                      ),
                    );
                  },
                  loading: () => const Center(child: CircularProgressIndicator()),
                  error: (e, __) => const Center(child: Text('Chart stream unavailable')),
                ),
              )
            else
              const SizedBox(
                height: 150,
                child: Center(
                  child: Text('Pair your watch in Settings to view live telemetry.', style: TextStyle(color: Colors.white54)),
                ),
              )
          ],
        ),
      ),
    );
  }
}
