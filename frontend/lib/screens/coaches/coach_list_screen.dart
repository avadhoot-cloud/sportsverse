import 'package:flutter/material.dart';
import 'package:sportsverse_app/api/api_client.dart';
import 'dart:convert';
import 'coach_enroll_screen.dart';

class CoachListScreen extends StatefulWidget {
  const CoachListScreen({super.key});

  @override
  State<CoachListScreen> createState() => _CoachListScreenState();
}

class _CoachListScreenState extends State<CoachListScreen> {
  List<dynamic> _coaches = [];
  bool _isLoading = true;
  String? _error;
  int? _expandedCoachId;

  @override
  void initState() {
    super.initState();
    _fetchCoaches();
  }

  Future<void> _fetchCoaches() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final response = await apiClient.get('/api/coaches/list/');
      if (response.statusCode == 200) {
        setState(() {
          _coaches = jsonDecode(response.body);
          _isLoading = false;
        });
      } else {
        setState(() {
          _error = 'Failed to load coaches (${response.statusCode})';
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

  Future<void> _removeAssignment(int assignmentId) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Remove assignment?'),
        content: const Text('This coach will be unassigned from the batch.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          TextButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Remove')),
        ],
      ),
    );
    if (confirmed != true) return;

    final response = await apiClient.delete('/api/coaches/assignments/$assignmentId/');
    if (response.statusCode == 200 || response.statusCode == 204) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Assignment removed'), backgroundColor: Colors.green),
        );
        _fetchCoaches();
      }
    } else if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed: ${response.body}')),
      );
    }
  }

  void _toggleCoach(int coachId) {
    setState(() {
      _expandedCoachId = _expandedCoachId == coachId ? null : coachId;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Enrolled Coaches"), backgroundColor: Colors.teal),
      floatingActionButton: FloatingActionButton(
        onPressed: () async {
          await Navigator.push(
            context,
            MaterialPageRoute(builder: (context) => const CoachEnrollScreen()),
          );
          _fetchCoaches();
        },
        child: const Icon(Icons.add),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(_error!),
                      const SizedBox(height: 12),
                      ElevatedButton(onPressed: _fetchCoaches, child: const Text('Retry')),
                    ],
                  ),
                )
              : _coaches.isEmpty
                  ? const Center(child: Text('No coaches enrolled yet'))
                  : RefreshIndicator(
                      onRefresh: _fetchCoaches,
                      child: ListView.builder(
                        itemCount: _coaches.length,
                        itemBuilder: (context, index) {
                          final coach = _coaches[index];
                          final coachId = coach['id'] as int;
                          final assignments = (coach['assignments'] as List<dynamic>?) ?? [];
                          final isExpanded = _expandedCoachId == coachId;

                          return Card(
                            margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                            child: Column(
                              children: [
                                ListTile(
                                  leading: const CircleAvatar(child: Icon(Icons.person)),
                                  title: Text(coach['full_name'] ?? 'Coach'),
                                  subtitle: Text(coach['email'] ?? ''),
                                  trailing: Icon(
                                    isExpanded ? Icons.expand_less : Icons.expand_more,
                                  ),
                                  onTap: () => _toggleCoach(coachId),
                                ),
                                if (isExpanded) ...[
                                  const Divider(height: 1),
                                  if (assignments.isEmpty)
                                    const Padding(
                                      padding: EdgeInsets.all(16),
                                      child: Text('No batch assignments yet'),
                                    )
                                  else
                                    ...assignments.map((a) {
                                      return ListTile(
                                        dense: true,
                                        title: Text(a['batch_name'] ?? 'Batch'),
                                        subtitle: Text(
                                          '${a['branch_name'] ?? ''} • ${a['sport_name'] ?? ''}',
                                        ),
                                        trailing: IconButton(
                                          icon: const Icon(Icons.delete_outline, color: Colors.red),
                                          onPressed: () => _removeAssignment(a['id'] as int),
                                          tooltip: 'Remove assignment',
                                        ),
                                      );
                                    }),
                                ],
                              ],
                            ),
                          );
                        },
                      ),
                    ),
    );
  }
}
