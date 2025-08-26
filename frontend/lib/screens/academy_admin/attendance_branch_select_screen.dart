import 'package:flutter/material.dart';
import 'package:sportsverse_app/api/branch_api.dart';
import 'package:sportsverse_app/api/auth_api.dart';
import 'package:sportsverse_app/api/batch_api.dart';
import 'package:sportsverse_app/models/branch.dart';
import 'package:sportsverse_app/models/batch.dart';
import 'package:sportsverse_app/models/user.dart';

class AttendanceBranchSelectScreen extends StatefulWidget {
  const AttendanceBranchSelectScreen({super.key});

  @override
  State<AttendanceBranchSelectScreen> createState() => _AttendanceBranchSelectScreenState();
}

class _AttendanceBranchSelectScreenState extends State<AttendanceBranchSelectScreen> {
  bool _loading = true;
  String? _error;
  List<Branch> _branches = [];

  @override
  void initState() {
    super.initState();
    _loadBranches();
  }

  Future<void> _loadBranches() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final branches = await branchApi.getBranches();
      setState(() {
        _branches = branches;
      });
    } catch (e) {
      setState(() => _error = e.toString());
    } finally {
      setState(() => _loading = false);
    }
  }

  void _onSelectBranch(Branch branch) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => AttendanceSportSelectScreen(branch: branch),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Select Branch')),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? Center(child: Text(_error!, style: const TextStyle(color: Colors.red)))
              : LayoutBuilder(
                  builder: (context, constraints) {
                    final double width = constraints.maxWidth;
                    final int columns = width >= 1000
                        ? 4
                        : width >= 700
                            ? 3
                            : 2;
                    return GridView.builder(
                      padding: const EdgeInsets.all(16),
                      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: columns,
                        childAspectRatio: 0.95,
                        crossAxisSpacing: 16,
                        mainAxisSpacing: 16,
                      ),
                      itemCount: _branches.length,
                      itemBuilder: (context, index) {
                        final branch = _branches[index];
                        return _SelectCard(
                          title: branch.name,
                          subtitle: branch.address,
                          icon: Icons.apartment,
                          color: const Color(0xFF667eea),
                          onTap: () => _onSelectBranch(branch),
                        );
                      },
                    );
                  },
                ),
    );
  }
}

class AttendanceSportSelectScreen extends StatefulWidget {
  final Branch branch;
  const AttendanceSportSelectScreen({super.key, required this.branch});

  @override
  State<AttendanceSportSelectScreen> createState() => _AttendanceSportSelectScreenState();
}

class _AttendanceSportSelectScreenState extends State<AttendanceSportSelectScreen> {
  bool _loading = true;
  String? _error;
  List<Sport> _sports = [];

  @override
  void initState() {
    super.initState();
    _loadSports();
  }

  Future<void> _loadSports() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final sports = await authApi.getSports();
      setState(() => _sports = sports);
    } catch (e) {
      setState(() => _error = e.toString());
    } finally {
      setState(() => _loading = false);
    }
  }

  void _onSelectSport(Sport sport) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => AttendanceBatchSelectScreen(branch: widget.branch, sport: sport),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('Select Sport - ${widget.branch.name}')),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? Center(child: Text(_error!, style: const TextStyle(color: Colors.red)))
              : LayoutBuilder(
                  builder: (context, constraints) {
                    final double width = constraints.maxWidth;
                    final int columns = width >= 1000
                        ? 4
                        : width >= 700
                            ? 3
                            : 2;
                    return GridView.builder(
                      padding: const EdgeInsets.all(16),
                      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: columns,
                        childAspectRatio: 0.95,
                        crossAxisSpacing: 16,
                        mainAxisSpacing: 16,
                      ),
                      itemCount: _sports.length,
                      itemBuilder: (context, index) {
                        final sport = _sports[index];
                        return _SelectCard(
                          title: sport.name,
                          subtitle: 'Sport',
                          icon: Icons.sports,
                          color: const Color(0xFF4facfe),
                          onTap: () => _onSelectSport(sport),
                        );
                      },
                    );
                  },
                ),
    );
  }
}

class AttendanceBatchSelectScreen extends StatefulWidget {
  final Branch branch;
  final Sport sport;
  const AttendanceBatchSelectScreen({super.key, required this.branch, required this.sport});

  @override
  State<AttendanceBatchSelectScreen> createState() => _AttendanceBatchSelectScreenState();
}

class _AttendanceBatchSelectScreenState extends State<AttendanceBatchSelectScreen> {
  bool _loading = true;
  String? _error;
  List<Batch> _batches = [];

  @override
  void initState() {
    super.initState();
    _loadBatches();
  }

  Future<void> _loadBatches() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final batches = await batchApi.getBatches();
      setState(() {
        _batches = batches
            .where((b) => b.branchId == widget.branch.id && b.sportId == widget.sport.id)
            .toList();
      });
    } catch (e) {
      setState(() => _error = e.toString());
    } finally {
      setState(() => _loading = false);
    }
  }

  void _onSelectBatch(Batch batch) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => AttendanceActionsScreen(branch: widget.branch, sport: widget.sport, batch: batch),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('Select Batch - ${widget.sport.name}')),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? Center(child: Text(_error!, style: const TextStyle(color: Colors.red)))
              : LayoutBuilder(
                  builder: (context, constraints) {
                    final double width = constraints.maxWidth;
                    final int columns = width >= 1000
                        ? 4
                        : width >= 700
                            ? 3
                            : 2;
                    return GridView.builder(
                      padding: const EdgeInsets.all(16),
                      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: columns,
                        childAspectRatio: 1.25,
                        crossAxisSpacing: 16,
                        mainAxisSpacing: 16,
                      ),
                      itemCount: _batches.length,
                      itemBuilder: (context, index) {
                        final batch = _batches[index];
                        return _SelectCard(
                          title: batch.name,
                          subtitle: batch.scheduleDisplay,
                          icon: Icons.group_work,
                          color: const Color(0xFFf093fb),
                          onTap: () => _onSelectBatch(batch),
                        );
                      },
                    );
                  },
                ),
    );
  }
}

class AttendanceActionsScreen extends StatelessWidget {
  final Branch branch;
  final Sport sport;
  final Batch batch;
  const AttendanceActionsScreen({super.key, required this.branch, required this.sport, required this.batch});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Attendance')),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: LayoutBuilder(
          builder: (context, constraints) {
            final double width = constraints.maxWidth;
            final int columns = width >= 1000
                ? 4
                : width >= 700
                    ? 3
                    : 2;
            return GridView.count(
              crossAxisCount: columns,
              crossAxisSpacing: 16,
              mainAxisSpacing: 16,
              childAspectRatio: 0.95,
              children: [
                _SelectCard(
                  title: 'Mark Attendance',
                  subtitle: '${branch.name} • ${sport.name}',
                  icon: Icons.fact_check,
                  color: const Color(0xFF06beb6),
                  onTap: () {
                    Navigator.pushNamed(context, '/attendance/take', arguments: {
                      'branchId': branch.id,
                      'branchName': branch.name,
                      'sportId': sport.id,
                      'sportName': sport.name,
                      'batchId': batch.id,
                      'batchName': batch.name,
                    });
                  },
                ),
                _SelectCard(
                  title: 'View Attendance',
                  subtitle: '${branch.name} • ${sport.name}',
                  icon: Icons.insights,
                  color: const Color(0xFF43e97b),
                  onTap: () {
                    Navigator.pushNamed(context, '/attendance/view', arguments: {
                      'branchId': branch.id,
                      'branchName': branch.name,
                      'sportId': sport.id,
                      'sportName': sport.name,
                      'batchId': batch.id,
                      'batchName': batch.name,
                    });
                  },
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}

class _SelectCard extends StatelessWidget {
  final String title;
  final String subtitle;
  final IconData icon;
  final Color color;
  final VoidCallback onTap;

  const _SelectCard({required this.title, required this.subtitle, required this.icon, required this.color, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(16),
      elevation: 2,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: FittedBox(
            fit: BoxFit.scaleDown,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: color.withOpacity(0.12),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Icon(icon, color: color, size: 32),
                ),
                const SizedBox(height: 12),
                Text(
                  title,
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: Colors.grey[800]),
                ),
                const SizedBox(height: 6),
                Text(
                  subtitle,
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 13, color: Colors.grey[600]),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}


