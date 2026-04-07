import 'dart:convert';
import 'package:flutter/material.dart';
import '../../api/api_client.dart';

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
      setState(() => isLoading = false);
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
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text("⚠️ You were absent for 2+ days!"),
            backgroundColor: Colors.red,
          ),
        );
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
    if (isLoading) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    if (attendanceData.isEmpty) {
      return const Scaffold(
        body: Center(child: Text("No Data")),
      );
    }

    final data = attendanceData[0];

    final percentage =
        (data['attendance_percentage'] ?? 0).toDouble();

    return Scaffold(
      appBar: AppBar(title: const Text("My Attendance")),
      body: Column(
        children: [
          // 🚨 ALERT
          if (percentage < 75)
            Container(
              width: double.infinity,
              color: Colors.red,
              padding: const EdgeInsets.all(10),
              child: const Text(
                "⚠️ Low Attendance!",
                style: TextStyle(color: Colors.white),
              ),
            ),

          // 📊 SUMMARY
          Card(
            margin: const EdgeInsets.all(10),
            child: ListTile(
              title: Text("Attendance: $percentage%"),
              subtitle: Text(
                "Present: ${data['present_count'] ?? 0} / ${data['total_sessions'] ?? 0}",
              ),
            ),
          ),

          // 📊 PROGRESS
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: LinearProgressIndicator(
              value: percentage / 100,
              minHeight: 10,
            ),
          ),

          // 📊 PREDICTION
          Padding(
            padding: const EdgeInsets.all(10),
            child: Text(
              getPrediction(percentage),
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
          ),

          // 📅 FILTERS
          Row(
            children: [
              DropdownButton<String>(
                value: selectedMonth,
                items: [
                  const DropdownMenuItem(
                      value: "All", child: Text("All")),
                  ...List.generate(12, (index) {
                    return DropdownMenuItem(
                      value: (index + 1).toString(),
                      child: Text("Month ${index + 1}"),
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

              const SizedBox(width: 10),

              Expanded(
                child: TextField(
                  decoration: const InputDecoration(
                    hintText: "Search YYYY-MM-DD",
                  ),
                  onChanged: (val) {
                    searchDate = val;
                    applyFilters();
                  },
                ),
              ),
            ],
          ),

          const SizedBox(height: 10),

          // 📋 HEADER
          Container(
            color: Colors.grey[300],
            padding: const EdgeInsets.all(10),
            child: const Row(
              children: [
                Expanded(flex: 3, child: Text("Date")),
                Expanded(flex: 2, child: Text("Status")),
                Expanded(flex: 2, child: Text("Time")),
                Expanded(flex: 2, child: Text("By")),
              ],
            ),
          ),

          // 📋 TABLE (FULL SAFE)
          Expanded(
            child: (filteredList is List && filteredList.isNotEmpty)
                ? ListView.builder(
                    itemCount: filteredList.length,
                    itemBuilder: (context, index) {
                      final item = filteredList[index] ?? {};

                      final date =
                          item['date']?.toString() ?? "-";
                      final status =
                          item['status']?.toString() ?? "Absent";
                      final time = item['time'];
                      final markedBy = item['marked_by'];

                      return Padding(
                        padding: const EdgeInsets.all(8),
                        child: Row(
                          children: [
                            Expanded(flex: 3, child: Text(date)),

                            Expanded(
                              flex: 2,
                              child: Text(
                                status,
                                style: TextStyle(
                                  color: status == "Present"
                                      ? Colors.green
                                      : Colors.red,
                                ),
                              ),
                            ),

                            Expanded(
                              flex: 2,
                              child: Text(
                                (time != null &&
                                        time.toString().length >= 16)
                                    ? time
                                        .toString()
                                        .substring(11, 16)
                                    : "-",
                              ),
                            ),

                            Expanded(
                              flex: 2,
                              child:
                                  Text(markedBy?.toString() ?? "-"),
                            ),
                          ],
                        ),
                      );
                    },
                  )
                : const Center(
                    child: Text("No Attendance Records"),
                  ),
          ),
        ],
      ),
    );
  }
}