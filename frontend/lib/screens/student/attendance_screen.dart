import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:sportsverse_app/providers/student_provider.dart';

class AttendanceScreen extends StatelessWidget {
  const AttendanceScreen({super.key});

  @override
  Widget build(BuildContext context) {
    // 1. Listen to the provider
    final provider = context.watch<StudentProvider>();
    
    // 2. Extract real data from provider
    // Note: Adjust these variable names to match your StudentProvider exactly
    final records = provider.attendanceRecords ?? []; 
    final totalSessions = records.length;
    final presentCount = records.where((r) => r.status == "Present").length;
    final absentCount = records.where((r) => r.status == "Absent").length;
    
    // Calculate dynamic percentage
    double attendanceRate = totalSessions > 0 ? presentCount / totalSessions : 0.0;

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFB),
      appBar: AppBar(
        title: const Text("My Attendance", style: TextStyle(fontWeight: FontWeight.bold, color: Colors.black)),
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
        : Column(
            children: [
              // Dynamic Stats Header
              _buildStatsHeader(attendanceRate, presentCount.toString(), absentCount.toString()),
              const SizedBox(height: 10),
              Expanded(
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  decoration: const BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.only(topLeft: Radius.circular(30), topRight: Radius.circular(30)),
                  ),
                  child: records.isEmpty 
                    ? const Center(child: Text("No attendance records found from database."))
                    : _buildAttendanceList(records),
                ),
              ),
            ],
          ),
    );
  }

  // --- DYNAMIC HEADER ---
  Widget _buildStatsHeader(double rate, String present, String absent) {
    return Container(
      padding: const EdgeInsets.all(25),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text("Performance", style: TextStyle(color: Colors.grey, fontSize: 14)),
              Text(
                rate >= 0.75 ? "Excellent!" : rate >= 0.5 ? "Good Job!" : "Needs Focus", 
                style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Color(0xFF1B3D2F))
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  _miniStat(present, "Present", Colors.green),
                  const SizedBox(width: 15),
                  _miniStat(absent, "Absent", Colors.red),
                ],
              )
            ],
          ),
          Stack(
            alignment: Alignment.center,
            children: [
              SizedBox(
                height: 80,
                width: 80,
                child: CircularProgressIndicator(
                  value: rate,
                  strokeWidth: 8,
                  backgroundColor: Colors.grey[200],
                  valueColor: const AlwaysStoppedAnimation<Color>(Color(0xFF1B3D2F)),
                ),
              ),
              Text("${(rate * 100).toInt()}%", style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
            ],
          )
        ],
      ),
    );
  }

  Widget _miniStat(String val, String label, Color color) {
    return Row(
      children: [
        Container(width: 8, height: 8, decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
        const SizedBox(width: 5),
        Text("$val $label", style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500)),
      ],
    );
  }

  // --- DYNAMIC LIST ---
  Widget _buildAttendanceList(List records) {
    return ListView.builder(
      padding: const EdgeInsets.only(top: 25),
      itemCount: records.length,
      itemBuilder: (context, index) {
        // Mapping your database model to the UI
        final record = records[index];
        return _attendanceCard({
          "date": record.date ?? "N/A", // Ensure your model has a .date
          "day": record.day ?? "Training Day", 
          "status": record.status ?? "Null", // Present, Absent, or Null
          "coach": record.coachName ?? "Admin", 
        });
      },
    );
  }

  Widget _attendanceCard(Map<String, dynamic> data) {
    Color statusColor;
    IconData statusIcon;

    switch (data['status']) {
      case 'Present':
        statusColor = Colors.green;
        statusIcon = Icons.check_circle;
        break;
      case 'Absent':
        statusColor = Colors.red;
        statusIcon = Icons.cancel;
        break;
      default: // This handles the 'null' or 'pending' state
        statusColor = Colors.orange;
        statusIcon = Icons.hourglass_top;
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 15),
      padding: const EdgeInsets.all(15),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.grey.shade100),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.03), blurRadius: 10, offset: const Offset(0, 5))],
      ),
      child: Row(
        children: [
          // Dynamic Date Handling
          Column(
            children: [
              Text(
                data['date'].toString().split(" ")[0], 
                style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)
              ),
              Text(
                data['date'].toString().contains(" ") ? data['date'].toString().split(" ")[1] : "", 
                style: const TextStyle(fontSize: 11, color: Colors.grey)
              ),
            ],
          ),
          const SizedBox(width: 15),
          Container(width: 1, height: 40, color: Colors.grey[200]),
          const SizedBox(width: 15),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(data['day'], style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                Text("Verified by ${data['coach']}", style: const TextStyle(fontSize: 11, color: Colors.grey)),
              ],
            ),
          ),
          // Status Badge
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
            decoration: BoxDecoration(
              color: statusColor.withOpacity(0.1),
              borderRadius: BorderRadius.circular(30),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(statusIcon, color: statusColor, size: 12),
                const SizedBox(width: 4),
                Text(data['status'], style: TextStyle(color: statusColor, fontWeight: FontWeight.bold, fontSize: 11)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}