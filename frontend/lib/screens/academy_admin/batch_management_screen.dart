// sportsverse/frontend/sportsverse_app/lib/screens/academy_admin/batch_management_screen.dart

import 'package:flutter/material.dart';
import 'package:sportsverse_app/api/batch_api.dart';
import 'package:sportsverse_app/api/branch_api.dart';
import 'package:sportsverse_app/api/auth_api.dart';
import 'package:sportsverse_app/models/batch.dart';
import 'package:sportsverse_app/models/branch.dart';
import 'package:sportsverse_app/models/user.dart';

class BatchManagementScreen extends StatefulWidget {
  const BatchManagementScreen({super.key});

  @override
  State<BatchManagementScreen> createState() => _BatchManagementScreenState();
}

class _BatchManagementScreenState extends State<BatchManagementScreen> {
  List<Batch> batches = [];
  bool isLoading = true;
  String? errorMessage;

  @override
  void initState() {
    super.initState();
    _loadBatches();
  }

  Future<void> _loadBatches() async {
    setState(() {
      isLoading = true;
      errorMessage = null;
    });

    try {
      final loadedBatches = await batchApi.getBatches();
      setState(() {
        batches = loadedBatches;
        isLoading = false;
      });
    } catch (e) {
      setState(() {
        errorMessage = e.toString();
        isLoading = false;
      });
    }
  }

  Future<void> _deleteBatch(Batch batch) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Batch'),
        content: Text('Are you sure you want to delete "${batch.name}"?'),
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
        await batchApi.deleteBatch(batch.id);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Batch deleted successfully')),
        );
        _loadBatches();
      } catch (e) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to delete batch: ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  void _navigateToAddEditBatch([Batch? batch]) async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => AddEditBatchScreen(batch: batch)),
    );

    if (result == true) {
      _loadBatches();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Manage Batches'),
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
                    onPressed: _loadBatches,
                    child: const Text('Retry'),
                  ),
                ],
              ),
            )
          : batches.isEmpty
          ? const Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.batch_prediction, size: 64, color: Colors.grey),
                  SizedBox(height: 16),
                  Text(
                    'No batches found',
                    style: TextStyle(fontSize: 18, color: Colors.grey),
                  ),
                  SizedBox(height: 8),
                  Text(
                    'Add your first batch to get started',
                    style: TextStyle(color: Colors.grey),
                  ),
                ],
              ),
            )
          : RefreshIndicator(
              onRefresh: _loadBatches,
              child: ListView.builder(
                padding: const EdgeInsets.all(16),
                itemCount: batches.length,
                itemBuilder: (context, index) {
                  final batch = batches[index];
                  return Card(
                    margin: const EdgeInsets.only(bottom: 12),
                    child: ListTile(
                      leading: CircleAvatar(
                        backgroundColor: batch.isActive
                            ? Colors.blue
                            : Colors.grey,
                        child: Icon(
                          batch.isActive
                              ? Icons.batch_prediction
                              : Icons.batch_prediction_outlined,
                          color: Colors.white,
                        ),
                      ),
                      title: Text(
                        batch.name,
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                      subtitle: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Sport: ${batch.sportName}'),
                          Text('Branch: ${batch.branchName}'),
                          Text('Schedule: ${batch.scheduleDisplay}'),
                          Text('Max Students: ${batch.maxStudents}'),
                          const SizedBox(height: 4),
                          Text(
                            batch.isActive ? 'Active' : 'Inactive',
                            style: TextStyle(
                              color: batch.isActive
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
                              _navigateToAddEditBatch(batch);
                              break;
                            case 'delete':
                              _deleteBatch(batch);
                              break;
                            case 'enrollments':
                              _navigateToEnrollments(batch);
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
                            value: 'enrollments',
                            child: Row(
                              children: [
                                Icon(Icons.people, color: Colors.green),
                                SizedBox(width: 8),
                                Text('View Enrollments'),
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
                      onTap: () => _navigateToAddEditBatch(batch),
                    ),
                  );
                },
              ),
            ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _navigateToAddEditBatch(),
        backgroundColor: Colors.blue,
        child: const Icon(Icons.add, color: Colors.white),
      ),
    );
  }

  void _navigateToEnrollments(Batch batch) {
    // TODO: Implement enrollment management screen
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Enrollments for ${batch.name} - Coming Soon!')),
    );
  }
}

// Add/Edit Batch Screen
class AddEditBatchScreen extends StatefulWidget {
  final Batch? batch;

  const AddEditBatchScreen({super.key, this.batch});

  @override
  State<AddEditBatchScreen> createState() => _AddEditBatchScreenState();
}

class _AddEditBatchScreenState extends State<AddEditBatchScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _maxStudentsController = TextEditingController();

  List<Branch> branches = [];
  List<Sport> sports = [];
  Branch? _selectedBranch;
  Sport? _selectedSport;
  bool _isActive = true;
  bool _isLoading = false;
  bool _dataLoading = true;
  String? _dataError;

  // Schedule fields
  List<String> _selectedDays = [];
  TimeOfDay? _startTime;
  TimeOfDay? _endTime;

  final List<String> _weekDays = [
    'Mon',
    'Tue',
    'Wed',
    'Thu',
    'Fri',
    'Sat',
    'Sun',
  ];

  bool get isEditing => widget.batch != null;

  @override
  void initState() {
    super.initState();
    _loadInitialData();
    if (isEditing) {
      _populateFields();
    }
  }

  Future<void> _loadInitialData() async {
    try {
      // Load branches and sports
      final loadedBranches = await branchApi.getBranches();
      final loadedSports = await authApi.getSports();

      setState(() {
        branches = loadedBranches;
        sports = loadedSports;
        _dataLoading = false;
      });
    } catch (e) {
      setState(() {
        _dataError = e.toString();
        _dataLoading = false;
      });
    }
  }

  void _populateFields() {
    if (widget.batch != null) {
      _nameController.text = widget.batch!.name;
      _maxStudentsController.text = widget.batch!.maxStudents.toString();
      _isActive = widget.batch!.isActive;

      // Find selected branch and sport
      _selectedBranch = branches.firstWhere(
        (branch) => branch.id == widget.batch!.branchId,
        orElse: () => branches.first,
      );
      _selectedSport = sports.firstWhere(
        (sport) => sport.id == widget.batch!.sportId,
        orElse: () => sports.first,
      );

      // Parse schedule
      _selectedDays = widget.batch!.scheduleDays;
      final schedule = widget.batch!.scheduleDetails;
      if (schedule['start_time'] != null) {
        final parts = schedule['start_time'].split(':');
        _startTime = TimeOfDay(
          hour: int.parse(parts[0]),
          minute: int.parse(parts[1]),
        );
      }
      if (schedule['end_time'] != null) {
        final parts = schedule['end_time'].split(':');
        _endTime = TimeOfDay(
          hour: int.parse(parts[0]),
          minute: int.parse(parts[1]),
        );
      }
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _maxStudentsController.dispose();
    super.dispose();
  }

  Future<void> _saveBatch() async {
    if (!_formKey.currentState!.validate()) return;

    if (_selectedBranch == null || _selectedSport == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please select branch and sport'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    if (_selectedDays.isEmpty || _startTime == null || _endTime == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please set complete schedule'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      final scheduleDetails = {
        'days': _selectedDays,
        'start_time':
            '${_startTime!.hour.toString().padLeft(2, '0')}:${_startTime!.minute.toString().padLeft(2, '0')}',
        'end_time':
            '${_endTime!.hour.toString().padLeft(2, '0')}:${_endTime!.minute.toString().padLeft(2, '0')}',
      };

      if (isEditing) {
        await batchApi.updateBatch(
          batchId: widget.batch!.id,
          name: _nameController.text.trim(),
          branchId: _selectedBranch!.id,
          sportId: _selectedSport!.id,
          scheduleDetails: scheduleDetails,
          maxStudents: int.parse(_maxStudentsController.text),
          isActive: _isActive,
        );
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Batch updated successfully')),
          );
        }
      } else {
        await batchApi.createBatch(
          name: _nameController.text.trim(),
          branchId: _selectedBranch!.id,
          sportId: _selectedSport!.id,
          scheduleDetails: scheduleDetails,
          maxStudents: int.parse(_maxStudentsController.text),
          isActive: _isActive,
        );
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Batch created successfully')),
          );
        }
      }

      if (mounted) {
        Navigator.pop(context, true);
      }
    } catch (e) {
      setState(() {
        _isLoading = false;
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(e.toString()), backgroundColor: Colors.red),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_dataLoading) {
      return Scaffold(
        appBar: AppBar(
          title: Text(isEditing ? 'Edit Batch' : 'Add Batch'),
          backgroundColor: Colors.blue,
          foregroundColor: Colors.white,
        ),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    if (_dataError != null) {
      return Scaffold(
        appBar: AppBar(
          title: Text(isEditing ? 'Edit Batch' : 'Add Batch'),
          backgroundColor: Colors.blue,
          foregroundColor: Colors.white,
        ),
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text('Error: $_dataError'),
              ElevatedButton(
                onPressed: _loadInitialData,
                child: const Text('Retry'),
              ),
            ],
          ),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(isEditing ? 'Edit Batch' : 'Add Batch'),
        backgroundColor: Colors.blue,
        foregroundColor: Colors.white,
      ),
      body: Form(
        key: _formKey,
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              TextFormField(
                controller: _nameController,
                decoration: const InputDecoration(
                  labelText: 'Batch Name *',
                  hintText: 'e.g., Morning Cricket Batch',
                  prefixIcon: Icon(Icons.batch_prediction),
                ),
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'Batch name is required';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),
              DropdownButtonFormField<Branch>(
                value: _selectedBranch,
                decoration: const InputDecoration(
                  labelText: 'Branch *',
                  prefixIcon: Icon(Icons.store),
                ),
                items: branches.map((branch) {
                  return DropdownMenuItem(
                    value: branch,
                    child: Text(branch.name),
                  );
                }).toList(),
                onChanged: (value) {
                  setState(() {
                    _selectedBranch = value;
                  });
                },
                validator: (value) {
                  if (value == null) {
                    return 'Please select a branch';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),
              DropdownButtonFormField<Sport>(
                value: _selectedSport,
                decoration: const InputDecoration(
                  labelText: 'Sport *',
                  prefixIcon: Icon(Icons.sports),
                ),
                items: sports.map((sport) {
                  return DropdownMenuItem(
                    value: sport,
                    child: Text(sport.name),
                  );
                }).toList(),
                onChanged: (value) {
                  setState(() {
                    _selectedSport = value;
                  });
                },
                validator: (value) {
                  if (value == null) {
                    return 'Please select a sport';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _maxStudentsController,
                decoration: const InputDecoration(
                  labelText: 'Maximum Students *',
                  hintText: '20',
                  prefixIcon: Icon(Icons.people),
                ),
                keyboardType: TextInputType.number,
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'Maximum students is required';
                  }
                  final number = int.tryParse(value);
                  if (number == null || number < 1) {
                    return 'Please enter a valid number';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 24),
              const Text(
                'Schedule',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 12),
              const Text('Select Days:'),
              Wrap(
                children: _weekDays.map((day) {
                  final isSelected = _selectedDays.contains(day);
                  return Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: FilterChip(
                      label: Text(day),
                      selected: isSelected,
                      onSelected: (selected) {
                        setState(() {
                          if (selected) {
                            _selectedDays.add(day);
                          } else {
                            _selectedDays.remove(day);
                          }
                        });
                      },
                    ),
                  );
                }).toList(),
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: ListTile(
                      title: const Text('Start Time'),
                      subtitle: Text(
                        _startTime != null
                            ? _startTime!.format(context)
                            : 'Select time',
                      ),
                      trailing: const Icon(Icons.access_time),
                      onTap: () async {
                        final time = await showTimePicker(
                          context: context,
                          initialTime: _startTime ?? TimeOfDay.now(),
                        );
                        if (time != null) {
                          setState(() {
                            _startTime = time;
                          });
                        }
                      },
                    ),
                  ),
                  Expanded(
                    child: ListTile(
                      title: const Text('End Time'),
                      subtitle: Text(
                        _endTime != null
                            ? _endTime!.format(context)
                            : 'Select time',
                      ),
                      trailing: const Icon(Icons.access_time),
                      onTap: () async {
                        final time = await showTimePicker(
                          context: context,
                          initialTime: _endTime ?? TimeOfDay.now(),
                        );
                        if (time != null) {
                          setState(() {
                            _endTime = time;
                          });
                        }
                      },
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              SwitchListTile(
                title: const Text('Active Status'),
                subtitle: Text(
                  _isActive ? 'Batch is active' : 'Batch is inactive',
                ),
                value: _isActive,
                onChanged: (value) {
                  setState(() {
                    _isActive = value;
                  });
                },
              ),
              const SizedBox(height: 32),
              ElevatedButton(
                onPressed: _isLoading ? null : _saveBatch,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.blue,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                ),
                child: _isLoading
                    ? const Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              valueColor: AlwaysStoppedAnimation<Color>(
                                Colors.white,
                              ),
                            ),
                          ),
                          SizedBox(width: 12),
                          Text('Saving...'),
                        ],
                      )
                    : Text(isEditing ? 'Update Batch' : 'Create Batch'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
