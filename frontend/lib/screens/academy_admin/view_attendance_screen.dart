import 'package:flutter/material.dart';
import 'dart:convert';                                       // <--- added
import 'package:sportsverse_app/api/api_client.dart';       // <--- added

class ViewAttendanceScreen extends StatefulWidget {
  const ViewAttendanceScreen({super.key});

  @override
  State<ViewAttendanceScreen> createState() => _ViewAttendanceScreenState();
}

class _ViewAttendanceScreenState extends State<ViewAttendanceScreen> {
  bool _showReport = false;

  // NEW -- dropdown selections
  String? _selectedBranch;
  String? _selectedBatch;
  String? _selectedBranchName;
  String? _selectedBatchName;
  String? _selectedStudentId;
  String? _selectedStudentName;
  String? _selectedTimeline;

  // NEW -- dynamic lists to populate dropdowns
  List<dynamic> _branches = [];
  List<dynamic> _batches = [];
  List<Map<String, String>> _students = [];

  // NEW -- attendance records
  List<dynamic> _attendanceRecords = [];

  @override
  void initState() {
    super.initState();
    _fetchBranches(); // initial load
  }

  Future<void> _fetchBranches() async {
    final response = await apiClient.get('/organizations/branches/');
    if (response.statusCode == 200) {
      setState(() {
        _branches = jsonDecode(response.body);
      });
    }
  }

  Future<void> _fetchBatches(String branchId) async {
    try {
      final response =
          await apiClient.get('/organizations/batches/?branch=$branchId');
      if (response.statusCode == 200) {
        final decoded = jsonDecode(response.body);
        setState(() {
          _batches = decoded is List
              ? decoded
              : (decoded is Map && decoded['results'] is List
                  ? List<dynamic>.from(decoded['results'])
                  : <dynamic>[]);
        });
      }
    } catch (_) {
      setState(() {
        _batches = [];
      });
    }
  }

  Future<void> _fetchStudents(String batchId) async {
    try {
      final response =
          await apiClient.get('/organizations/enrollments/?batch=$batchId');
      if (response.statusCode == 200) {
        final decoded = jsonDecode(response.body);
        final List<dynamic> items = decoded is List
            ? decoded
            : (decoded is Map && decoded['results'] is List
                ? List<dynamic>.from(decoded['results'])
                : <dynamic>[]);
        setState(() {
          _students = items.map<Map<String, String>>((e) {
            if (e is! Map) return {'id': '', 'name': 'Unnamed Student'};
            final dynamic studentField = e['student'];
            if (studentField is Map) {
              final id = (studentField['id'] ?? '').toString();
              final first = (studentField['first_name'] ?? '').toString();
              final last = (studentField['last_name'] ?? '').toString();
              final name = (first + ' ' + last).trim();
              return {'id': id, 'name': name.isNotEmpty ? name : 'Unnamed Student'};
            }
            // Fallback to flat fields from EnrollmentSerializer
            final id = (e['student'] ?? '').toString();
            final first = (e['student_name'] ?? '').toString();
            final last = (e['student_last_name'] ?? '').toString();
            final name = (first + ' ' + last).trim();
            return {'id': id, 'name': name.isNotEmpty ? name : 'Unnamed Student'};
          }).toList();
        });
      }
    } catch (_) {
      setState(() {
        _students = [];
      });
    }
  }

  Future<void> _viewAttendance() async {
    setState(() {
      _showReport = false;
      _attendanceRecords = [];
    });
    try {
      final response = await apiClient.get(
          '/organizations/attendance/?student=' + (_selectedStudentId ?? '') + '&batch=' + (_selectedBatch ?? ''));
      if (response.statusCode == 200) {
        final decoded = jsonDecode(response.body);
        setState(() {
          _attendanceRecords = decoded is List
              ? decoded
              : (decoded is Map && decoded['results'] is List
                  ? List<dynamic>.from(decoded['results'])
                  : <dynamic>[]);
          _showReport = true;
        });
      }
    } catch (_) {
      setState(() {
        _showReport = false;
        _attendanceRecords = [];
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    // Preselect from arguments once on first build
    final args = ModalRoute.of(context)?.settings.arguments;
    if (args is Map && _selectedBranch == null && _selectedBatch == null) {
      final int? branchId = args['branchId'] as int?;
      final int? batchId = args['batchId'] as int?;
      final String? branchName = args['branchName'] as String?;
      final String? batchName = args['batchName'] as String?;
      if (branchId != null) {
        _selectedBranch = branchId.toString();
        _selectedBranchName = branchName;
        _fetchBatches(_selectedBranch!);
      }
      if (batchId != null) {
        _selectedBatch = batchId.toString();
        _selectedBatchName = batchName;
        // ensure students are loaded when batch is prefilled
        _fetchStudents(_selectedBatch!);
      }
    }
    final bool isPrefilled = _selectedBranch != null && _selectedBatch != null;
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Student Attendance Report',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
      ),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24.0),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 800),
            child: Card(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12.0),
              ),
              elevation: 4.0,
              child: Column(
                children: [
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(
                        horizontal: 20, vertical: 16),
                    decoration: const BoxDecoration(
                      color: Color(0xFF006C62),
                      borderRadius: BorderRadius.only(
                        topLeft: Radius.circular(12.0),
                        topRight: Radius.circular(12.0),
                      ),
                    ),
                    child: const Text(
                      'Student Attendance Report',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.all(20.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // ---- BRANCH (hide if prefilled)
                        if (!isPrefilled)
                          _DropdownInput(
                            label: 'Branch',
                            hint: 'Select Branch',
                            icon: Icons.school,
                            items: _branches
                                .map<String>((b) => b['id'].toString())
                                .toList(),
                            onChanged: (value) async {
                              setState(() {
                                _selectedBranch = value;
                                _selectedBatch = null;
                                _selectedStudentId = null;
                                _selectedStudentName = null;
                                _batches = [];
                                _students = [];
                                _showReport = false;
                                _attendanceRecords = [];
                              });
                              if (value != null) {
                                await _fetchBatches(value);
                              }
                            },
                          )
                        else
                          Padding(
                            padding: const EdgeInsets.only(bottom: 12.0),
                            child: Row(
                              children: [
                                const Icon(Icons.school),
                                const SizedBox(width: 8),
                                Text(_selectedBranchName ?? 'Branch')
                              ],
                            ),
                          ),
                        const SizedBox(height: 20),
                        if (!isPrefilled)
                          _DropdownInput(
                            label: 'Batch',
                            hint: 'Select Batch',
                            icon: Icons.group,
                            items: _batches
                                .map<String>((b) => b['id'].toString())
                                .toList(),
                            onChanged: (value) async {
                              setState(() {
                                _selectedBatch = value;
                                _selectedStudentId = null;
                                _selectedStudentName = null;
                                _students = [];
                                _showReport = false;
                                _attendanceRecords = [];
                              });
                              if (value != null) {
                                await _fetchStudents(value);
                              }
                            },
                          )
                        else
                          Padding(
                            padding: const EdgeInsets.only(bottom: 12.0),
                            child: Row(
                              children: [
                                const Icon(Icons.group),
                                const SizedBox(width: 8),
                                Text(_selectedBatchName ?? 'Batch')
                              ],
                            ),
                          ),
                        const SizedBox(height: 20),
                        // ---- STUDENT DROPDOWN (dynamic)
                        _DropdownInput(
                          label: 'Student',
                          hint: 'Select Student',
                          icon: Icons.person,
                          items: _students
                              .map<String>((s) => s['name'] ?? 'Unnamed Student')
                              .toList(),
                          onChanged: (value) {
                            setState(() {
                              _selectedStudentName = value;
                              final match = _students.firstWhere(
                                  (m) => m['name'] == value,
                                  orElse: () => {'id': '', 'name': ''});
                              _selectedStudentId = match['id'];
                              _showReport = false;
                              _attendanceRecords = [];
                            });
                          },
                        ),
                        const SizedBox(height: 20),
                        // ---- TIMELINE (static options)
                        _DropdownInput(
                          label: 'Timeline',
                          hint: 'Current Month',
                          icon: Icons.calendar_month,
                          items: [
                            'Current Month',
                            'Last 3 Months',
                            'Last 6 Months',
                            'Custom Date Range'
                          ],
                          onChanged: (v) {
                            setState(() => _selectedTimeline = v);
                          },
                        ),
                        const SizedBox(height: 20),
                        GestureDetector(
                          onTap: (_selectedBatch != null &&
                                  _selectedStudentId != null && (_selectedStudentId ?? '').isNotEmpty)
                              ? _viewAttendance
                              : null,
                          child: Container(
                            width: double.infinity,
                            padding: const EdgeInsets.all(16.0),
                            decoration: BoxDecoration(
                              color: (_selectedBatch != null &&
                                      _selectedStudentId != null && (_selectedStudentId ?? '').isNotEmpty)
                                  ? const Color(0xFF006C62)
                                  : Colors.grey,
                              borderRadius: BorderRadius.circular(8.0),
                            ),
                            child: const Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(Icons.search, color: Colors.white),
                                SizedBox(width: 8),
                                Text(
                                  'View Attendance',
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontSize: 16,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(height: 30),
                        if (_showReport) _buildAttendanceReport(),
                      ],
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

  Widget _buildAttendanceReport() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: double.infinity,
          padding:
              const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
          decoration: const BoxDecoration(
            color: Color(0xFF006C62),
            borderRadius: BorderRadius.only(
              topLeft: Radius.circular(12.0),
              topRight: Radius.circular(12.0),
            ),
          ),
          child: Text(
            'Attendance Records for ${_selectedStudentName ?? 'Student'}',
            style: const TextStyle(
              color: Colors.white,
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
        const SizedBox(height: 20),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: DataTable(
            columns: const [
              DataColumn(label: Text('No.')),
              DataColumn(label: Text('Date')),
              DataColumn(label: Text('Status')),
            ],
            rows: _attendanceRecords.asMap().entries.map((entry) {
              final idx = entry.key + 1;
              final record = entry.value;
              return DataRow(
                cells: [
                  DataCell(Text(idx.toString())),
                  DataCell(Text(record['date'].toString())),
                  DataCell(Text(record['is_present'] ? 'Present' : 'Absent')),
                ],
              );
            }).toList(),
          ),
        ),
      ],
    );
  }
}

// reusable dropdown (unchanged except onChanged added)
class _DropdownInput extends StatelessWidget {
  final String label;
  final String hint;
  final IconData icon;
  final List<String> items;
  final void Function(String?) onChanged;                // <--- added

  const _DropdownInput({
    required this.label,
    required this.hint,
    required this.icon,
    required this.items,
    required this.onChanged,                             // <--- added
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 8),
        DropdownButtonFormField<String>(
          decoration: InputDecoration(
            hintText: hint,
            prefixIcon: Icon(icon),
            border: const OutlineInputBorder(
              borderRadius: BorderRadius.all(Radius.circular(8.0)),
              borderSide: BorderSide(color: Colors.grey),
            ),
            enabledBorder: const OutlineInputBorder(
              borderRadius: BorderRadius.all(Radius.circular(8.0)),
              borderSide: BorderSide(color: Colors.grey),
            ),
            contentPadding:
                const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          ),
          items: items.map((String value) {
            return DropdownMenuItem<String>(
              value: value,
              child: Text(value),
            );
          }).toList(),
          onChanged: onChanged,                           // <--- added
        ),
      ],
    );
  }
}
