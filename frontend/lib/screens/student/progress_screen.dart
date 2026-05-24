import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:sportsverse_app/providers/student_provider.dart';

class ProgressScreen extends StatefulWidget {
  const ProgressScreen({super.key});

  @override
  State<ProgressScreen> createState() => _ProgressScreenState();
}

class _ProgressScreenState extends State<ProgressScreen> {
  @override
  void initState() {
    super.initState();
    Future.microtask(() {
      Provider.of<StudentProvider>(context, listen: false).loadDashboardData();
    });
  }

  List<Map<String, dynamic>> _skillsFromData(StudentProvider provider) {
    final data = provider.dashboardData;
    if (data == null) return [];
    final singles = data.duprSinglesRating / 8.0;
    final doubles = data.duprDoublesRating / 8.0;
    final reliability = data.duprReliability / 100.0;
    int total = 0;
    int attended = 0;
    for (final e in data.currentEnrollments) {
      total += e.totalSessions ?? 0;
      attended += e.sessionsAttended;
    }
    final attendance = total > 0 ? attended / total : 0.0;
    return [
      {'label': 'Singles Rating', 'level': singles.clamp(0.0, 1.0), 'color': const Color(0xFF1B3D2F)},
      {'label': 'Doubles Rating', 'level': doubles.clamp(0.0, 1.0), 'color': const Color(0xFF1565C0)},
      {'label': 'Reliability', 'level': reliability.clamp(0.0, 1.0), 'color': const Color(0xFF2E7D32)},
      {'label': 'Attendance', 'level': attendance.clamp(0.0, 1.0), 'color': const Color(0xFF7B1FA2)},
      {'label': 'Match Play', 'level': (data.duprMatchesSingles / 20).clamp(0.0, 1.0), 'color': const Color(0xFFE65100)},
    ];
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<StudentProvider>();
    final data = provider.dashboardData;
    final skills = _skillsFromData(provider);

    // Aggregate session data from enrollments
    int totalSessions = 0;
    int attendedSessions = 0;
    if (data != null) {
      for (final e in data.currentEnrollments) {
        totalSessions += (e.totalSessions ?? 0);
        attendedSessions += e.sessionsAttended;
      }
    }
    final attendanceRate = totalSessions > 0 ? attendedSessions / totalSessions : 0.0;

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFB),
      appBar: AppBar(
        title: const Text("My Progress",
            style: TextStyle(fontWeight: FontWeight.bold, color: Colors.black)),
        backgroundColor: Colors.white,
        elevation: 0,
        centerTitle: true,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new, color: Colors.black, size: 20),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: provider.isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Summary Cards Row
                  Row(
                    children: [
                      Expanded(child: _statCard("Sessions Done", "$attendedSessions", Icons.check_circle, const Color(0xFF1B3D2F))),
                      const SizedBox(width: 12),
                      Expanded(child: _statCard("Total Sessions", "$totalSessions", Icons.calendar_today, const Color(0xFF1565C0))),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: _statCard(
                          "Attendance Rate",
                          "${(attendanceRate * 100).toStringAsFixed(0)}%",
                          Icons.bar_chart,
                          attendanceRate >= 0.75 ? const Color(0xFF2E7D32) : const Color(0xFFE65100),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _statCard(
                          "Batches Enrolled",
                        "${data?.currentEnrollments.length ?? 0}",
                          Icons.group,
                          const Color(0xFF7B1FA2),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),

                  const Text('Performance Metrics', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                  const SizedBox(height: 4),
                  const Text("Based on coach evaluations",
                      style: TextStyle(color: Colors.grey, fontSize: 12)),
                  const SizedBox(height: 14),
                  Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(18),
                      boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10)],
                    ),
                    child: Column(
                      children: skills.map((s) => _buildSkillBar(s)).toList(),
                    ),
                  ),
                  const SizedBox(height: 24),

                  // Overall performance
                  const Text("Overall Performance",
                      style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                  const SizedBox(height: 14),
                  _buildPerformanceBanner(attendanceRate),
                ],
              ),
            ),
    );
  }

  Widget _statCard(String label, String value, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 8)],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: color, size: 22),
          const SizedBox(height: 8),
          Text(value, style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: color)),
          const SizedBox(height: 4),
          Text(label, style: TextStyle(fontSize: 11, color: Colors.grey[600])),
        ],
      ),
    );
  }

  Widget _buildSkillBar(Map<String, dynamic> s) {
    final color = s['color'] as Color;
    final level = s['level'] as double;
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(s['label'] as String, style: const TextStyle(fontWeight: FontWeight.w500, fontSize: 13)),
              Text("${(level * 100).toInt()}%",
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: color)),
            ],
          ),
          const SizedBox(height: 6),
          ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: LinearProgressIndicator(
              value: level,
              backgroundColor: color.withOpacity(0.1),
              color: color,
              minHeight: 8,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPerformanceBanner(double attendanceRate) {
    final isGood = attendanceRate >= 0.75;
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: isGood
              ? [const Color(0xFF1B3D2F), const Color(0xFF2D6A4F)]
              : [const Color(0xFFE65100), const Color(0xFFFF8F00)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        children: [
          Icon(
            isGood ? Icons.thumb_up : Icons.trending_up,
            color: Colors.white,
            size: 40,
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  isGood ? "Great work! Keep it up 💪" : "More sessions needed",
                  style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16),
                ),
                const SizedBox(height: 4),
                Text(
                  isGood
                      ? "Your attendance is above 75%. You're on track!"
                      : "Try to attend more sessions to improve your skills.",
                  style: const TextStyle(color: Colors.white70, fontSize: 12),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
