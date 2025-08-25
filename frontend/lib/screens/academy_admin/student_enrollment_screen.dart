// sportsverse/frontend/sportsverse_app/lib/screens/academy_admin/student_enrollment_screen.dart

import 'package:flutter/material.dart';
import 'package:sportsverse_app/api/batch_api.dart';
import 'package:sportsverse_app/models/batch.dart';

class StudentEnrollmentScreen extends StatefulWidget {
  const StudentEnrollmentScreen({super.key});

  @override
  State<StudentEnrollmentScreen> createState() =>
      _StudentEnrollmentScreenState();
}

class _StudentEnrollmentScreenState extends State<StudentEnrollmentScreen> {
  List<Batch> batches = [];
  List<Enrollment> enrollments = [];
  bool isLoading = true;
  String? errorMessage;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() {
      isLoading = true;
      errorMessage = null;
    });

    try {
      final loadedBatches = await batchApi.getBatches();
      final loadedEnrollments = await batchApi.getEnrollments();

      setState(() {
        batches = loadedBatches.where((batch) => batch.isActive).toList();
        enrollments = loadedEnrollments;
        isLoading = false;
      });
    } catch (e) {
      setState(() {
        errorMessage = e.toString();
        isLoading = false;
      });
    }
  }

  void _showEnrollmentDialog([Enrollment? enrollment]) async {
    final result = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (context) =>
          StudentEnrollmentDialog(batches: batches, enrollment: enrollment),
    );

    if (result != null) {
      try {
        setState(() {
          isLoading = true;
        });

        if (enrollment != null) {
          // Update existing enrollment
          await batchApi.updateEnrollment(
            enrollmentId: enrollment.id,
            studentId: result['studentId'],
            batchId: result['batchId'],
            enrollmentType: result['enrollmentType'],
            startDate: result['startDate'],
            endDate: result['endDate'],
            totalSessions: result['totalSessions'],
            isActive: result['isActive'],
          );
        } else {
          // Create new enrollment
          await batchApi.enrollStudent(
            studentId: result['studentId'],
            batchId: result['batchId'],
            enrollmentType: result['enrollmentType'],
            startDate: result['startDate'],
            endDate: result['endDate'],
            totalSessions: result['totalSessions'],
          );
        }

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              enrollment != null
                  ? 'Enrollment updated successfully'
                  : 'Student enrolled successfully',
            ),
            backgroundColor: Colors.green,
          ),
        );

        _loadData();
      } catch (e) {
        setState(() {
          isLoading = false;
        });

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Failed to ${enrollment != null ? 'update' : 'create'} enrollment: ${e.toString()}',
            ),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _deleteEnrollment(Enrollment enrollment) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Enrollment'),
        content: Text(
          'Are you sure you want to delete enrollment for ${enrollment.fullStudentName} in ${enrollment.batchName}?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      try {
        await batchApi.deleteEnrollment(enrollment.id);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Enrollment deleted successfully')),
        );
        _loadData();
      } catch (e) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to delete enrollment: ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Student Enrollments'),
        backgroundColor: Colors.blue,
        foregroundColor: Colors.white,
      ),
      body: isLoading
          ? const Center(child: CircularProgressIndicator())
          : errorMessage != null
          ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    'Error: $errorMessage',
                    style: const TextStyle(color: Colors.red),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 16),
                  ElevatedButton(
                    onPressed: _loadData,
                    child: const Text('Retry'),
                  ),
                ],
              ),
            )
          : enrollments.isEmpty
          ? const Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.school, size: 64, color: Colors.grey),
                  SizedBox(height: 16),
                  Text(
                    'No enrollments found',
                    style: TextStyle(fontSize: 18, color: Colors.grey),
                  ),
                  SizedBox(height: 8),
                  Text(
                    'Enroll students in batches to get started',
                    style: TextStyle(color: Colors.grey),
                  ),
                ],
              ),
            )
          : RefreshIndicator(
              onRefresh: _loadData,
              child: ListView.builder(
                padding: const EdgeInsets.all(16),
                itemCount: enrollments.length,
                itemBuilder: (context, index) {
                  final enrollment = enrollments[index];
                  return Card(
                    margin: const EdgeInsets.only(bottom: 12),
                    child: ListTile(
                      leading: CircleAvatar(
                        backgroundColor: enrollment.isActive
                            ? Colors.green
                            : Colors.grey,
                        child: Icon(
                          enrollment.isActive
                              ? Icons.school
                              : Icons.school_outlined,
                          color: Colors.white,
                        ),
                      ),
                      title: Text(
                        enrollment.fullStudentName,
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                      subtitle: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Batch: ${enrollment.batchName}${enrollment.branchName != null ? ' (${enrollment.branchName})' : ''}',
                          ),
                          Text('Type: ${enrollment.enrollmentTypeDisplay}'),
                          Text(
                            'Progress: ${enrollment.progressDisplay ?? 'N/A'}',
                          ),
                          if (enrollment.enrollmentStarted &&
                              enrollment.startDate != null)
                            Text(
                              'Started: ${enrollment.startDate!.day}/${enrollment.startDate!.month}/${enrollment.startDate!.year}',
                            )
                          else
                            Text(
                              'Enrolled: ${enrollment.dateEnrolled.day}/${enrollment.dateEnrolled.month}/${enrollment.dateEnrolled.year}',
                            ),
                          const SizedBox(height: 4),
                          Text(
                            enrollment.enrollmentStatus ??
                                (enrollment.isActive ? 'Active' : 'Inactive'),
                            style: TextStyle(
                              color:
                                  enrollment.enrollmentStarted &&
                                      enrollment.isActive
                                  ? Colors.green
                                  : Colors.grey,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                      trailing: PopupMenuButton<String>(
                        onSelected: (value) {
                          switch (value) {
                            case 'edit':
                              _showEnrollmentDialog(enrollment);
                              break;
                            case 'delete':
                              _deleteEnrollment(enrollment);
                              break;
                          }
                        },
                        itemBuilder: (context) => [
                          const PopupMenuItem(
                            value: 'edit',
                            child: Row(
                              children: [
                                Icon(Icons.edit, color: Colors.blue),
                                SizedBox(width: 8),
                                Text('Edit'),
                              ],
                            ),
                          ),
                          const PopupMenuItem(
                            value: 'delete',
                            child: Row(
                              children: [
                                Icon(Icons.delete, color: Colors.red),
                                SizedBox(width: 8),
                                Text('Delete'),
                              ],
                            ),
                          ),
                        ],
                      ),
                      onTap: () => _showEnrollmentDialog(enrollment),
                    ),
                  );
                },
              ),
            ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _showEnrollmentDialog(),
        backgroundColor: Colors.blue,
        child: const Icon(Icons.add, color: Colors.white),
      ),
    );
  }
}

class StudentEnrollmentDialog extends StatefulWidget {
  final List<Batch> batches;
  final Enrollment? enrollment;

  const StudentEnrollmentDialog({
    super.key,
    required this.batches,
    this.enrollment,
  });

  @override
  State<StudentEnrollmentDialog> createState() =>
      _StudentEnrollmentDialogState();
}

class _StudentEnrollmentDialogState extends State<StudentEnrollmentDialog> {
  final _formKey = GlobalKey<FormState>();
  final _studentIdController = TextEditingController();
  final _totalSessionsController = TextEditingController();

  Batch? _selectedBatch;
  String _enrollmentType = 'SESSION_BASED';
  DateTime _startDate = DateTime.now();
  DateTime? _endDate;
  bool _isActive = true;

  bool get isEditing => widget.enrollment != null;

  @override
  void initState() {
    super.initState();
    if (isEditing) {
      _populateFields();
    }
  }

  void _populateFields() {
    if (widget.enrollment != null) {
      final enrollment = widget.enrollment!;
      _studentIdController.text = enrollment.studentId.toString();
      _enrollmentType = enrollment.enrollmentType;
      _startDate = enrollment.startDate ?? DateTime.now();
      _endDate = enrollment.endDate;
      _isActive = enrollment.isActive;

      if (enrollment.totalSessions != null) {
        _totalSessionsController.text = enrollment.totalSessions.toString();
      }

      _selectedBatch = widget.batches.firstWhere(
        (batch) => batch.id == enrollment.batchId,
        orElse: () => widget.batches.first,
      );
    }
  }

  @override
  void dispose() {
    _studentIdController.dispose();
    _totalSessionsController.dispose();
    super.dispose();
  }

  Future<void> _selectDate(BuildContext context, bool isStartDate) async {
    final initialDate = isStartDate ? _startDate : (_endDate ?? DateTime.now());
    final picked = await showDatePicker(
      context: context,
      initialDate: initialDate,
      firstDate: DateTime(2020),
      lastDate: DateTime(2030),
    );

    if (picked != null) {
      setState(() {
        if (isStartDate) {
          _startDate = picked;
        } else {
          _endDate = picked;
        }
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(isEditing ? 'Edit Enrollment' : 'Enroll Student'),
      content: SizedBox(
        width: double.maxFinite,
        child: Form(
          key: _formKey,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextFormField(
                  controller: _studentIdController,
                  decoration: const InputDecoration(
                    labelText: 'Student ID *',
                    hintText: 'Enter student ID',
                    prefixIcon: Icon(Icons.person),
                  ),
                  keyboardType: TextInputType.number,
                  validator: (value) {
                    if (value == null || value.trim().isEmpty) {
                      return 'Student ID is required';
                    }
                    if (int.tryParse(value) == null) {
                      return 'Please enter a valid student ID';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 16),
                DropdownButtonFormField<Batch>(
                  value: _selectedBatch,
                  decoration: const InputDecoration(
                    labelText: 'Batch *',
                    prefixIcon: Icon(Icons.batch_prediction),
                  ),
                  items: widget.batches.map((batch) {
                    return DropdownMenuItem(
                      value: batch,
                      child: Text('${batch.name} (${batch.branchName})'),
                    );
                  }).toList(),
                  onChanged: (value) {
                    setState(() {
                      _selectedBatch = value;
                    });
                  },
                  validator: (value) {
                    if (value == null) {
                      return 'Please select a batch';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 16),
                DropdownButtonFormField<String>(
                  value: _enrollmentType,
                  decoration: const InputDecoration(
                    labelText: 'Enrollment Type *',
                    prefixIcon: Icon(Icons.category),
                  ),
                  items: const [
                    DropdownMenuItem(
                      value: 'SESSION_BASED',
                      child: Text('Session Based'),
                    ),
                    DropdownMenuItem(
                      value: 'DURATION_BASED',
                      child: Text('Duration Based'),
                    ),
                  ],
                  onChanged: (value) {
                    setState(() {
                      _enrollmentType = value!;
                    });
                  },
                ),
                const SizedBox(height: 16),
                ListTile(
                  title: const Text('Start Date'),
                  subtitle: Text(
                    '${_startDate.day}/${_startDate.month}/${_startDate.year}',
                  ),
                  trailing: const Icon(Icons.calendar_today),
                  onTap: () => _selectDate(context, true),
                ),
                if (_enrollmentType == 'DURATION_BASED')
                  ListTile(
                    title: const Text('End Date'),
                    subtitle: Text(
                      _endDate != null
                          ? '${_endDate!.day}/${_endDate!.month}/${_endDate!.year}'
                          : 'Select end date',
                    ),
                    trailing: const Icon(Icons.calendar_today),
                    onTap: () => _selectDate(context, false),
                  ),
                if (_enrollmentType == 'SESSION_BASED')
                  TextFormField(
                    controller: _totalSessionsController,
                    decoration: const InputDecoration(
                      labelText: 'Total Sessions *',
                      hintText: '20',
                      prefixIcon: Icon(Icons.numbers),
                    ),
                    keyboardType: TextInputType.number,
                    validator: (value) {
                      if (_enrollmentType == 'SESSION_BASED' &&
                          (value == null || value.trim().isEmpty)) {
                        return 'Total sessions is required for session-based enrollment';
                      }
                      if (value != null &&
                          value.isNotEmpty &&
                          int.tryParse(value) == null) {
                        return 'Please enter a valid number';
                      }
                      return null;
                    },
                  ),
                const SizedBox(height: 16),
                SwitchListTile(
                  title: const Text('Active'),
                  subtitle: Text(
                    _isActive
                        ? 'Enrollment is active'
                        : 'Enrollment is inactive',
                  ),
                  value: _isActive,
                  onChanged: (value) {
                    setState(() {
                      _isActive = value;
                    });
                  },
                ),
              ],
            ),
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        ElevatedButton(
          onPressed: () {
            if (_formKey.currentState!.validate()) {
              final result = {
                'studentId': int.parse(_studentIdController.text),
                'batchId': _selectedBatch!.id,
                'enrollmentType': _enrollmentType,
                'startDate': _startDate,
                'endDate': _endDate,
                'totalSessions': _totalSessionsController.text.isNotEmpty
                    ? int.parse(_totalSessionsController.text)
                    : null,
                'isActive': _isActive,
              };
              Navigator.pop(context, result);
            }
          },
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.blue,
            foregroundColor: Colors.white,
          ),
          child: Text(isEditing ? 'Update' : 'Enroll'),
        ),
      ],
    );
  }
}
