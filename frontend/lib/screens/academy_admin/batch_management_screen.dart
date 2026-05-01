import 'package:flutter/material.dart';
import 'package:sportsverse_app/api/batch_api.dart';
import 'package:sportsverse_app/api/branch_api.dart';
import 'package:sportsverse_app/api/auth_api.dart';
import 'package:sportsverse_app/models/batch.dart';
import 'package:sportsverse_app/models/branch.dart';
import 'package:sportsverse_app/models/user.dart';

import 'package:sportsverse_app/theme/elite_theme.dart';
import 'package:sportsverse_app/widgets/elite_card.dart';
import 'package:sportsverse_app/widgets/glass_header.dart';
import 'package:sportsverse_app/widgets/elite_button.dart';

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
    final theme = EliteTheme.of(context);
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: theme.surfaceContainerLowest,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text('Delete Batch', style: theme.heading),
        content: Text('Are you sure you want to delete "${batch.name}"?', style: theme.body),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text('Cancel', style: theme.body),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(backgroundColor: theme.error),
            child: Text('Delete', style: theme.body.copyWith(color: theme.surfaceContainerLowest, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      try {
        await batchApi.deleteBatch(batch.id);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: const Text('Batch deleted successfully'), backgroundColor: theme.primary),
          );
          _loadBatches();
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Failed to delete batch: ${e.toString()}'),
              backgroundColor: theme.error,
            ),
          );
        }
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
    final theme = EliteTheme.of(context);

    return Scaffold(
      backgroundColor: theme.surface,
      appBar: const GlassHeader(title: 'Manage Batches'),
      body: isLoading
          ? Center(child: CircularProgressIndicator(color: theme.primary))
          : errorMessage != null
          ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    'Error: $errorMessage',
                    style: theme.body.copyWith(color: theme.error),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 16),
                  ElevatedButton(
                    onPressed: _loadBatches,
                    style: ElevatedButton.styleFrom(backgroundColor: theme.primary),
                    child: Text('Retry', style: theme.body.copyWith(color: theme.surfaceContainerLowest)),
                  ),
                ],
              ),
            )
          : batches.isEmpty
          ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.batch_prediction, size: 64, color: theme.secondaryText),
                  const SizedBox(height: 16),
                  Text(
                    'No batches found',
                    style: theme.display2.copyWith(color: theme.secondaryText),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Add your first batch to get started',
                    style: theme.body.copyWith(color: theme.secondaryText),
                  ),
                ],
              ),
            )
          : RefreshIndicator(
              color: theme.primary,
              onRefresh: _loadBatches,
              child: ListView.builder(
                padding: const EdgeInsets.all(24),
                itemCount: batches.length,
                itemBuilder: (context, index) {
                  final batch = batches[index];
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 16),
                    child: EliteCard(
                      onTap: () => _navigateToAddEditBatch(batch),
                      padding: EdgeInsets.zero,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                            decoration: BoxDecoration(
                              color: theme.primary,
                              borderRadius: const BorderRadius.only(topLeft: Radius.circular(20), topRight: Radius.circular(20))
                            ),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Row(
                                  children: [
                                    Icon(Icons.groups, color: theme.surfaceContainerLowest, size: 24),
                                    const SizedBox(width: 12),
                                    Text(batch.name, style: theme.heading.copyWith(color: theme.surfaceContainerLowest)),
                                  ]
                                ),
                                PopupMenuButton<String>(
                                  icon: Icon(Icons.more_vert, color: theme.surfaceContainerLowest),
                                  color: theme.surfaceContainerLowest,
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
                                    PopupMenuItem(
                                      value: 'edit',
                                      child: Row(
                                        children: [
                                          Icon(Icons.edit, color: theme.primary),
                                          const SizedBox(width: 8),
                                          Text('Edit', style: theme.body),
                                        ],
                                      ),
                                    ),
                                    PopupMenuItem(
                                      value: 'enrollments',
                                      child: Row(
                                        children: [
                                          Icon(Icons.people, color: theme.accent),
                                          const SizedBox(width: 8),
                                          Text('View Enrollments', style: theme.body),
                                        ],
                                      ),
                                    ),
                                    PopupMenuItem(
                                      value: 'delete',
                                      child: Row(
                                        children: [
                                          Icon(Icons.delete, color: theme.error),
                                          const SizedBox(width: 8),
                                          Text('Delete', style: theme.body),
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                          Padding(
                            padding: const EdgeInsets.all(20),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                _buildInfoRow(theme, Icons.sports, 'Sport', batch.sportName),
                                const SizedBox(height: 8),
                                _buildInfoRow(theme, Icons.apartment, 'Branch', batch.branchName),
                                const SizedBox(height: 8),
                                _buildInfoRow(theme, Icons.schedule, 'Schedule', batch.scheduleDisplay),
                                const SizedBox(height: 8),
                                _buildInfoRow(theme, Icons.group_add, 'Max Students', '${batch.maxStudents}'),
                              ],
                            ),
                          )
                        ],
                      )
                    ),
                  );
                },
              ),
            ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _navigateToAddEditBatch(),
        backgroundColor: theme.accent, // Lime!
        child: Icon(Icons.add, color: theme.primary),
      ),
    );
  }

  Widget _buildInfoRow(EliteTheme theme, IconData icon, String label, String value) {
    return Row(
      children: [
        Icon(icon, size: 16, color: theme.secondaryText),
        const SizedBox(width: 8),
        Text('$label: ', style: theme.caption.copyWith(color: theme.secondaryText)),
        Expanded(child: Text(value, style: theme.body.copyWith(fontWeight: FontWeight.bold))),
      ]
    );
  }

  void _navigateToEnrollments(Batch batch) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Enrollments for ${batch.name} - Coming Soon!'),
        backgroundColor: EliteTheme.of(context).primary
      ),
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
  final _feeController = TextEditingController();

  String? _selectedPaymentPolicy = 'POST_PAID'; // Default value

  List<Branch> branches = [];
  List<Sport> sports = [];
  Branch? _selectedBranch;
  Sport? _selectedSport;

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

      // Only populate once data is available to avoid empty list errors
      if (isEditing) {
        _populateFields();
      }
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
      _feeController.text = widget.batch!.feePerSession?.toString() ?? '';
      _selectedPaymentPolicy = widget.batch!.paymentPolicy;

      // Find selected branch and sport
      if (branches.isNotEmpty) {
        _selectedBranch = branches.firstWhere(
          (branch) => branch.id == widget.batch!.branchId,
          orElse: () => branches.first,
        );
      }
      if (sports.isNotEmpty) {
        _selectedSport = sports.firstWhere(
          (sport) => sport.id == widget.batch!.sportId,
          orElse: () => sports.first,
        );
      }

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
    _feeController.dispose();
    super.dispose();
  }

  Future<void> _saveBatch() async {
    if (!_formKey.currentState!.validate()) return;

    if (_selectedBranch == null || _selectedSport == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Please select branch and sport'),
          backgroundColor: EliteTheme.of(context).error,
        ),
      );
      return;
    }

    if (_selectedDays.isEmpty || _startTime == null || _endTime == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Please set complete schedule'),
          backgroundColor: EliteTheme.of(context).error,
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
          isActive: widget.batch!.isActive,
          feePerSession: double.parse(_feeController.text),
          paymentPolicy: _selectedPaymentPolicy!,
        );
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: const Text('Batch updated successfully'), backgroundColor: EliteTheme.of(context).primary),
          );
        }
      } else {
        await batchApi.createBatch(
          name: _nameController.text.trim(),
          branchId: _selectedBranch!.id,
          sportId: _selectedSport!.id,
          scheduleDetails: scheduleDetails,
          maxStudents: int.parse(_maxStudentsController.text),
          isActive: true,
          feePerSession: double.parse(_feeController.text),
          paymentPolicy: _selectedPaymentPolicy!,
        );
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: const Text('Batch created successfully'), backgroundColor: EliteTheme.of(context).primary),
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
          SnackBar(content: Text(e.toString()), backgroundColor: EliteTheme.of(context).error),
        );
      }
    }
  }

  InputDecoration _buildInputDecoration(EliteTheme theme, String label, String hint, IconData icon) {
    return InputDecoration(
      labelText: label,
      hintText: hint,
      prefixIcon: Icon(icon, color: theme.primary),
      filled: true,
      fillColor: theme.surfaceContainerLowest,
      labelStyle: theme.body.copyWith(color: theme.secondaryText),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: theme.surfaceContainer),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: theme.surfaceContainer),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: theme.primary, width: 2),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: theme.error),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = EliteTheme.of(context);

    if (_dataLoading) {
      return Scaffold(
        backgroundColor: theme.surface,
        appBar: GlassHeader(title: isEditing ? 'Edit Batch' : 'Add Batch'),
        body: Center(child: CircularProgressIndicator(color: theme.primary)),
      );
    }

    if (_dataError != null) {
      return Scaffold(
        backgroundColor: theme.surface,
        appBar: GlassHeader(title: isEditing ? 'Edit Batch' : 'Add Batch'),
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text('Error: $_dataError', style: theme.body.copyWith(color: theme.error)),
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: _loadInitialData,
                style: ElevatedButton.styleFrom(backgroundColor: theme.primary),
                child: Text('Retry', style: theme.body.copyWith(color: theme.surfaceContainerLowest)),
              ),
            ],
          ),
        ),
      );
    }

    return Scaffold(
      backgroundColor: theme.surface,
      appBar: GlassHeader(title: isEditing ? 'Edit Batch' : 'Add Batch'),
      body: Form(
        key: _formKey,
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              TextFormField(
                controller: _nameController,
                style: theme.body,
                decoration: _buildInputDecoration(theme, 'Batch Name *', 'e.g., Morning Cricket Batch', Icons.batch_prediction),
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'Batch name is required';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 20),
              DropdownButtonFormField<Branch>(
                value: _selectedBranch,
                dropdownColor: theme.surfaceContainerLowest,
                style: theme.body,
                icon: Icon(Icons.keyboard_arrow_down, color: theme.primary),
                decoration: _buildInputDecoration(theme, 'Branch *', '', Icons.store),
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
              const SizedBox(height: 20),
              DropdownButtonFormField<Sport>(
                value: _selectedSport,
                dropdownColor: theme.surfaceContainerLowest,
                style: theme.body,
                icon: Icon(Icons.keyboard_arrow_down, color: theme.primary),
                decoration: _buildInputDecoration(theme, 'Sport *', '', Icons.sports),
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
              const SizedBox(height: 20),
              TextFormField(
                controller: _maxStudentsController,
                style: theme.body,
                decoration: _buildInputDecoration(theme, 'Maximum Students *', '20', Icons.people),
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
              const SizedBox(height: 20),
              TextFormField(
                controller: _feeController,
                style: theme.body,
                decoration: _buildInputDecoration(theme, 'Fee Per Session', 'e.g., 500', Icons.attach_money),
                keyboardType: TextInputType.number,
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'Fee per session is required';
                  }
                  final number = double.tryParse(value);
                  if (number == null || number < 0) {
                    return 'Please enter a valid fee';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 20),
              DropdownButtonFormField<String>(
                value: _selectedPaymentPolicy,
                dropdownColor: theme.surfaceContainerLowest,
                style: theme.body,
                icon: Icon(Icons.keyboard_arrow_down, color: theme.primary),
                decoration: _buildInputDecoration(theme, 'Payment Policy', '', Icons.payment),
                items: ['PRE_PAID', 'POST_PAID'].map((policy) {
                  return DropdownMenuItem(
                    value: policy,
                    child: Text(policy == 'PRE_PAID' ? 'Pre-paid' : 'Post-paid'),
                  );
                }).toList(),
                onChanged: (value) {
                  setState(() {
                    _selectedPaymentPolicy = value;
                  });
                },
                validator: (value) {
                  if (value == null) {
                    return 'Please select a payment policy';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 32),
              Text(
                'Schedule',
                style: theme.display2,
              ),
              const SizedBox(height: 16),
              Text('Select Days:', style: theme.caption.copyWith(color: theme.secondaryText)),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: _weekDays.map((day) {
                  final isSelected = _selectedDays.contains(day);
                  return FilterChip(
                    label: Text(day, style: theme.body.copyWith(
                      color: isSelected ? theme.primary : theme.text,
                      fontWeight: isSelected ? FontWeight.bold : FontWeight.normal
                    )),
                    selected: isSelected,
                    selectedColor: theme.accent, // Lime
                    backgroundColor: theme.surfaceContainerLowest,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                      side: BorderSide(color: isSelected ? theme.accent : theme.surfaceContainer),
                    ),
                    onSelected: (selected) {
                      setState(() {
                        if (selected) {
                          _selectedDays.add(day);
                        } else {
                          _selectedDays.remove(day);
                        }
                      });
                    },
                  );
                }).toList(),
              ),
              const SizedBox(height: 24),
              Row(
                children: [
                  Expanded(
                    child: EliteCard(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                      onTap: () async {
                        final time = await showTimePicker(
                          context: context,
                          initialTime: _startTime ?? TimeOfDay.now(),
                          builder: (context, child) {
                            return Theme(
                              data: Theme.of(context).copyWith(
                                colorScheme: ColorScheme.light(
                                  primary: theme.primary,
                                  onPrimary: theme.surfaceContainerLowest,
                                  onSurface: theme.text,
                                ),
                              ),
                              child: child!,
                            );
                          },
                        );
                        if (time != null) {
                          setState(() {
                            _startTime = time;
                          });
                        }
                      },
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Icon(Icons.access_time, size: 16, color: theme.secondaryText),
                              const SizedBox(width: 8),
                              Text('Start Time', style: theme.caption.copyWith(color: theme.secondaryText)),
                            ],
                          ),
                          const SizedBox(height: 8),
                          Text(
                            _startTime != null ? _startTime!.format(context) : 'Select time',
                            style: theme.subtitle.copyWith(
                              color: _startTime != null ? theme.primary : theme.secondaryText
                            )
                          )
                        ]
                      ),
                    )
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: EliteCard(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                      onTap: () async {
                        final time = await showTimePicker(
                          context: context,
                          initialTime: _endTime ?? TimeOfDay.now(),
                          builder: (context, child) {
                            return Theme(
                              data: Theme.of(context).copyWith(
                                colorScheme: ColorScheme.light(
                                  primary: theme.primary,
                                  onPrimary: theme.surfaceContainerLowest,
                                  onSurface: theme.text,
                                ),
                              ),
                              child: child!,
                            );
                          },
                        );
                        if (time != null) {
                          setState(() {
                            _endTime = time;
                          });
                        }
                      },
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Icon(Icons.access_time, size: 16, color: theme.secondaryText),
                              const SizedBox(width: 8),
                              Text('End Time', style: theme.caption.copyWith(color: theme.secondaryText)),
                            ],
                          ),
                          const SizedBox(height: 8),
                          Text(
                            _endTime != null ? _endTime!.format(context) : 'Select time',
                            style: theme.subtitle.copyWith(
                              color: _endTime != null ? theme.primary : theme.secondaryText
                            )
                          )
                        ]
                      ),
                    )
                  ),
                ],
              ),
              const SizedBox(height: 40),
              EliteButton(
                text: isEditing ? 'Update Batch' : 'Create Batch',
                onPressed: _isLoading ? () {} : _saveBatch,
                isLoading: _isLoading,
              ),
              const SizedBox(height: 40),
            ],
          ),
        ),
      ),
    );
  }
}
