//widgets/financial_chart.dart

import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';

class FinancialDashboardChart extends StatefulWidget {
  final Map<String, dynamic> analytics;

  const FinancialDashboardChart({
    super.key,
    required this.analytics,
  });

  @override
  State<FinancialDashboardChart> createState() =>
      _FinancialDashboardChartState();
}

class _FinancialDashboardChartState extends State<FinancialDashboardChart> {
  String? selectedBranch;

  List<dynamic> get data {
    final br = widget.analytics['branch_revenue'] 
        ?? widget.analytics['branchRevenue'] 
        ?? widget.analytics['branches'];
    if (br is List) return br;
    return [];
  }

  List<dynamic> get filteredData {
    if (selectedBranch == null) return data;
    return data.where((e) => e['branch'].toString() == selectedBranch).toList();
  }

  @override
  Widget build(BuildContext context) {
    final online =
        (widget.analytics['online_percentage'] as num?)?.toDouble() ?? 0.0;
    final cash =
        (widget.analytics['cash_percentage'] as num?)?.toDouble() ?? 0.0;
    final tokenAmount = widget.analytics['total_token_amount'] ?? 0;

    final branchTotal = selectedBranch == null
        ? (widget.analytics['total_amount'] ?? 0).toDouble()
        : filteredData.fold<double>(
            0.0,
            (sum, item) =>
                sum + ((item['total'] as num?)?.toDouble() ?? 0.0),
          );

    if (widget.analytics.isEmpty) {
      return const Center(child: Text("No Analytics Data"));
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        final isMobile = constraints.maxWidth < 600;
        return SingleChildScrollView(
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (isMobile) ...[
                  _infoCard(
                    "Payment Mode",
                    "Online: ${online.toInt()}% | Cash: ${cash.toInt()}%",
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Expanded(
                        child: _infoCard(
                          "Token Amt",
                          "₹ $tokenAmount",
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: _branchDropdown(),
                      ),
                    ],
                  ),
                ] else ...[
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: _infoCard(
                          "Payment Mode",
                          "Online: ${online.toInt()}% | Cash: ${cash.toInt()}%",
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: _infoCard(
                          "Token Amt",
                          "₹ $tokenAmount",
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: _branchDropdown(),
                      ),
                    ],
                  ),
                ],
                const SizedBox(height: 12),
                _infoCard(
                  "Branch Amount",
                  "₹ $branchTotal",
                ),
                const SizedBox(height: 20),
                if (isMobile) ...[
                  _buildPieChart(online, cash),
                  const SizedBox(height: 16),
                  _buildDonutChart(branchTotal),
                ] else ...[
                  Row(
                    children: [
                      Expanded(child: _buildPieChart(online, cash)),
                      const SizedBox(width: 12),
                      Expanded(child: _buildDonutChart(branchTotal)),
                    ],
                  ),
                ],
                const SizedBox(height: 20),
                SizedBox(
                  width: double.infinity,
                  child: _buildBarChart(),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _infoCard(String title, String value) {
    return Container(
      padding: const EdgeInsets.all(10),
      // Removed fixed height to prevent overflow
      constraints: const BoxConstraints(minHeight: 80), 
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border.all(color: Colors.grey.shade300),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            title, 
            style: const TextStyle(fontSize: 10, color: Colors.grey),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 6),
          Text(
            value,
            style: const TextStyle(
                fontSize: 13, fontWeight: FontWeight.bold),
          ),
        ],
      ),
    );
  }

  Widget _branchDropdown() {
    if (data.isEmpty) {
      return Container(
        height: 80,
        decoration: BoxDecoration(
          color: Colors.white,
          border: Border.all(color: Colors.grey.shade300),
          borderRadius: BorderRadius.circular(6),
        ),
        child: const Center(child: Text("No Data", style: TextStyle(fontSize: 10))),
      );
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8),
      height: 80, // Kept this for dropdown alignment, but made internal text smaller
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border.all(color: Colors.grey.shade300),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Center(
        child: DropdownButton<String>(
          isExpanded: true,
          underline: const SizedBox(),
          hint: const Text("Branch", style: TextStyle(fontSize: 11)),
          value: selectedBranch,
          style: const TextStyle(fontSize: 11, color: Colors.black),
          items: data.map<DropdownMenuItem<String>>((item) {
            return DropdownMenuItem<String>(
              value: item['branch'].toString(),
              child: Text(
                item['branch'].toString(),
                overflow: TextOverflow.ellipsis,
              ),
            );
          }).toList(),
          onChanged: (value) {
            setState(() {
              selectedBranch = value;
            });
          },
        ),
      ),
    );
  }

  Widget _buildPieChart(double online, double cash) {
    return _card(
      title: "Payment Method",
      child: SizedBox(
        height: 180, // Slightly reduced height for better fit
        child: PieChart(
          PieChartData(
            sectionsSpace: 2,
            centerSpaceRadius: 30,
            sections: [
              PieChartSectionData(
                value: online, 
                color: Colors.orange,
                title: "${online.toInt()}%",
                radius: 40,
                titleStyle: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.white),
              ),
              PieChartSectionData(
                value: cash, 
                color: Colors.amber,
                title: "${cash.toInt()}%",
                radius: 40,
                titleStyle: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.white),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDonutChart(num total) {
    return _card(
      title: "Selected Total",
      child: SizedBox(
        height: 180,
        child: PieChart(
          PieChartData(
            centerSpaceRadius: 35,
            sections: [
              PieChartSectionData(
                value: total.toDouble(),
                color: Colors.blueAccent,
                title: "₹${total.toInt()}",
                radius: 40,
                titleStyle: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.white),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildBarChart() {
    if (filteredData.isEmpty) {
      return const Center(child: Text("No Data Available"));
    }

    return _card(
      title: "Branch Revenue Comparison",
      child: SizedBox(
        height: 300,
        child: BarChart(
          BarChartData(
            maxY: _getMaxY(),
            gridData: const FlGridData(show: false),
            titlesData: FlTitlesData(
              bottomTitles: AxisTitles(
                sideTitles: SideTitles(
                  showTitles: true,
                  getTitlesWidget: (value, meta) {
                    int index = value.toInt();
                    if (index >= 0 && index < filteredData.length) {
                      return Padding(
                        padding: const EdgeInsets.only(top: 8.0),
                        child: Text(
                          filteredData[index]['branch'].toString().split('.').first,
                          style: const TextStyle(fontSize: 9),
                        ),
                      );
                    }
                    return const Text('');
                  },
                ),
              ),
            ),
            barGroups: List.generate(filteredData.length, (index) {
              final item = filteredData[index];
              return BarChartGroupData(
                x: index,
                barRods: [
                  BarChartRodData(
                    toY: (item['total'] as num?)?.toDouble() ?? 0.0,
                    color: Colors.blue,
                    width: 16,
                    borderRadius: BorderRadius.circular(4),
                  ),
                ],
              );
            }),
          ),
        ),
      ),
    );
  }

  Widget _card({required String title, required Widget child}) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border.all(color: Colors.grey.shade300),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title,
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
          const SizedBox(height: 10),
          child,
        ],
      ),
    );
  }

  double _getMaxY() {
    double maxVal = 0;
    for (var item in filteredData) {
      final value = (item['total'] as num?)?.toDouble() ?? 0.0;
      if (value > maxVal) maxVal = value;
    }
    return maxVal == 0 ? 100 : maxVal * 1.2;
  }
}