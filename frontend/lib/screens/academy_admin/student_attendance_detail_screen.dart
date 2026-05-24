import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:sportsverse_app/api/api_client.dart';

class StudentAttendanceDetailScreen extends StatefulWidget {
  final int studentId;
  final String studentName;
  final String? batchId;

  const StudentAttendanceDetailScreen({
    super.key,
    required this.studentId,
    required this.studentName,
    this.batchId,
  });

  @override
  State<StudentAttendanceDetailScreen> createState() =>
      _StudentAttendanceDetailScreenState();
}

class _StudentAttendanceDetailScreenState
    extends State<StudentAttendanceDetailScreen> {
  String _selectedPeriod = 'month';
  DateTime? _customStart;
  DateTime? _customEnd;
  List<dynamic> _records = [];
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _loadAttendance();
  }

  (DateTime, DateTime) _dateRangeForPeriod() {
    final now = DateTime.now();
    switch (_selectedPeriod) {
      case 'quarter':
        final quarterStartMonth = ((now.month - 1) ~/ 3) * 3 + 1;
        final start = DateTime(now.year, quarterStartMonth, 1);
        final end = DateTime(now.year, quarterStartMonth + 2 + 1, 0);
        return (start, end);
      case 'year':
        return (DateTime(now.year, 1, 1), DateTime(now.year, 12, 31));
      case 'custom':
        return (
          _customStart ?? DateTime(now.year, now.month, 1),
          _customEnd ?? now,
        );
      case 'month':
      default:
        return (DateTime(now.year, now.month, 1), DateTime(now.year, now.month + 1, 0));
    }
  }

  String _fmt(DateTime d) =>
      '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

  Future<void> _pickCustomRange() async {
    final start = await showDatePicker(
      context: context,
      initialDate: _customStart ?? DateTime.now(),
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
    );
    if (start == null || !mounted) return;

    final end = await showDatePicker(
      context: context,
      initialDate: _customEnd ?? DateTime.now(),
      firstDate: start,
      lastDate: DateTime.now(),
    );
    if (end == null || !mounted) return;

    setState(() {
      _selectedPeriod = 'custom';
      _customStart = start;
      _customEnd = end;
    });
    await _loadAttendance();
  }

  Future<void> _loadAttendance() async {
    setState(() => _isLoading = true);
    final (start, end) = _dateRangeForPeriod();

    try {
      var url =
          '/api/organizations/attendance/?student=${widget.studentId}&start_date=${_fmt(start)}&end_date=${_fmt(end)}';
      if (widget.batchId != null) {
        url += '&batch=${widget.batchId}';
      }

      final response = await apiClient.get(url);
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        setState(() {
          _records = data is List ? data : (data['results'] ?? []);
          _isLoading = false;
        });
      } else {
        setState(() => _isLoading = false);
      }
    } catch (_) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.studentName),
        backgroundColor: const Color(0xFF006C62),
        foregroundColor: Colors.white,
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                DropdownButtonFormField<String>(
                  value: _selectedPeriod,
                  decoration: const InputDecoration(
                    labelText: 'Date Range',
                    border: OutlineInputBorder(),
                  ),
                  items: const [
                    DropdownMenuItem(value: 'month', child: Text('This Month')),
                    DropdownMenuItem(value: 'quarter', child: Text('This Quarter')),
                    DropdownMenuItem(value: 'year', child: Text('This Year')),
                    DropdownMenuItem(value: 'custom', child: Text('Custom Range')),
                  ],
                  onChanged: (val) async {
                    if (val == null) return;
                    if (val == 'custom') {
                      await _pickCustomRange();
                    } else {
                      setState(() => _selectedPeriod = val);
                      await _loadAttendance();
                    }
                  },
                ),
                if (_selectedPeriod == 'custom' &&
                    _customStart != null &&
                    _customEnd != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 8),
                    child: Text(
                      '${_fmt(_customStart!)} to ${_fmt(_customEnd!)}',
                      style: const TextStyle(color: Colors.grey),
                    ),
                  ),
              ],
            ),
          ),
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _records.isEmpty
                    ? const Center(child: Text('No attendance records in this period'))
                    : ListView.builder(
                        itemCount: _records.length,
                        itemBuilder: (context, index) {
                          final r = _records[index];
                          final date = (r['date'] ?? '').toString().split('T').first;
                          return Card(
                            margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                            child: ListTile(
                              leading: const Icon(Icons.check_circle, color: Colors.green),
                              title: Text(date),
                              subtitle: Text(
                                '${r['batch_name'] ?? 'Batch'} • Marked by ${r['marked_by_name'] ?? 'Admin'}',
                              ),
                              trailing: const Text(
                                'Present',
                                style: TextStyle(
                                  color: Colors.green,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          );
                        },
                      ),
          ),
        ],
      ),
    );
  }
}
