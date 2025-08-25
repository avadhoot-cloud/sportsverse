// sportsverse/frontend/sportsverse_app/lib/screens/academy_admin/coach_assignment_screen.dart

import 'package:flutter/material.dart';
import 'package:sportsverse_app/api/coach_api.dart';
import 'package:sportsverse_app/api/branch_api.dart';
import 'package:sportsverse_app/models/branch.dart';

class CoachAssignmentScreen extends StatefulWidget {
  const CoachAssignmentScreen({super.key});

  @override
  State<CoachAssignmentScreen> createState() => _CoachAssignmentScreenState();
}

class _CoachAssignmentScreenState extends State<CoachAssignmentScreen> {
  List<Coach> coaches = [];
  List<Branch> branches = [];
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
      final loadedCoaches = await coachApi.getCoaches();
      final loadedBranches = await branchApi.getBranches();

      setState(() {
        coaches = loadedCoaches;
        branches = loadedBranches;
        isLoading = false;
      });
    } catch (e) {
      setState(() {
        errorMessage = e.toString();
        isLoading = false;
      });
    }
  }

  void _assignBranches(Coach coach) async {
    final selectedBranches = List<int>.from(coach.assignedBranches);

    final result = await showDialog<List<int>>(
      context: context,
      builder: (context) => BranchAssignmentDialog(
        coachName: coach.coachName,
        branches: branches,
        selectedBranchIds: selectedBranches,
      ),
    );

    if (result != null) {
      try {
        setState(() {
          isLoading = true;
        });

        await coachApi.assignBranches(coachId: coach.id, branchIds: result);

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Branches assigned to ${coach.coachName} successfully',
            ),
            backgroundColor: Colors.green,
          ),
        );

        _loadData(); // Refresh the data
      } catch (e) {
        setState(() {
          isLoading = false;
        });

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to assign branches: ${e.toString()}'),
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
        title: const Text('Coach Branch Assignment'),
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
          : coaches.isEmpty
          ? const Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.person_add, size: 64, color: Colors.grey),
                  SizedBox(height: 16),
                  Text(
                    'No coaches found',
                    style: TextStyle(fontSize: 18, color: Colors.grey),
                  ),
                  SizedBox(height: 8),
                  Text(
                    'Register coaches first to assign them to branches',
                    style: TextStyle(color: Colors.grey),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            )
          : RefreshIndicator(
              onRefresh: _loadData,
              child: ListView.builder(
                padding: const EdgeInsets.all(16),
                itemCount: coaches.length,
                itemBuilder: (context, index) {
                  final coach = coaches[index];
                  return Card(
                    margin: const EdgeInsets.only(bottom: 12),
                    child: ListTile(
                      leading: const CircleAvatar(
                        backgroundColor: Colors.blue,
                        child: Icon(Icons.person, color: Colors.white),
                      ),
                      title: Text(
                        coach.coachName,
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                      subtitle: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const SizedBox(height: 4),
                          if (coach.assignedBranchNames.isEmpty)
                            const Text(
                              'No branches assigned',
                              style: TextStyle(
                                color: Colors.grey,
                                fontStyle: FontStyle.italic,
                              ),
                            )
                          else
                            Wrap(
                              children: coach.assignedBranchNames.map((
                                branchName,
                              ) {
                                return Container(
                                  margin: const EdgeInsets.only(
                                    right: 4,
                                    bottom: 4,
                                  ),
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 8,
                                    vertical: 2,
                                  ),
                                  decoration: BoxDecoration(
                                    color: Colors.blue.shade100,
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: Text(
                                    branchName,
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: Colors.blue.shade800,
                                    ),
                                  ),
                                );
                              }).toList(),
                            ),
                        ],
                      ),
                      trailing: ElevatedButton(
                        onPressed: () => _assignBranches(coach),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.green,
                          foregroundColor: Colors.white,
                        ),
                        child: const Text('Assign'),
                      ),
                      onTap: () => _assignBranches(coach),
                    ),
                  );
                },
              ),
            ),
    );
  }
}

class BranchAssignmentDialog extends StatefulWidget {
  final String coachName;
  final List<Branch> branches;
  final List<int> selectedBranchIds;

  const BranchAssignmentDialog({
    super.key,
    required this.coachName,
    required this.branches,
    required this.selectedBranchIds,
  });

  @override
  State<BranchAssignmentDialog> createState() => _BranchAssignmentDialogState();
}

class _BranchAssignmentDialogState extends State<BranchAssignmentDialog> {
  late Set<int> selectedBranches;

  @override
  void initState() {
    super.initState();
    selectedBranches = Set<int>.from(widget.selectedBranchIds);
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text('Assign Branches to ${widget.coachName}'),
      content: SizedBox(
        width: double.maxFinite,
        child: widget.branches.isEmpty
            ? const Text('No branches available')
            : Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text('Select branches to assign:'),
                  const SizedBox(height: 16),
                  Flexible(
                    child: ListView.builder(
                      shrinkWrap: true,
                      itemCount: widget.branches.length,
                      itemBuilder: (context, index) {
                        final branch = widget.branches[index];
                        final isSelected = selectedBranches.contains(branch.id);

                        return CheckboxListTile(
                          title: Text(branch.name),
                          subtitle: Text(branch.address),
                          value: isSelected,
                          onChanged: branch.isActive
                              ? (value) {
                                  setState(() {
                                    if (value == true) {
                                      selectedBranches.add(branch.id);
                                    } else {
                                      selectedBranches.remove(branch.id);
                                    }
                                  });
                                }
                              : null,
                          secondary: Icon(
                            branch.isActive
                                ? Icons.store
                                : Icons.store_mall_directory_outlined,
                            color: branch.isActive ? Colors.green : Colors.grey,
                          ),
                        );
                      },
                    ),
                  ),
                ],
              ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        ElevatedButton(
          onPressed: () => Navigator.pop(context, selectedBranches.toList()),
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.blue,
            foregroundColor: Colors.white,
          ),
          child: const Text('Assign'),
        ),
      ],
    );
  }
}
