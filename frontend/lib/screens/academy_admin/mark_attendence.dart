import 'package:flutter/material.dart';
import '../../api/api_client.dart';
import '../../api/branch_api.dart';
import '../../api/batch_api.dart';
import '../../api/attendance_api.dart';

class MarkAttendanceScreen extends StatefulWidget {
  const MarkAttendanceScreen({super.key});

  @override
  State<MarkAttendanceScreen> createState() =>
      _MarkAttendanceScreenState();
}

class _MarkAttendanceScreenState extends State<MarkAttendanceScreen> {

  // 🔥 API SETUP
  final apiClient = ApiClient();
  late AttendanceApi attendanceApi;
  late BranchApi branchApi;
  late BatchApi batchApi;

  List branches = [];
  List batches = [];
  List students = [];

  int? selectedBranch;
  int? selectedBatch;

  DateTime selectedDate = DateTime.now();

  Map<int, bool> attendanceMap = {};

  bool isLoading = false;

  @override
  void initState() {
    super.initState();

    attendanceApi = AttendanceApi(apiClient);
    branchApi = BranchApi(apiClient);
    batchApi = BatchApi(apiClient);

    fetchBranches();
  }

  // 🔥 FETCH BRANCHES
  Future<void> fetchBranches() async {
    final res = await branchApi.getBranches();
    setState(() => branches = res);
  }

  // 🔥 FETCH BATCHES
  Future<void> fetchBatches(int branchId) async {
    final res = await batchApi.getBatches();

    // ⚠️ IMPORTANT: adjust field if needed
    batches = res.where((b) => b.branchId == branchId).toList();

    selectedBatch = null;
    students.clear();

    setState(() {});
  }

  // 🔥 FETCH STUDENTS
  Future<void> fetchStudents() async {
    if (selectedBatch == null) return;

    setState(() => isLoading = true);

    final res = await attendanceApi.getStudentsForAttendance(
      batchId: selectedBatch!,
      date: selectedDate.toString().split(' ')[0],
    );

    students = res;

    attendanceMap.clear();

    for (var s in students) {
      attendanceMap[s["enrollment_id"]] =
    !s["already_marked"] &&
    (s["sessions_left"] == null || s["sessions_left"] > 0);
    }

    setState(() => isLoading = false);
  }

  // 🔥 SUBMIT ATTENDANCE
  Future<void> submitAttendance() async {
    List data = [];

    attendanceMap.forEach((id, present) {
      if (present) {
        data.add({
          "enrollment_id": id,
          "date": selectedDate.toString().split(' ')[0],
        });
      }
    });

    await attendanceApi.markBulkAttendance(data);

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text("Attendance Saved ✅")),
    );

    fetchStudents();
  }

  // 🔥 STUDENT CARD
// 🔥 STUDENT CARD
Widget buildStudentCard(Map s) {
  final enrollmentId = s["enrollment_id"];
  final sessionsLeft = s["sessions_left"];
  final isCompleted = sessionsLeft != null && sessionsLeft <= 0;
  final isMarked = s["already_marked"] == true;

  // ✅ SAFE NULL HANDLING
  final String markedBy = (s["marked_by"] ?? "").toString();

  return Card(
    margin: const EdgeInsets.symmetric(vertical: 6),
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(12),
    ),
    elevation: 3,
    child: ListTile(
      title: Text(
        s["student_name"],
        style: const TextStyle(fontWeight: FontWeight.w600),
      ),

      subtitle: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            sessionsLeft == null
                ? "Unlimited Sessions"
                : "Sessions Left: $sessionsLeft",
          ),

          // 🔥 FIXED: SHOW WHO MARKED (NO CRASH)
          if (isMarked)
            Text(
              markedBy.isNotEmpty
                  ? (markedBy.toLowerCase().contains("coach")
                      ? "Marked by Coach"
                      : "Marked by Admin")
                  : "Marked",
              style: const TextStyle(
                color: Colors.blue,
                fontSize: 12,
              ),
            ),
        ],
      ),

      trailing: isCompleted
          ? const Chip(
              label: Text("Completed"),
              backgroundColor: Colors.grey,
            )
          : isMarked
              ? const Chip(
                  label: Text("Locked"),
                  backgroundColor: Colors.orange,
                )
              : Checkbox(
                  value: attendanceMap[enrollmentId],
                  onChanged: (val) {
                    setState(() {
                      attendanceMap[enrollmentId] = val!;
                    });
                  },
                ),
    ),
  );
}

  // 🔥 DATE PICKER
  Future<void> pickDate() async {
    DateTime? picked = await showDatePicker(
      context: context,
      initialDate: selectedDate,
      firstDate: DateTime(2023),
      lastDate: DateTime(2100),
    );

    if (picked != null) {
      selectedDate = picked;
      fetchStudents();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Mark Attendance"),
        centerTitle: true,
      ),
      body: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          children: [

            // 🔻 BRANCH DROPDOWN
            DropdownButtonFormField<int>(
              decoration:
                  const InputDecoration(labelText: "Select Branch"),
              value: selectedBranch,
              items: branches.map<DropdownMenuItem<int>>((b) {
                return DropdownMenuItem(
                  value: b.id,
                  child: Text(b.name),
                );
              }).toList(),
              onChanged: (val) {
                selectedBranch = val;
                fetchBatches(val!);
              },
            ),

            const SizedBox(height: 10),

            // 🔻 BATCH DROPDOWN
            DropdownButtonFormField<int>(
              decoration:
                  const InputDecoration(labelText: "Select Batch"),
              value: selectedBatch,
              items: batches.map<DropdownMenuItem<int>>((b) {
                return DropdownMenuItem(
                  value: b.id,
                  child: Text(b.name),
                );
              }).toList(),
              onChanged: (val) {
                setState(() => selectedBatch = val);
                fetchStudents();
              },
            ),

            const SizedBox(height: 10),

            // 📅 DATE PICKER
            ListTile(
              tileColor: Colors.grey.shade100,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
              title: Text(
                "Date: ${selectedDate.toString().split(' ')[0]}",
              ),
              trailing: const Icon(Icons.calendar_today),
              onTap: pickDate,
            ),

            const SizedBox(height: 10),

            if (isLoading) const CircularProgressIndicator(),

            Expanded(
              child: students.isEmpty
                  ? const Center(child: Text("No students found"))
                  : ListView.builder(
                      itemCount: students.length,
                      itemBuilder: (context, index) {
                        return buildStudentCard(students[index]);
                      },
                    ),
            ),

            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed:
                    students.isEmpty ? null : submitAttendance,
                child: const Text("Submit Attendance"),
              ),
            ),
          ],
        ),
      ),
    );
  }
}