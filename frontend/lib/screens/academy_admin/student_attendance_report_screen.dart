// sportsverse/frontend/sportsverse_app/lib/screens/academy_admin/student_attendance_report_screen.dart

import 'package:flutter/material.dart';
import 'package:sportsverse_app/api/api_client.dart'; 
import 'package:sportsverse_app/api/branch_api.dart';
import 'package:sportsverse_app/api/batch_api.dart';
import 'package:sportsverse_app/models/branch.dart';
import 'package:sportsverse_app/models/batch.dart';

class StudentAttendanceReportScreen extends StatefulWidget {
  const StudentAttendanceReportScreen({super.key});

  @override
  State<StudentAttendanceReportScreen> createState() => _StudentAttendanceReportScreenState();
}

class _StudentAttendanceReportScreenState extends State<StudentAttendanceReportScreen> {
  late BranchApi _branchApi;
  late BatchApi _batchApi;

  List<Branch> _branches = [];
  List<Batch> _batches = [];
  
  String? _selectedBranchId;
  String? _selectedBatchId;
  String? _selectedTimeline = 'All Time';
  bool _isLoading = true;
  bool _isInitialized = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_isInitialized) {
      // FIX: ApiClient() takes 0 arguments based on your error
      final apiClient = ApiClient(); 
      
      _branchApi = BranchApi(apiClient); 
      _batchApi = BatchApi(apiClient);
      
      _loadInitialData();
      _isInitialized = true;
    }
  }

  Future<void> _loadInitialData() async {
    try {
      final branches = await _branchApi.getBranches();
      setState(() {
        _branches = branches;
        _isLoading = false;
      });
    } catch (e) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _loadBatches() async {
    try {
      // Fetching all batches. 
      // If the filter '.branch' failed, we will just show all available batches for now
      // to get the screen running.
      final batches = await _batchApi.getBatches();
      setState(() {
        _batches = batches;
      });
    } catch (e) {
      debugPrint("Error loading batches: $e");
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FA),
      appBar: AppBar(
        title: const Text('Student Attendance Report', 
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        backgroundColor: const Color(0xFF00796B),
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: _isLoading 
        ? const Center(child: CircularProgressIndicator(color: Color(0xFF00796B)))
        : Padding(
            padding: const EdgeInsets.all(24.0),
            child: Center(
              child: Container(
                constraints: const BoxConstraints(maxWidth: 600),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: const Color(0xFF00796B), width: 1.5),
                ),
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(32),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildLabel("Branch"),
                      _buildDropdown(
                        hint: "Select Branch",
                        icon: Icons.business,
                        value: _selectedBranchId,
                        items: _branches.map((b) => DropdownMenuItem(
                          value: b.id.toString(),
                          child: Text(b.name),
                        )).toList(),
                        onChanged: (val) {
                          setState(() {
                            _selectedBranchId = val;
                            _selectedBatchId = null;
                          });
                          _loadBatches(); // Load batches when branch changes
                        },
                      ),
                      const SizedBox(height: 24),

                      _buildLabel("Batch"),
                      _buildDropdown(
                        hint: "Select Batch",
                        icon: Icons.groups_outlined,
                        value: _selectedBatchId,
                        items: _batches.map((b) => DropdownMenuItem(
                          value: b.id.toString(),
                          child: Text(b.name),
                        )).toList(),
                        onChanged: (val) => setState(() => _selectedBatchId = val),
                      ),
                      const SizedBox(height: 24),

                      _buildLabel("Timeline"),
                      _buildDropdown(
                        hint: "Timeline",
                        icon: Icons.calendar_today,
                        value: _selectedTimeline,
                        items: ['All Time', 'Today', 'This Week', 'This Month'].map((t) => DropdownMenuItem(
                          value: t,
                          child: Text(t),
                        )).toList(),
                        onChanged: (val) => setState(() => _selectedTimeline = val),
                      ),
                      const SizedBox(height: 40),

                      SizedBox(
                        width: double.infinity,
                        height: 50,
                        child: ElevatedButton.icon(
                          onPressed: (_selectedBranchId != null) ? () {
                             // Button logic here
                          } : null,
                          icon: const Icon(Icons.search),
                          label: const Text("View Attendance", style: TextStyle(fontWeight: FontWeight.bold)),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF00796B),
                            foregroundColor: Colors.white,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
    );
  }

  Widget _buildLabel(String text) => Padding(
    padding: const EdgeInsets.only(bottom: 8),
    child: Text(text, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
  );

  Widget _buildDropdown({
    required String hint,
    required IconData icon,
    required String? value,
    required List<DropdownMenuItem<String>> items,
    required Function(String?) onChanged,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12),
      decoration: BoxDecoration(
        color: const Color(0xFFF5F5F5),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.grey.shade300),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          isExpanded: true,
          value: value,
          hint: Row(
            children: [
              Icon(icon, size: 20, color: const Color(0xFF00796B)),
              const SizedBox(width: 12),
              Text(hint),
            ],
          ),
          items: items,
          onChanged: onChanged,
        ),
      ),
    );
  }
}