import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:sportsverse_app/api/api_client.dart';
import 'package:sportsverse_app/models/batch.dart';
import 'package:sportsverse_app/theme/elite_theme.dart';

class BatchEnrollmentsScreen extends StatefulWidget {
  final Batch batch;

  const BatchEnrollmentsScreen({super.key, required this.batch});

  @override
  State<BatchEnrollmentsScreen> createState() => _BatchEnrollmentsScreenState();
}

class _BatchEnrollmentsScreenState extends State<BatchEnrollmentsScreen> {
  List<dynamic> _enrollments = [];
  bool _isLoading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadEnrollments();
  }

  Future<void> _loadEnrollments() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final response = await apiClient.get(
        '/api/organizations/enrollments/?batch=${widget.batch.id}',
      );
      if (response.statusCode == 200) {
        setState(() {
          _enrollments = jsonDecode(response.body);
          _isLoading = false;
        });
      } else {
        setState(() {
          _error = 'Failed to load enrollments';
          _isLoading = false;
        });
      }
    } catch (e) {
      setState(() {
        _error = e.toString();
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = EliteTheme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: Text('Enrollments — ${widget.batch.name}'),
        backgroundColor: theme.primary,
        foregroundColor: theme.surfaceContainerLowest,
      ),
      body: _isLoading
          ? Center(child: CircularProgressIndicator(color: theme.primary))
          : _error != null
              ? Center(child: Text(_error!, style: theme.body))
              : _enrollments.isEmpty
                  ? Center(
                      child: Text(
                        'No enrollments in this batch',
                        style: theme.body.copyWith(color: theme.secondaryText),
                      ),
                    )
                  : RefreshIndicator(
                      onRefresh: _loadEnrollments,
                      child: ListView.separated(
                        padding: const EdgeInsets.all(16),
                        itemCount: _enrollments.length,
                        separatorBuilder: (_, __) => const SizedBox(height: 8),
                        itemBuilder: (context, index) {
                          final e = _enrollments[index];
                          final isActive = e['is_active'] == true;
                          final studentName =
                              e['student_name'] ?? e['student']?['first_name'] ?? 'Student';
                          final lastName = e['student_last_name'] ?? '';
                          final enrollmentType = e['enrollment_type'] ?? 'N/A';
                          final sessionsAttended = e['sessions_attended'] ?? 0;
                          final totalSessions = e['total_sessions'];
                          final dateEnrolled = e['date_enrolled']?.toString().split('T').first ?? '';

                          return Card(
                            child: ListTile(
                              leading: CircleAvatar(
                                backgroundColor: isActive ? theme.accent : Colors.grey,
                                child: Icon(
                                  Icons.person,
                                  color: theme.primary,
                                ),
                              ),
                              title: Text('$studentName $lastName'.trim()),
                              subtitle: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text('Type: $enrollmentType'),
                                  if (totalSessions != null)
                                    Text('Sessions: $sessionsAttended / $totalSessions'),
                                  if (dateEnrolled.isNotEmpty)
                                    Text('Enrolled: $dateEnrolled'),
                                ],
                              ),
                              trailing: Chip(
                                label: Text(
                                  isActive ? 'ACTIVE' : 'INACTIVE',
                                  style: TextStyle(
                                    color: isActive ? Colors.green.shade800 : Colors.red.shade800,
                                    fontSize: 11,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                backgroundColor:
                                    isActive ? Colors.green.shade50 : Colors.red.shade50,
                              ),
                            ),
                          );
                        },
                      ),
                    ),
    );
  }
}
