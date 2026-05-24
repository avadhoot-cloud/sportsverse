import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:sportsverse_app/api/api_client.dart';
import 'package:sportsverse_app/api/batch_api.dart';
import 'package:sportsverse_app/models/batch.dart';

class AssignInactiveStudentsScreen extends StatefulWidget {
  const AssignInactiveStudentsScreen({super.key});

  @override
  State<AssignInactiveStudentsScreen> createState() =>
      _AssignInactiveStudentsScreenState();
}

class _AssignInactiveStudentsScreenState extends State<AssignInactiveStudentsScreen> {
  List<dynamic> _inactiveEnrollments = [];
  List<Batch> _batches = [];
  bool _isLoading = true;
  bool _isSubmitting = false;

  int? _selectedStudentId;
  String? _selectedStudentName;
  int? _selectedBatchId;
  String _enrollmentType = 'SESSION_BASED';
  final TextEditingController _totalSessionsController = TextEditingController(text: '10');

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    try {
      final enrollmentsRes = await apiClient.get('/api/organizations/enrollments/');
      final batches = await batchApi.getBatches();
      if (enrollmentsRes.statusCode == 200) {
        final all = jsonDecode(enrollmentsRes.body) as List<dynamic>;
        final inactive = all.where((e) {
          return e['is_active'] == false || e['enrollment_status'] == 'Completed';
        }).toList();

        final Map<int, dynamic> byStudent = {};
        for (final e in inactive) {
          final studentId = e['student'] as int;
          byStudent[studentId] = e;
        }

        final studentsRes = await apiClient.get('/api/accounts/students/');
        if (studentsRes.statusCode == 200) {
          final students = jsonDecode(studentsRes.body) as List<dynamic>;
          for (final s in students.where((s) => s['is_active'] == false)) {
            final sid = s['id'] as int;
            if (!byStudent.containsKey(sid)) {
              byStudent[sid] = {
                'id': sid,
                'student': sid,
                'student_name': s['student_name'],
                'student_last_name': s['student_last_name'],
                'batch_name': s['batch_name'] ?? 'No active batch',
                'is_active': false,
              };
            }
          }
        }

        setState(() {
          _inactiveEnrollments = byStudent.values.toList();
          _batches = batches.where((b) => b.isActive).toList();
          _isLoading = false;
        });
      } else {
        setState(() => _isLoading = false);
      }
    } catch (_) {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _assignToBatch() async {
    if (_selectedStudentId == null || _selectedBatchId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Select a student and target batch')),
      );
      return;
    }

    setState(() => _isSubmitting = true);
    try {
      final payload = {
        'student': _selectedStudentId,
        'batch': _selectedBatchId,
        'enrollment_type': _enrollmentType,
        'is_active': true,
      };
      if (_enrollmentType == 'SESSION_BASED') {
        payload['total_sessions'] = int.tryParse(_totalSessionsController.text.trim()) ?? 10;
      }

      final response = await apiClient.post(
        '/api/organizations/enrollments/',
        payload,
      );

      if (response.statusCode == 201) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Student reassigned to batch successfully'),
              backgroundColor: Colors.green,
            ),
          );
          setState(() {
            _selectedStudentId = null;
            _selectedStudentName = null;
            _selectedBatchId = null;
          });
          await _loadData();
        }
      } else if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: ${response.body}')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  @override
  void dispose() {
    _totalSessionsController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Assign Inactive Students'),
        backgroundColor: const Color(0xFF00796B),
        foregroundColor: Colors.white,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Select an inactive enrollment and assign the student to a new batch.',
                    style: TextStyle(color: Colors.grey),
                  ),
                  const SizedBox(height: 20),
                  DropdownButtonFormField<int>(
                    isExpanded: true,
                    decoration: const InputDecoration(
                      labelText: 'Inactive Student',
                      border: OutlineInputBorder(),
                    ),
                    value: _inactiveEnrollments.any((e) => e['student'] == _selectedStudentId)
                        ? _selectedStudentId
                        : null,
                    items: _inactiveEnrollments.map<DropdownMenuItem<int>>((e) {
                      final name =
                          '${e['student_name'] ?? ''} ${e['student_last_name'] ?? ''}'.trim();
                      final batchName = e['batch_name'] ?? 'Unknown batch';
                      final label = name.isEmpty
                          ? 'Student #${e['student']}'
                          : '$name (was: $batchName)';
                      return DropdownMenuItem<int>(
                        value: e['student'] as int,
                        child: Text(label, overflow: TextOverflow.ellipsis),
                      );
                    }).toList(),
                    onChanged: (val) {
                      if (val == null) return;
                      final enrollment =
                          _inactiveEnrollments.firstWhere((e) => e['student'] == val);
                      setState(() {
                        _selectedStudentId = val;
                        _selectedStudentName =
                            '${enrollment['student_name'] ?? ''} ${enrollment['student_last_name'] ?? ''}'.trim();
                      });
                    },
                  ),
                  const SizedBox(height: 16),
                  DropdownButtonFormField<int>(
                    isExpanded: true,
                    decoration: const InputDecoration(
                      labelText: 'Target Batch',
                      border: OutlineInputBorder(),
                    ),
                    value: _selectedBatchId,
                    items: _batches.map<DropdownMenuItem<int>>((b) {
                      return DropdownMenuItem<int>(
                        value: b.id,
                        child: Text(b.name, overflow: TextOverflow.ellipsis),
                      );
                    }).toList(),
                    onChanged: (val) => setState(() => _selectedBatchId = val),
                  ),
                  const SizedBox(height: 16),
                  DropdownButtonFormField<String>(
                    isExpanded: true,
                    decoration: const InputDecoration(
                      labelText: 'Enrollment Type',
                      border: OutlineInputBorder(),
                    ),
                    value: _enrollmentType,
                    items: const [
                      DropdownMenuItem(value: 'SESSION_BASED', child: Text('Session Based')),
                      DropdownMenuItem(value: 'DURATION_BASED', child: Text('Duration Based')),
                    ],
                    onChanged: (val) => setState(() => _enrollmentType = val ?? 'SESSION_BASED'),
                  ),
                  if (_enrollmentType == 'SESSION_BASED') ...[
                    const SizedBox(height: 16),
                    TextField(
                      controller: _totalSessionsController,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(
                        labelText: 'Total Sessions',
                        border: OutlineInputBorder(),
                      ),
                    ),
                  ],
                  const SizedBox(height: 24),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: _isSubmitting ? null : _assignToBatch,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF00796B),
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                      ),
                      child: _isSubmitting
                          ? const SizedBox(
                              height: 20,
                              width: 20,
                              child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                            )
                          : Text(
                              _selectedStudentName != null
                                  ? 'Assign $_selectedStudentName to Batch'
                                  : 'Assign to Batch',
                              overflow: TextOverflow.ellipsis,
                              textAlign: TextAlign.center,
                            ),
                    ),
                  ),
                  if (_inactiveEnrollments.isEmpty) ...[
                    const SizedBox(height: 24),
                    const Center(child: Text('No inactive enrollments found')),
                  ],
                ],
              ),
            ),
    );
  }
}
