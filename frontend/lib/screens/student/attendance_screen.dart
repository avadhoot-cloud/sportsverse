import 'dart:convert';
import 'package:flutter/material.dart';
import '../../api/api_client.dart';
import 'package:sportsverse_app/theme/elite_theme.dart';
import 'package:sportsverse_app/widgets/elite_card.dart';
import 'package:sportsverse_app/widgets/glass_header.dart';
import 'package:sportsverse_app/widgets/performance_badge.dart';

class AttendanceScreen extends StatefulWidget {
  const AttendanceScreen({super.key});

  @override
  State<AttendanceScreen> createState() => _AttendanceScreenState();
}

class _AttendanceScreenState extends State<AttendanceScreen> {
  List<dynamic> attendanceData = [];
  List<dynamic> filteredList = [];

  bool isLoading = true;
  String selectedMonth = "All";
  String searchDate = "";

  @override
  void initState() {
    super.initState();
    fetchAttendance();
  }

  Future<void> fetchAttendance() async {
    try {
      final api = ApiClient();
      final response =
          await api.get("api/organizations/student/attendance/");

      final decoded = jsonDecode(response.body);

      setState(() {
        attendanceData = decoded is List ? decoded : [];

        filteredList = (attendanceData.isNotEmpty &&
                attendanceData[0]['attendance_details'] != null)
            ? attendanceData[0]['attendance_details']
            : [];

        isLoading = false;
      });

      checkAbsentReminder();
    } catch (e) {
      print("❌ FETCH ERROR: $e");
      if (mounted) {
        setState(() => isLoading = false);
      }
    }
  }

  // 🔍 FILTER LOGIC (SAFE)
  void applyFilters() {
    if (attendanceData.isEmpty) return;

    final data = attendanceData[0];
    List list = data['attendance_details'] ?? [];

    if (selectedMonth != "All") {
      list = list.where((item) {
        try {
          final date = DateTime.parse(item['date']);
          return date.month == int.parse(selectedMonth);
        } catch (_) {
          return false;
        }
      }).toList();
    }

    if (searchDate.isNotEmpty) {
      list = list.where((item) {
        return item['date']?.toString().contains(searchDate) ?? false;
      }).toList();
    }

    setState(() {
      filteredList = list;
    });
  }

  // 🔔 ABSENT REMINDER (SAFE)
  void checkAbsentReminder() {
    if (attendanceData.isEmpty) return;

    final list = attendanceData[0]['attendance_details'] ?? [];

    int absentStreak = 0;

    for (var item in list) {
      if (item['status'] == "Absent") {
        absentStreak++;
      } else {
        break;
      }
    }

    if (absentStreak >= 2) {
      Future.delayed(Duration.zero, () {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: const Text("⚠️ You were absent for 2+ days!"),
              backgroundColor: EliteTheme.of(context).error,
            ),
          );
        }
      });
    }
  }

  // 📊 SMART PREDICTION
  String getPrediction(double percentage) {
    if (percentage < 75) {
      return "⚠️ You are below 75%. Risk!";
    } else if (percentage < 80) {
      return "⚠️ You may fall below 75% soon";
    } else {
      return "✅ You are safe";
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = EliteTheme.of(context);

    if (isLoading) {
      return Scaffold(
        backgroundColor: theme.surface,
        appBar: const GlassHeader(title: "My Attendance"),
        body: Center(child: CircularProgressIndicator(color: theme.primary)),
      );
    }

    if (attendanceData.isEmpty) {
      return Scaffold(
        backgroundColor: theme.surface,
        appBar: const GlassHeader(title: "My Attendance"),
        body: Center(child: Text("No Data", style: theme.body)),
      );
    }

    final data = attendanceData[0];
    final percentage = (data['attendance_percentage'] ?? 0).toDouble();

    return Scaffold(
      backgroundColor: theme.surface,
      appBar: const GlassHeader(title: "My Attendance"),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 🚨 ALERT
            if (percentage < 75)
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16),
                margin: const EdgeInsets.only(bottom: 16),
                decoration: BoxDecoration(
                  color: theme.errorBackground,
                  borderRadius: BorderRadius.circular(theme.cardRadius),
                  border: Border.all(color: theme.error.withOpacity(0.3)),
                ),
                child: Row(
                  children: [
                    Icon(Icons.warning_amber_rounded, color: theme.error),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        "⚠️ Low Attendance Warning!",
                        style: theme.subtitle.copyWith(color: theme.error),
                      ),
                    ),
                  ],
                ),
              ),

            // 📊 SUMMARY
            EliteCard(
              padding: const EdgeInsets.all(24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text("Attendance Score", style: theme.heading),
                      Text("$percentage%", style: theme.display2.copyWith(color: percentage < 75 ? theme.error : theme.primary)),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    "Present: ${data['present_count'] ?? 0} / ${data['total_sessions'] ?? 0}",
                    style: theme.body.copyWith(color: theme.secondaryText),
                  ),
                  const SizedBox(height: 16),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: LinearProgressIndicator(
                      value: percentage / 100,
                      backgroundColor: theme.surfaceContainer,
                      color: percentage < 75 ? theme.error : theme.primary,
                      minHeight: 8,
                    ),
                  ),
                  const SizedBox(height: 16),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: percentage < 75 ? theme.errorBackground : (percentage < 80 ? Colors.orange.shade50 : theme.accent.withOpacity(0.1)),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      getPrediction(percentage),
                      style: theme.caption.copyWith(
                        color: percentage < 75 ? theme.error : (percentage < 80 ? Colors.orange.shade800 : theme.primary),
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            
            const SizedBox(height: 32),
            Text("Attendance Log", style: theme.display2),
            const SizedBox(height: 16),

            // 📅 FILTERS
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                  decoration: BoxDecoration(
                      border: Border.all(color: theme.surfaceContainer),
                      borderRadius: BorderRadius.circular(12)),
                  child: DropdownButton<String>(
                    value: selectedMonth,
                    underline: const SizedBox(),
                    icon: Icon(Icons.keyboard_arrow_down, color: theme.primary),
                    items: [
                      DropdownMenuItem(
                        value: "All", 
                        child: Text("All Months", style: theme.body)
                      ),
                      ...List.generate(12, (index) {
                        return DropdownMenuItem(
                          value: (index + 1).toString(),
                          child: Text("Month ${index + 1}", style: theme.body),
                        );
                      })
                    ],
                    onChanged: (val) {
                      setState(() {
                        selectedMonth = val!;
                      });
                      applyFilters();
                    },
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    decoration: BoxDecoration(
                        border: Border.all(color: theme.surfaceContainer),
                        borderRadius: BorderRadius.circular(12)),
                    child: TextField(
                      decoration: InputDecoration(
                        hintText: "Search YYYY-MM-DD",
                        hintStyle: theme.body.copyWith(color: theme.secondaryText),
                        border: InputBorder.none,
                        icon: Icon(Icons.search, color: theme.secondaryText, size: 20),
                      ),
                      style: theme.body,
                      onChanged: (val) {
                        searchDate = val;
                        applyFilters();
                      },
                    ),
                  ),
                ),
              ],
            ),

            const SizedBox(height: 24),

            // 📋 LIST
            (filteredList is List && filteredList.isNotEmpty)
                ? ListView.separated(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: filteredList.length,
                    separatorBuilder: (context, index) => const SizedBox(height: 12),
                    itemBuilder: (context, index) {
                      final item = filteredList[index] ?? {};

                      final date = item['date']?.toString() ?? "-";
                      final status = item['status']?.toString() ?? "Absent";
                      final time = item['time'];
                      final markedBy = item['marked_by'];
                      
                      final isPresent = status == "Present";

                      return EliteCard(
                        padding: const EdgeInsets.all(16),
                        child: Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: isPresent ? theme.accent.withOpacity(0.2) : theme.errorBackground,
                                borderRadius: BorderRadius.circular(12)
                              ),
                              child: Icon(
                                isPresent ? Icons.check_circle_outline : Icons.cancel_outlined,
                                color: isPresent ? theme.primary : theme.error,
                              )
                            ),
                            const SizedBox(width: 16),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(date, style: theme.subtitle),
                                  const SizedBox(height: 4),
                                  Text(
                                    (time != null && time.toString().length >= 16)
                                        ? time.toString().substring(11, 16)
                                        : "No Time",
                                    style: theme.caption.copyWith(color: theme.secondaryText)
                                  ),
                                ]
                              ),
                            ),
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.end,
                              children: [
                                PerformanceBadge(
                                  label: status,
                                  status: isPresent ? BadgeStatus.success : BadgeStatus.error,
                                ),
                                const SizedBox(height: 6),
                                Text(
                                  markedBy?.toString() ?? "-",
                                  style: theme.caption.copyWith(color: theme.secondaryText)
                                )
                              ],
                            )
                          ],
                        ),
                      );
                    },
                  )
                : Center(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 32),
                      child: Text("No Attendance Records Found", style: theme.body.copyWith(color: theme.secondaryText)),
                    ),
                  ),
          ],
        ),
      ),
    );
  }
}