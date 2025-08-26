import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:sportsverse_app/api/api_client.dart';   // <-- add this
import 'dart:convert';                                 // <-- add this


// A model class to represent a student with their attendance status.
class Student {
  final int enrollmentId;
  final String name;
  bool isPresent;

  Student({required this.enrollmentId, required this.name, this.isPresent = false});
}

class TakeAttendanceScreen extends StatefulWidget {
  const TakeAttendanceScreen({super.key});

  @override
  State<TakeAttendanceScreen> createState() => _TakeAttendanceScreenState();
}

class _TakeAttendanceScreenState extends State<TakeAttendanceScreen> {
  // State variables for the screen
  List<Student> _students = [];
  bool _isLoading = false;
  bool _selectAll = false;

  // State variables to hold the selected dropdown values and date
  String? _selectedSport;
  String? _selectedBranch;
  String? _selectedBatch;
  String? _selectedSportName;
  String? _selectedBranchName;
  String? _selectedBatchName;
  DateTime? _selectedDate;

  // Controller for the date input field
  final TextEditingController _dateController = TextEditingController();

  // NEW: Lists for dropdowns
  List<dynamic> _sports = [];
  List<dynamic> _branches = [];
  List<dynamic> _batches = [];

  @override
  void initState() {
    super.initState();
    _fetchSports();
    _fetchBranches();
  }

  @override
  void dispose() {
    _dateController.dispose();
    super.dispose();
  }

  Future<void> _fetchSports() async {
    final response = await apiClient.get('/organizations/sports/');
    if (response.statusCode == 200) {
      setState(() {
        _sports = jsonDecode(response.body);
      });
    }
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
    final response = await apiClient.get('/organizations/batches/?branch=$branchId');
    if (response.statusCode == 200) {
      setState(() {
        _batches = jsonDecode(response.body);
      });
    }
  }

  // Fetch enrolled students for the selected batch
  Future<void> _fetchStudents() async {
    if (_selectedBatch == null) return;

    setState(() {
      _isLoading = true;
      _students = [];
    });

    try {
      final response = await apiClient
          .get('/organizations/enrollments/?batch=' + _selectedBatch!);

      if (response.statusCode == 200) {
        final decoded = jsonDecode(response.body);
        final List<dynamic> items = decoded is List
            ? decoded
            : (decoded is Map && decoded['results'] is List
                ? List<dynamic>.from(decoded['results'])
                : <dynamic>[]);

        final fetchedStudents = items.map<Student>((item) {
          // Support both nested student object (if ever provided) and flat name fields
          final dynamic studentField = (item is Map) ? item['student'] : null;
          final bool hasNested = studentField is Map;
          final String firstFromObj = hasNested ? (studentField['first_name'] ?? '').toString() : '';
          final String lastFromObj = hasNested ? (studentField['last_name'] ?? '').toString() : '';
          final String firstFromFlat = (item is Map) ? (item['student_name'] ?? '').toString() : '';
          final String lastFromFlat = (item is Map) ? (item['student_last_name'] ?? '').toString() : '';
          final String first = firstFromObj.isNotEmpty ? firstFromObj : firstFromFlat;
          final String last = lastFromObj.isNotEmpty ? lastFromObj : lastFromFlat;
          final String fullName = (first + ' ' + last).trim();
          final int enrollmentId = (item is Map && item['id'] != null)
              ? int.tryParse(item['id'].toString()) ?? 0
              : 0;
          return Student(
            enrollmentId: enrollmentId,
            name: fullName.isNotEmpty ? fullName : 'Unnamed Student',
          );
        }).toList();

        setState(() {
          _students = fetchedStudents;
          _selectAll = false;
        });
      }
    } catch (_) {
      // swallow and fall through to finally
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }


  // Method to handle form submission
  void _handleFormSubmission() {
    if (_selectedSport != null && _selectedBranch != null && _selectedBatch != null && _selectedDate != null) {
      _fetchStudents();
    }
  }

  // Method to toggle a single student's attendance
  void _toggleAttendance(bool? value, int index) {
    if (value == null) return;
    setState(() {
      _students[index].isPresent = value;
      // Update selectAll status
      _selectAll = _students.every((student) => student.isPresent);
    });
  }

  // Method to toggle attendance for all students
  void _toggleSelectAll(bool? value) {
    if (value == null) return;
    setState(() {
      _selectAll = value;
      for (var student in _students) {
        student.isPresent = value;
      }
    });
  }

  // Method to save attendance to backend
  Future<void> _saveAttendance() async {
    if (_selectedDate == null) return;
    final String dateStr = DateFormat('yyyy-MM-dd').format(_selectedDate!);
    int success = 0;
    for (final s in _students) {
      if (s.enrollmentId == 0) continue;
      final payload = {
        'enrollment': s.enrollmentId,
        'date': dateStr,
        'is_present': s.isPresent,
      };
      final resp = await apiClient.post('/organizations/attendance/', payload, includeAuth: true);
      if (resp.statusCode == 201 || resp.statusCode == 200) {
        success += 1;
      }
    }

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Attendance Saved'),
        content: Text('Saved $success/${_students.length} records for $dateStr'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  // Method to show the date picker
  Future<void> _selectDate(BuildContext context) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate ?? DateTime.now(),
      firstDate: DateTime(2000),
      lastDate: DateTime(2101),
    );
    if (picked != null && picked != _selectedDate) {
      setState(() {
        _selectedDate = picked;
        _dateController.text = DateFormat('yyyy-MM-dd').format(picked);
        _students = []; // Clear students when the date changes
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    // Read preselected params if provided
    final args = ModalRoute.of(context)?.settings.arguments;
    if (args is Map && _selectedBatch == null && _selectedBranch == null && _selectedSport == null) {
      final int? branchId = args['branchId'] as int?;
      final int? sportId = args['sportId'] as int?;
      final int? batchId = args['batchId'] as int?;
      final String? branchName = args['branchName'] as String?;
      final String? sportName = args['sportName'] as String?;
      final String? batchName = args['batchName'] as String?;
      if (branchId != null) {
        _selectedBranch = branchId.toString();
        _selectedBranchName = branchName;
        _fetchBatches(_selectedBranch!);
      }
      if (sportId != null) {
        // we only store sport name in dropdown; keep id string to display later
        _selectedSport = sportId.toString();
        _selectedSportName = sportName;
      }
      if (batchId != null) {
        _selectedBatch = batchId.toString();
        _selectedBatchName = batchName;
      }
    }
    final bool isPrefilled = _selectedSport != null && _selectedBranch != null && _selectedBatch != null;
    final bool isFormComplete = isPrefilled && _selectedDate != null;

    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Take or Update Attendance',
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
                  // Header section

                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                    decoration: const BoxDecoration(
                      color: Color(0xFF006C62),
                      borderRadius: BorderRadius.only(
                        topLeft: Radius.circular(12.0),
                        topRight: Radius.circular(12.0),
                      ),
                    ),
                    child: const Text(
                      'Take or Update Attendance',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),

                  // Form content section
                  Padding(
                    padding: const EdgeInsets.all(20.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Sports (hidden if prefilled)
                        if (!isPrefilled)
                          _DropdownInput(
                            label: 'Sport',
                            hint: 'Select Sport',
                            icon: Icons.sports,
                            items: (_sports).map<String>((s) => s['name'] as String).toList(),
                            onChanged: (value) {
                              setState(() {
                                _selectedSport = value;
                                _students = [];
                              });
                            },
                          )
                        else
                          Padding(
                            padding: const EdgeInsets.only(bottom: 12.0),
                            child: Row(
                              children: [
                                const Icon(Icons.sports),
                                const SizedBox(width: 8),
                                Text(_selectedSportName ?? 'Sport')
                              ],
                            ),
                          ),

                        // Branch, Batch, and Attendance Dates
                        if (!isPrefilled)
                          _DropdownInput(
                            label: 'Branch',
                            hint: 'Select Branch',
                            icon: Icons.school,
                            items: (_branches).map<String>((b) => b['id'].toString()).toList(),
                            onChanged: (value) async {
                              setState(() {
                                _selectedBranch = value;
                                _selectedBatch = null;
                                _batches = [];
                                _students = [];
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

                        // Batch Dropdown  (dynamic)
                        if (!isPrefilled)
                          _DropdownInput(
                            label: 'Batch',
                            hint: 'Select Batch',
                            icon: Icons.group_work,
                            items: (_batches).map<String>((b) => b['id'].toString()).toList(),
                            onChanged: (value) {
                              setState(() {
                                _selectedBatch = value;
                                _students = [];
                              });
                            },
                          )
                        else
                          Padding(
                            padding: const EdgeInsets.only(bottom: 12.0),
                            child: Row(
                              children: [
                                const Icon(Icons.group_work),
                                const SizedBox(width: 8),
                                Text(_selectedBatchName ?? 'Batch')
                              ],
                            ),
                          ),
                        const SizedBox(height: 20),

                        // Date Picker
                        _DateInput(
                          label: 'Attendance Date',
                          hint: 'Select Date',
                          icon: Icons.calendar_today,
                          controller: _dateController,
                          onTap: () => _selectDate(context),
                        ),

                        // Fetch Students Button
                        GestureDetector(
                          onTap: isFormComplete ? _handleFormSubmission : null,
                          child: Container(
                            width: double.infinity,
                            padding: const EdgeInsets.all(16.0),
                            decoration: BoxDecoration(
                              color: isFormComplete ? const Color(0xFF006C62) : Colors.grey,
                              borderRadius: BorderRadius.circular(8.0),
                            ),
                            child: const Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(Icons.search, color: Colors.white),
                                SizedBox(width: 8),
                                Text(
                                  'Fetch Students',
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

                        const SizedBox(height: 20),

                        // Display table if data is loaded
                        if (_isLoading)
                          const Center(child: CircularProgressIndicator())
                        else if (_students.isNotEmpty)
                          SingleChildScrollView(
                            scrollDirection: Axis.horizontal,
                            child: ConstrainedBox(
                              constraints: const BoxConstraints(minWidth: 600),
                              child: _buildAttendanceTable(),
                            ),
                          ),

                        // Adding some space at the bottom to prevent overflow
                        const SizedBox(height: 20),
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

  // Widget to build the attendance table and buttons
  Widget _buildAttendanceTable() {
    return Column(
      children: [
        // Select All Checkbox
        Row(
          mainAxisAlignment: MainAxisAlignment.end,
          children: [
            const Text(
              'Select All',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            Checkbox(
              value: _selectAll,
              onChanged: _toggleSelectAll,
            ),
          ],
        ),

        // Attendance Data Table
        DataTable(
            columns: const [
              DataColumn(label: Text('Sr. No.')),
              DataColumn(label: Text('Present')),
              DataColumn(label: Text('Student Name')),
            ],
            rows: _students.asMap().entries.map((entry) {
              final index = entry.key;
              final student = entry.value;
              return DataRow(
                cells: [
                  DataCell(Text('${index + 1}')),
                  DataCell(
                    Checkbox(
                      value: student.isPresent,
                      onChanged: (value) => _toggleAttendance(value, index),
                    ),
                  ),
                  DataCell(Text(student.name)),
                ],
              );
            }).toList(),
          ),

        const SizedBox(height: 20),

        // Save Attendance Button (avoid infinite width inside horizontal scroller)
        Align(
          alignment: Alignment.centerRight,
          child: ElevatedButton(
            onPressed: _saveAttendance,
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF006C62),
              padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 20),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8.0),
              ),
            ),
            child: const Text(
              'Save Attendance',
              style: TextStyle(
                color: Colors.white,
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ),
      ],
    );
  }
}

// Reusable widget for dropdown inputs
class _DropdownInput extends StatelessWidget {
  final String label;
  final String hint;
  final IconData icon;
  final List<String> items;
  final void Function(String?) onChanged;

  const _DropdownInput({
    required this.label,
    required this.hint,
    required this.icon,
    required this.items,
    required this.onChanged,
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
            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          ),
          items: items.map((String value) {
            return DropdownMenuItem<String>(
              value: value,
              child: Text(value),
            );
          }).toList(),
          onChanged: onChanged,
        ),
      ],
    );
  }
}

// Reusable widget for date input
class _DateInput extends StatelessWidget {
  final String label;
  final String hint;
  final IconData icon;
  final TextEditingController controller;
  final void Function() onTap;

  const _DateInput({
    required this.label,
    required this.hint,
    required this.icon,
    required this.controller,
    required this.onTap,
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
        TextFormField(
          controller: controller,
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
            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          ),
          readOnly: true,
          onTap: onTap,
        ),
      ],
    );
  }
}
