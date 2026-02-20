import 'package:flutter/material.dart';
import 'dart:convert';
import 'package:sportsverse_app/api/api_client.dart';

class ViewAttendanceScreen extends StatefulWidget {
  const ViewAttendanceScreen({super.key});

  @override
  State<ViewAttendanceScreen> createState() => _ViewAttendanceScreenState();
}

class _ViewAttendanceScreenState extends State<ViewAttendanceScreen> {
  bool _showReport = false;
  bool _isLoading = false;
  String? _selectedBranch;
  String? _selectedBatch;
  List<dynamic> _branches = [];
  List<dynamic> _batches = [];
  List<dynamic> _attendanceSummary = [];

  @override
  void initState() {
    super.initState();
    _fetchBranches();
  }

  Future<void> _fetchBranches() async {
    try {
      final response = await apiClient.get('/api/organizations/branches/');
      if (response.statusCode == 200) {
        setState(() => _branches = jsonDecode(response.body));
      }
    } catch (e) {
      debugPrint("Error: $e");
    }
  }

  Future<void> _fetchBatches(String branchId) async {
    try {
      final response = await apiClient.get('/api/organizations/batches/?branch=$branchId');
      if (response.statusCode == 200) {
        final decoded = jsonDecode(response.body);
        setState(() => _batches = decoded is List ? decoded : (decoded['results'] ?? []));
      }
    } catch (_) {}
  }

  Future<void> _viewAttendance() async {
    if (_selectedBatch == null) return;
    setState(() {
      _isLoading = true;
      _showReport = false;
      _attendanceSummary = [];
    });

    try {
      final response = await apiClient.get('/api/organizations/batch-summary/?batch=$_selectedBatch');
      if (response.statusCode == 200) {
        setState(() {
          _attendanceSummary = jsonDecode(response.body);
          _showReport = true;
        });
      }
    } catch (e) {
      debugPrint("API Error: $e");
    } finally {
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('ACADEMY ADMIN ATTENDANCE'), // OBVIOUS TITLE
        backgroundColor: const Color(0xFF006C62),
        foregroundColor: Colors.white,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            DropdownButtonFormField<String>(
              value: _selectedBranch,
              hint: const Text("Select Branch"),
              items: _branches.map((b) => DropdownMenuItem(value: b['id'].toString(), child: Text(b['name']))).toList(),
              onChanged: (val) {
                setState(() { _selectedBranch = val; _selectedBatch = null; _batches = []; });
                if (val != null) _fetchBatches(val);
              },
            ),
            const SizedBox(height: 10),
            DropdownButtonFormField<String>(
              value: _selectedBatch,
              hint: const Text("Select Batch"),
              items: _batches.map((b) => DropdownMenuItem(value: b['id'].toString(), child: Text(b['name']))).toList(),
              onChanged: (val) => setState(() => _selectedBatch = val),
            ),
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF006C62)),
                onPressed: _isLoading ? null : _viewAttendance,
                child: _isLoading ? const CircularProgressIndicator(color: Colors.white) : const Text("VIEW ATTENDANCE", style: TextStyle(color: Colors.white)),
              ),
            ),
            if (_showReport) ...[
              const SizedBox(height: 20),
              ListView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: _attendanceSummary.length,
                itemBuilder: (context, i) => Card(
                  child: ListTile(
                    title: Text(_attendanceSummary[i]['student_name']),
                    trailing: Text("${_attendanceSummary[i]['attendance_percentage']}%", style: const TextStyle(fontWeight: FontWeight.bold)),
                  ),
                ),
              ),
            ]
          ],
        ),
      ),
    );
  }
}