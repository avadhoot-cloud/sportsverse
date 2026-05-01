import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';

class RatingForecastChart extends StatelessWidget {
  final List<FlSpot> historicalData;
  final List<FlSpot> forecastData;
  
  const RatingForecastChart({
    super.key,
    required this.historicalData,
    required this.forecastData,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 300,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 10)],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text("AI Rating Forecast", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
          const SizedBox(height: 4),
          const Text("Based on Prophet time-series prediction", style: TextStyle(color: Colors.grey, fontSize: 12)),
          const SizedBox(height: 24),
          Expanded(
            child: LineChart(
              LineChartData(
                gridData: FlGridData(show: false),
                titlesData: FlTitlesData(
                  topTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  rightTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  bottomTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      getTitlesWidget: (value, meta) => Text('T+${value.toInt()}d', style: const TextStyle(fontSize: 10, color: Colors.grey)),
                    ),
                  ),
                ),
                borderData: FlBorderData(show: false),
                minX: 0,
                maxX: forecastData.isNotEmpty ? forecastData.last.x : 30,
                minY: 2.0,
                maxY: 8.0,
                lineBarsData: [
                  LineChartBarData(
                    spots: historicalData,
                    isCurved: true,
                    color: const Color(0xFF1B3D2F), // Solid green for history
                    barWidth: 3,
                    isStrokeCapRound: true,
                    dotData: FlDotData(show: false),
                    belowBarData: BarAreaData(
                      show: true,
                      color: const Color(0xFF1B3D2F).withValues(alpha: 0.1),
                    ),
                  ),
                  LineChartBarData(
                    spots: forecastData,
                    isCurved: true,
                    color: const Color(0xFFE65100), // Orange for AI forecast
                    barWidth: 2,
                    isStrokeCapRound: true,
                    dashArray: [5, 5], // Dashed line for predictions
                    dotData: FlDotData(show: true),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
