// lib/screens/coach/coach_attendance_screen.dart
//
// Coach picks a batch, picks a date, sees the student roster, toggles
// present/absent, then submits. Session deduction happens automatically
// on the backend via Attendance.save().

import 'package:flutter/material.dart';
import 'package:sportsverse_app/api/coach_api.dart';

import 'package:sportsverse_app/theme/elite_theme.dart';
import 'package:sportsverse_app/widgets/elite_card.dart';
import 'package:sportsverse_app/widgets/glass_header.dart';
import 'package:sportsverse_app/widgets/elite_button.dart';

class CoachAttendanceScreen extends StatefulWidget {
  const CoachAttendanceScreen({super.key});

  @override
  State<CoachAttendanceScreen> createState() => _CoachAttendanceScreenState();
}

class _CoachAttendanceScreenState extends State<CoachAttendanceScreen> {
  // Step 1: load all students grouped by batch
  late Future<List<CoachStudent>> _studentFuture;

  // Selected batch
  int? _selectedBatchId;
  Map<int, List<CoachStudent>> _byBatch = {}; // batchId → students
  List<int> _batchIds = [];
  List<String> _batchNames = [];

  // Step 2: attendance state
  DateTime _selectedDate = DateTime.now();
  Map<int, bool> _presence = {}; // enrollmentId → present

  bool _submitting = false;

  @override
  void initState() {
    super.initState();
    _studentFuture = coachApi.getCoachStudents();
  }

  void _onStudentsLoaded(List<CoachStudent> students) {
    final map = <int, List<CoachStudent>>{};
    for (final s in students) {
      map.putIfAbsent(s.batchId, () => []).add(s);
    }
    _byBatch = map;
    _batchIds = map.keys.toList();
    final first = students;
    _batchNames = _batchIds.map((id) => first.firstWhere((s) => s.batchId == id).batchName).toList();

    if (_batchIds.isNotEmpty && _selectedBatchId == null) {
      _selectedBatchId = _batchIds.first;
      _initPresence();
    }
  }

  void _initPresence() {
    final students = _byBatch[_selectedBatchId] ?? [];
    _presence = {for (final s in students) s.enrollmentId: true};
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime.now().subtract(const Duration(days: 7)),
      lastDate: DateTime.now(),
      builder: (context, child) {
        final theme = EliteTheme.of(context);
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
    if (picked != null) setState(() => _selectedDate = picked);
  }

  Future<void> _submit() async {
    if (_selectedBatchId == null) return;

    final dateStr =
        '${_selectedDate.year}-${_selectedDate.month.toString().padLeft(2, '0')}-${_selectedDate.day.toString().padLeft(2, '0')}';
    final records = _presence.entries
        .map((e) => {'enrollment_id': e.key, 'present': e.value})
        .toList();

    setState(() => _submitting = true);
    try {
      final result = await coachApi.markAttendance(
        batchId: _selectedBatchId!,
        date: dateStr,
        records: records,
      );
      if (!mounted) return;
      final created = result['created'] ?? 0;
      final skipped = result['skipped_duplicates'] ?? 0;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('✅ Attendance saved: $created marked, $skipped duplicates skipped'),
          backgroundColor: EliteTheme.of(context).accent,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: $e'), backgroundColor: EliteTheme.of(context).error),
      );
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = EliteTheme.of(context);

    return Scaffold(
      backgroundColor: theme.surface,
      appBar: const GlassHeader(title: 'Take Attendance'),
      body: FutureBuilder<List<CoachStudent>>(
        future: _studentFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return Center(child: CircularProgressIndicator(color: theme.primary));
          }
          if (snapshot.hasError) {
            return Center(
              child: Text('Error: ${snapshot.error}', style: theme.body.copyWith(color: theme.error)),
            );
          }
          final students = snapshot.data ?? [];
          if (students.isEmpty) {
            return Center(child: Text('No students found in your batches.', style: theme.body));
          }
          if (_byBatch.isEmpty) {
            _onStudentsLoaded(students);
          }

          final batchStudents = _byBatch[_selectedBatchId] ?? [];

          return Column(
            children: [
              // ── Controls bar ─────────────────────────────────────────────
              EliteCard(
                margin: const EdgeInsets.all(16),
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text("Select Batch", style: theme.caption.copyWith(color: theme.secondaryText)),
                    const SizedBox(height: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                      decoration: BoxDecoration(
                        border: Border.all(color: theme.surfaceContainer),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: DropdownButtonHideUnderline(
                        child: DropdownButton<int>(
                          isExpanded: true,
                          value: _selectedBatchId,
                          icon: Icon(Icons.keyboard_arrow_down, color: theme.primary),
                          items: _batchIds.asMap().entries.map((e) {
                            return DropdownMenuItem<int>(
                              value: e.value,
                              child: Text(_batchNames[e.key], style: theme.body),
                            );
                          }).toList(),
                          onChanged: (id) {
                            setState(() {
                              _selectedBatchId = id;
                              _initPresence();
                            });
                          },
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    Text("Date", style: theme.caption.copyWith(color: theme.secondaryText)),
                    const SizedBox(height: 8),
                    InkWell(
                      onTap: _pickDate,
                      borderRadius: BorderRadius.circular(12),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                        decoration: BoxDecoration(
                          border: Border.all(color: theme.surfaceContainer),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Row(
                          children: [
                            Icon(Icons.calendar_today, size: 18, color: theme.primary),
                            const SizedBox(width: 12),
                            Text(
                              '${_selectedDate.day}/${_selectedDate.month}/${_selectedDate.year}',
                              style: theme.body,
                            ),
                            const Spacer(),
                            Icon(Icons.edit, size: 16, color: theme.secondaryText),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              // ── Mark all row ─────────────────────────────────────────────
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text('${batchStudents.length} Students',
                        style: theme.subtitle),
                    TextButton(
                      onPressed: () => setState(() {
                        final allPresent = _presence.values.every((v) => v);
                        for (final key in _presence.keys) {
                          _presence[key] = !allPresent;
                        }
                      }),
                      style: TextButton.styleFrom(
                        foregroundColor: theme.accent, // Lime
                      ),
                      child: Text('Toggle All', style: theme.body.copyWith(fontWeight: FontWeight.bold, color: theme.primary)),
                    ),
                  ],
                ),
              ),

              // ── Student list ─────────────────────────────────────────────
              Expanded(
                child: ListView.builder(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  itemCount: batchStudents.length,
                  itemBuilder: (context, index) {
                    final s = batchStudents[index];
                    final isPresent = _presence[s.enrollmentId] ?? true;
                    
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: EliteCard(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                        child: Row(
                          children: [
                            CircleAvatar(
                              radius: 24,
                              backgroundColor: isPresent
                                  ? theme.accent.withOpacity(0.2) // Lime background
                                  : theme.errorBackground,
                              child: Text(
                                s.displayName.isNotEmpty
                                    ? s.displayName[0].toUpperCase()
                                    : '?',
                                style: theme.heading.copyWith(
                                  color: isPresent ? theme.primary : theme.error,
                                ),
                              ),
                            ),
                            const SizedBox(width: 16),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(s.displayName, style: theme.subtitle),
                                  const SizedBox(height: 2),
                                  Text('@${s.username}',
                                      style: theme.caption.copyWith(color: theme.secondaryText)),
                                ],
                              ),
                            ),
                            // Present / Absent toggle
                            GestureDetector(
                              onTap: () => setState(() {
                                _presence[s.enrollmentId] = !isPresent;
                              }),
                              child: AnimatedContainer(
                                duration: const Duration(milliseconds: 200),
                                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                                decoration: BoxDecoration(
                                  color: isPresent ? theme.primary : theme.errorBackground,
                                  borderRadius: BorderRadius.circular(20),
                                ),
                                child: Text(
                                  isPresent ? 'Present' : 'Absent',
                                  style: theme.caption.copyWith(
                                    color: isPresent ? theme.surfaceContainerLowest : theme.error,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
              ),

              // ── Submit button ─────────────────────────────────────────────
              Padding(
                padding: const EdgeInsets.all(24),
                child: EliteButton(
                  text: 'Submit Attendance',
                  onPressed: _submitting ? () {} : _submit,
                  isLoading: _submitting,
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}
