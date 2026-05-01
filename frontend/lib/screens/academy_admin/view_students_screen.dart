import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '/providers/admin_provider.dart';
import '/providers/auth_provider.dart';
import 'package:sportsverse_app/api/branch_api.dart';
import 'package:sportsverse_app/api/batch_api.dart';
import 'package:sportsverse_app/models/branch.dart';
import 'package:sportsverse_app/models/batch.dart';
class ViewStudentsScreen extends StatefulWidget {
  
  const ViewStudentsScreen({super.key});

  
 
  @override
  State<ViewStudentsScreen> createState() => _ViewStudentsScreenState();
}

class _ViewStudentsScreenState extends State<ViewStudentsScreen> {
  String? selectedBranchId;
  String? selectedBatchId;
  
  List<Branch> branches = [];
  List<Batch> batches = [];
  bool isLoadingFilters = true;
  bool _hasLoaded = false;

@override
void initState() {
  super.initState();

  WidgetsBinding.instance.addPostFrameCallback((_) async {
    final authProvider =
        Provider.of<AuthProvider>(context, listen: false);

    // ✅ WAIT until auth finishes
    while (authProvider.isLoading) {
      await Future.delayed(const Duration(milliseconds: 100));
    }

    // ✅ ONLY CALL API AFTER AUTH READY
    if (authProvider.currentUser != null) {
      _loadFilters();
      await Provider.of<AdminProvider>(context, listen: false)
          .fetchAllStudents(context);
    }
  });
}

  Future<void> _loadFilters() async {
    try {
      final fetchedBranches = await branchApi.getBranches();
      final fetchedBatches = await batchApi.getBatches();
      setState(() {
        branches = fetchedBranches;
        batches = fetchedBatches;
        isLoadingFilters = false;
      });
    } catch (e) {
      debugPrint("Error loading filters: $e");
      setState(() => isLoadingFilters = false);
    }
  }

  // ✅ APPLY FILTERS (CALL BACKEND)
  void applyFilters() {
    Provider.of<AdminProvider>(context, listen: false)
        .fetchAllStudents(
      context,
      branch: selectedBranchId,
      batch: selectedBatchId,
    );
  }

  @override
  Widget build(BuildContext context) {
    final provider = Provider.of<AdminProvider>(context);

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),

      // 🔝 APP BAR
      appBar: AppBar(
        title: const Text(
          "Student Directory",
          style: TextStyle(color: Colors.white),
        ),
        backgroundColor: const Color(0xFF006D77),
        iconTheme: const IconThemeData(color: Colors.white),
      ),

      body: Column(
        children: [
          _buildFilterSection(),
          Expanded(child: _buildStudentList(provider)),
        ],
      ),
    );
  }

  // 🔽 FILTER UI
  Widget _buildFilterSection() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
              color: Colors.black.withOpacity(0.05), blurRadius: 5)
        ],
      ),
      child: Row(
        children: [
          // 🔹 BRANCH DROPDOWN
          Expanded(
            child: DropdownButtonFormField<String?>(
              value: selectedBranchId,
              isExpanded: true,
              decoration: const InputDecoration(
                labelText: "Branch",
                border: InputBorder.none,
              ),
              items: [
                const DropdownMenuItem(value: null, child: Text("All Branches")),
                ...branches.map((b) => DropdownMenuItem(
                      value: b.id.toString(),
                      child: Text(
                        b.name,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ))
              ],
              onChanged: (val) {
                setState(() => selectedBranchId = val);
                applyFilters(); // 🔥 CALL API
              },
            ),
          ),

          const SizedBox(width: 10),

          // 🔹 BATCH DROPDOWN
          Expanded(
            child: DropdownButtonFormField<String?>(
              value: selectedBatchId,
              isExpanded: true,
              decoration: const InputDecoration(
                labelText: "Batch",
                border: InputBorder.none,
              ),
              items: [
                const DropdownMenuItem(value: null, child: Text("All Batches")),
                ...batches.map((b) => DropdownMenuItem(
                      value: b.id.toString(),
                      child: Text(
                        b.name,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ))
              ],
              onChanged: (val) {
                setState(() => selectedBatchId = val);
                applyFilters(); // 🔥 CALL API
              },
            ),
          ),
        ],
      ),
    );
  }

  // 📋 STUDENT LIST UI
  Widget _buildStudentList(AdminProvider provider) {
    // 🔄 LOADING
    if (provider.isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    // ❌ EMPTY
    if (provider.enrollments.isEmpty) {
      return const Center(child: Text("No students found"));
    }

    // ✅ LIST
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: provider.enrollments.length,
      itemBuilder: (context, index) {
        final student = provider.enrollments[index];

        return Card(
          elevation: 0,
          margin: const EdgeInsets.only(bottom: 12),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(15),
            side: BorderSide(color: Colors.grey.shade200),
          ),
          child: ListTile(
            contentPadding: const EdgeInsets.all(12),

            // 👤 AVATAR
            leading: CircleAvatar(
              radius: 25,
              backgroundColor: const Color(0xFF83C5BE),
              child: Text(
                student.studentName.isNotEmpty
                    ? student.studentName[0]
                    : "?",
                style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold),
              ),
            ),

            // 🧑 NAME
            title: Text(
              "${student.studentName} ${student.studentLastName}",
              style: const TextStyle(
                  fontWeight: FontWeight.bold, fontSize: 16),
            ),

            // 📄 DETAILS
            subtitle: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: 4),
                Text("Branch: ${student.branchName}"),
                Text("Batch: ${student.batchName}"),
                Text(
                  "Progress: ${student.progressDisplay}",
                  style: const TextStyle(
                    color: Color(0xFF006D77),
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),

            // 🔵 STATUS
            trailing: Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: student.isActive
                    ? Colors.green.shade50
                    : Colors.red.shade50,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text(
                student.isActive ? "ACTIVE" : "INACTIVE",
                style: TextStyle(
                  color: student.isActive
                      ? Colors.green
                      : Colors.red,
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  
}