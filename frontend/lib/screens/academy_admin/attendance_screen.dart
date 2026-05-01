import 'package:flutter/material.dart';
import 'dart:convert';
import 'package:sportsverse_app/api/api_client.dart';
import 'package:sportsverse_app/api/branch_api.dart';
import 'package:sportsverse_app/api/auth_api.dart';
import 'package:sportsverse_app/api/batch_api.dart';

import 'package:sportsverse_app/theme/elite_theme.dart';
import 'package:sportsverse_app/widgets/elite_card.dart';
import 'package:sportsverse_app/widgets/glass_header.dart';

class AttendanceScreen extends StatefulWidget {
  const AttendanceScreen({super.key});

  @override
  State<AttendanceScreen> createState() => _AttendanceScreenState();
}

class _AttendanceScreenState extends State<AttendanceScreen> {
  // State variables for dropdowns
  String? _selectedBranch;
  String? _selectedSport;
  String? _selectedBatch;
  String? _selectedBranchName;
  String? _selectedSportName;
  String? _selectedBatchName;
  
  // Lists for dropdown options
  List<dynamic> _branches = [];
  List<dynamic> _sports = [];
  List<dynamic> _batches = [];
  
  // Loading states
  bool _loadingBranches = true;
  bool _loadingSports = true;
  bool _loadingBatches = false;
  String? _error;
  
  @override
  void initState() {
    super.initState();
    _fetchBranches();
    _fetchSports();
  }
  
  Future<void> _fetchBranches() async {
    setState(() {
      _loadingBranches = true;
      _error = null;
    });
    
    try {
      final response = await apiClient.get('/api/organizations/branches/');
      if (response.statusCode == 200) {
        setState(() {
          _branches = jsonDecode(response.body);
          _loadingBranches = false;
        });
      } else {
        setState(() {
          _error = 'Failed to load branches';
          _loadingBranches = false;
        });
      }
    } catch (e) {
      setState(() {
        _error = e.toString();
        _loadingBranches = false;
      });
    }
  }
  
  Future<void> _fetchSports() async {
    setState(() {
      _loadingSports = true;
      _error = null;
    });
    
    try {
      final sports = await authApi.getSports();
      setState(() {
        _sports = sports;
        _loadingSports = false;
      });
    } catch (e) {
      setState(() {
        _error = e.toString();
        _loadingSports = false;
      });
    }
  }
  
  Future<void> _fetchBatches() async {
    if (_selectedBranch == null || _selectedSport == null) return;
    
    setState(() {
      _loadingBatches = true;
      _error = null;
    });
    
    try {
      final batches = await batchApi.getBatches();
      setState(() {
        _batches = batches
            .where((b) => 
                b.branchId.toString() == _selectedBranch && 
                b.sportId.toString() == _selectedSport)
            .toList();
        _loadingBatches = false;
      });
    } catch (e) {
      setState(() {
        _error = e.toString();
        _loadingBatches = false;
      });
    }
  }
  
  void _navigateToTakeAttendance() {
    if (_validateSelections()) {
      Navigator.pushNamed(
        context, 
        '/attendance/take',
        arguments: {
          'branchId': _selectedBranch,
          'branchName': _selectedBranchName,
          'sportId': _selectedSport,
          'sportName': _selectedSportName,
          'batchId': _selectedBatch,
          'batchName': _selectedBatchName,
        },
      );
    }
  }
  
  void _navigateToViewAttendance() {
    if (_validateSelections()) {
      Navigator.pushNamed(
        context, 
        '/attendance/view',
        arguments: {
          'branchId': _selectedBranch,
          'branchName': _selectedBranchName,
          'sportId': _selectedSport,
          'sportName': _selectedSportName,
          'batchId': _selectedBatch,
          'batchName': _selectedBatchName,
        },
      );
    }
  }
  
  bool _validateSelections() {
    if (_selectedBranch == null) {
      _showErrorSnackBar('Please select a branch');
      return false;
    }
    if (_selectedSport == null) {
      _showErrorSnackBar('Please select a sport');
      return false;
    }
    if (_selectedBatch == null) {
      _showErrorSnackBar('Please select a batch');
      return false;
    }
    return true;
  }
  
  void _showErrorSnackBar(String message) {
    Future.microtask(() {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(message),
          backgroundColor: EliteTheme.of(context).error,
        ),
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = EliteTheme.of(context);
    final bool isLoading = _loadingBranches || _loadingSports || _loadingBatches;
    final bool hasError = _error != null;
    final bool hasSelections = _selectedBranch != null && 
                              _selectedSport != null && 
                              _selectedBatch != null;
    
    return Scaffold(
      backgroundColor: theme.surface,
      appBar: const GlassHeader(title: 'Attendance Management'),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (hasError)
              Container(
                padding: const EdgeInsets.all(16),
                margin: const EdgeInsets.only(bottom: 24),
                decoration: BoxDecoration(
                  color: theme.errorBackground,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: theme.error.withOpacity(0.3)),
                ),
                child: Row(
                  children: [
                    Icon(Icons.error_outline, color: theme.error),
                    const SizedBox(width: 12),
                    Expanded(child: Text(_error!, style: theme.body.copyWith(color: theme.error))),
                  ],
                ),
              ),
            
            if (isLoading)
              Center(
                child: Padding(
                  padding: const EdgeInsets.all(32.0),
                  child: CircularProgressIndicator(color: theme.primary),
                ),
              ),
            
            if (!isLoading) ...[              
              _DropdownInput(
                theme: theme,
                label: 'Branch',
                hint: 'Select Branch',
                icon: Icons.apartment,
                items: _branches.map<DropdownMenuItem<String>>((branch) {
                  return DropdownMenuItem<String>(
                    value: branch['id'].toString(),
                    child: Text(branch['name'], style: theme.body),
                    onTap: () {
                      setState(() {
                        _selectedBranchName = branch['name'];
                      });
                    },
                  );
                }).toList(),
                value: _selectedBranch,
                onChanged: (value) {
                  setState(() {
                    _selectedBranch = value;
                    _selectedBatch = null;
                    _batches = [];
                  });
                  if (_selectedSport != null) {
                    _fetchBatches();
                  }
                },
              ),
              const SizedBox(height: 20),
              
              _DropdownInput(
                theme: theme,
                label: 'Sport',
                hint: 'Select Sport',
                icon: Icons.sports,
                items: _sports.map<DropdownMenuItem<String>>((sport) {
                  return DropdownMenuItem<String>(
                    value: sport.id.toString(),
                    child: Text(sport.name, style: theme.body),
                    onTap: () {
                      setState(() {
                        _selectedSportName = sport.name;
                      });
                    },
                  );
                }).toList(),
                value: _selectedSport,
                onChanged: (value) {
                  setState(() {
                    _selectedSport = value;
                    _selectedBatch = null;
                    _batches = [];
                  });
                  if (_selectedBranch != null) {
                    _fetchBatches();
                  }
                },
              ),
              const SizedBox(height: 20),
              
              _DropdownInput(
                theme: theme,
                label: 'Batch',
                hint: 'Select Batch',
                icon: Icons.group,
                items: _batches.map<DropdownMenuItem<String>>((batch) {
                  return DropdownMenuItem<String>(
                    value: batch.id.toString(),
                    child: Text(batch.name, style: theme.body),
                    onTap: () {
                      setState(() {
                        _selectedBatchName = batch.name;
                      });
                    },
                  );
                }).toList(),
                value: _selectedBatch,
                onChanged: (value) {
                  setState(() {
                    _selectedBatch = value;
                  });
                },
              ),
              const SizedBox(height: 40),
              
              if (hasSelections) ...[                
                GridView.count(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  crossAxisCount: 2,
                  crossAxisSpacing: 16,
                  mainAxisSpacing: 16,
                  childAspectRatio: 0.9,
                  children: [
                    _ActionCard(
                      theme: theme,
                      title: 'Take Attendance',
                      subtitle: 'Mark student attendance',
                      icon: Icons.fact_check,
                      color: theme.primary,
                      onTap: _navigateToTakeAttendance,
                    ),
                    
                    _ActionCard(
                      theme: theme,
                      title: 'View Attendance',
                      subtitle: 'Check attendance records',
                      icon: Icons.insights,
                      color: theme.accent, // Lime
                      onTap: _navigateToViewAttendance,
                    ),
                  ],
                ),
              ],
            ],
          ],
        ),
      ),
    );
  }
}

class _DropdownInput extends StatelessWidget {
  final EliteTheme theme;
  final String label;
  final String hint;
  final IconData icon;
  final List<DropdownMenuItem<String>> items;
  final String? value;
  final Function(String?) onChanged;

  const _DropdownInput({
    required this.theme,
    required this.label,
    required this.hint,
    required this.icon,
    required this.items,
    required this.onChanged,
    this.value,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: theme.subtitle,
        ),
        const SizedBox(height: 8),
        DropdownButtonFormField<String>(
          decoration: InputDecoration(
            prefixIcon: Icon(icon, color: theme.primary),
            hintText: hint,
            hintStyle: theme.body.copyWith(color: theme.secondaryText),
            filled: true,
            fillColor: theme.surfaceContainerLowest,
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
              borderSide: BorderSide(color: theme.primary),
            ),
            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
          ),
          icon: Icon(Icons.keyboard_arrow_down, color: theme.primary),
          value: value,
          items: items,
          onChanged: onChanged,
          isExpanded: true,
          dropdownColor: theme.surfaceContainerLowest,
        ),
      ],
    );
  }
}

class _ActionCard extends StatelessWidget {
  final EliteTheme theme;
  final String title;
  final String subtitle;
  final IconData icon;
  final Color color;
  final VoidCallback onTap;

  const _ActionCard({
    required this.theme,
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return EliteCard(
      onTap: onTap,
      padding: const EdgeInsets.all(20),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: color.withOpacity(0.1),
              borderRadius: BorderRadius.circular(16)
            ),
            child: Icon(icon, size: 32, color: color)
          ),
          const SizedBox(height: 16),
          Text(
            title,
            style: theme.subtitle,
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 6),
          Text(
            subtitle,
            style: theme.caption.copyWith(color: theme.secondaryText),
            textAlign: TextAlign.center,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }
}