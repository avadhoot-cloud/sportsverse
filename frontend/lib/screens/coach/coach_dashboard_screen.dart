// lib/screens/coach/coach_dashboard_screen.dart
//
// Sidebar + KPI cards for the coach. Matches student dashboard style.
// No fee/salary cards shown to the coach.

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:sportsverse_app/api/coach_api.dart';
import 'package:sportsverse_app/providers/auth_provider.dart';
import 'package:sportsverse_app/screens/coach/coach_attendance_screen.dart';
import 'package:sportsverse_app/screens/coach/coach_batches_screen.dart';
import 'package:sportsverse_app/screens/coach/coach_ratings_screen.dart';

// ─── Colour constants (same dark green as student dashboard) ──────────────────
const Color _kGreen = Color(0xFF1B3D2F);
const Color _kBg    = Color(0xFFF5F7F9);

class CoachDashboardScreen extends StatefulWidget {
  const CoachDashboardScreen({super.key});

  @override
  State<CoachDashboardScreen> createState() => _CoachDashboardScreenState();
}

class _CoachDashboardScreenState extends State<CoachDashboardScreen> {
  late Future<CoachDashboardData> _future;

  @override
  void initState() {
    super.initState();
    _future = coachApi.getCoachDashboard();
  }

  void _refresh() => setState(() {
        _future = coachApi.getCoachDashboard();
      });

  // Navigation helpers
  void _go(Widget screen) {
    Navigator.pop(context); // close drawer
    Navigator.push(context, MaterialPageRoute(builder: (_) => screen));
  }

  void _logout() {
    Navigator.pop(context);
    Provider.of<AuthProvider>(context, listen: false).logout();
    if (mounted) Navigator.of(context).pushNamedAndRemoveUntil('/', (r) => false);
  }

  @override
  Widget build(BuildContext context) {
    final user = context.watch<AuthProvider>().currentUser;

    return Scaffold(
      backgroundColor: _kBg,
      drawer: _buildDrawer(context, user),
      appBar: AppBar(
        title: const Text(
          'Coach Dashboard',
          style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold, fontSize: 18),
        ),
        backgroundColor: Colors.white,
        elevation: 0.5,
        iconTheme: const IconThemeData(color: Colors.black),
        actions: [
          IconButton(
            tooltip: 'Refresh',
            onPressed: _refresh,
            icon: const Icon(Icons.refresh, color: Colors.black),
          ),
          Padding(
            padding: const EdgeInsets.only(right: 16, left: 4),
            child: CircleAvatar(
              radius: 16,
              backgroundColor: _kGreen,
              child: const Icon(Icons.person, size: 18, color: Colors.white),
            ),
          ),
        ],
      ),
      body: FutureBuilder<CoachDashboardData>(
        future: _future,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return _ErrorRetry(
              message: snapshot.error.toString().replaceFirst('Exception: ', ''),
              onRetry: _refresh,
            );
          }
          final data = snapshot.data!;
          return RefreshIndicator(
            onRefresh: () async => _refresh(),
            child: SingleChildScrollView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Greeting
                  Text(
                    "Hello, ${data.coachProfile.fullName.isNotEmpty ? data.coachProfile.fullName : user?.username ?? 'Coach'} 👋",
                    style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: _kGreen),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    data.coachProfile.specialization.isNotEmpty
                        ? data.coachProfile.specialization
                        : data.coachProfile.organizationName,
                    style: const TextStyle(color: Colors.grey, fontSize: 13),
                  ),
                  const SizedBox(height: 24),

                  // KPI cards
                  Row(
                    children: [
                      Expanded(
                        child: _KpiCard(
                          icon: Icons.calendar_today,
                          color: const Color(0xFF4A90E2),
                          label: 'Upcoming Sessions',
                          value: data.upcomingSessions.length.toString(),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _KpiCard(
                          icon: Icons.how_to_reg,
                          color: const Color(0xFF27AE60),
                          label: 'Attendance (30d)',
                          value: data.attendanceSummary.last30Days.toString(),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: _KpiCard(
                          icon: Icons.sports,
                          color: const Color(0xFF8E44AD),
                          label: 'My Batches',
                          value: data.assignments.length.toString(),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _KpiCard(
                          icon: Icons.star,
                          color: const Color(0xFFE67E22),
                          label: 'Quick Actions',
                          value: 'Tap Sidebar',
                          isAction: true,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 28),

                  // Upcoming sessions list
                  const Text('Upcoming Sessions',
                      style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold, color: _kGreen)),
                  const SizedBox(height: 12),
                  if (data.upcomingSessions.isEmpty)
                    const _EmptyState(message: 'No upcoming sessions this week')
                  else
                    ...data.upcomingSessions.take(5).map((s) => _SessionTile(session: s)),

                  const SizedBox(height: 28),

                  // Batch list
                  const Text('My Batches',
                      style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold, color: _kGreen)),
                  const SizedBox(height: 12),
                  if (data.assignments.isEmpty)
                    const _EmptyState(message: 'No batches assigned yet')
                  else
                    ...data.assignments.map(
                      (a) => Padding(
                        padding: const EdgeInsets.only(bottom: 10),
                        child: _BatchCard(assignment: a),
                      ),
                    ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  // ── Drawer ─────────────────────────────────────────────────────────────────

  Widget _buildDrawer(BuildContext context, dynamic user) {
    final username = user?.username ?? 'Coach';
    final email    = user?.email    ?? '';

    return Drawer(
      child: ListView(
        padding: EdgeInsets.zero,
        children: [
          UserAccountsDrawerHeader(
            decoration: const BoxDecoration(color: _kGreen),
            accountName: Text(username,
                style: const TextStyle(fontWeight: FontWeight.bold)),
            accountEmail: Text(email),
            currentAccountPicture: const CircleAvatar(
              backgroundColor: Colors.white,
              child: Icon(Icons.sports_tennis, color: _kGreen, size: 32),
            ),
          ),
          _tile(Icons.dashboard, 'Dashboard', () => Navigator.pop(context)),
          _tile(Icons.fact_check, 'Attendance', () => _go(const CoachAttendanceScreen())),
          _tile(Icons.sports, 'My Batches', () => _go(const CoachBatchesScreen())),
          _tile(Icons.star, 'DUPR Ratings', () => _go(const CoachRatingsScreen())),
          const Divider(),
          _tile(Icons.logout, 'Logout', _logout, isLogout: true),
        ],
      ),
    );
  }

  Widget _tile(IconData icon, String title, VoidCallback onTap,
      {bool isLogout = false}) {
    final color = isLogout ? Colors.red : _kGreen;
    return ListTile(
      leading: Icon(icon, color: color),
      title: Text(title,
          style: TextStyle(
              color: isLogout ? Colors.red : Colors.black87,
              fontWeight: FontWeight.w500)),
      onTap: onTap,
    );
  }
}

// ─── KPI Card ─────────────────────────────────────────────────────────────────

class _KpiCard extends StatelessWidget {
  const _KpiCard({
    required this.icon,
    required this.color,
    required this.label,
    required this.value,
    this.isAction = false,
  });

  final IconData icon;
  final Color color;
  final String label;
  final String value;
  final bool isAction;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10, offset: const Offset(0, 4)),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: color.withOpacity(0.12),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: color, size: 22),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(value,
                    style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: isAction ? Colors.grey : color)),
                Text(label,
                    style: const TextStyle(fontSize: 11, color: Colors.grey),
                    overflow: TextOverflow.ellipsis),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Session Tile ─────────────────────────────────────────────────────────────

class _SessionTile extends StatelessWidget {
  const _SessionTile({required this.session});
  final UpcomingSession session;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
          boxShadow: [
            BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 8, offset: const Offset(0, 2)),
          ],
        ),
        child: Row(
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: const Color(0xFF4A90E2).withOpacity(0.1),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Center(
                child: Text(
                  session.day.length >= 2 ? session.day.substring(0, 2).toUpperCase() : session.day,
                  style: const TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF4A90E2), fontSize: 13),
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(session.batchName,
                      style: const TextStyle(fontWeight: FontWeight.w600),
                      overflow: TextOverflow.ellipsis),
                  Text('${session.date}  ${session.time}',
                      style: const TextStyle(fontSize: 12, color: Colors.grey)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─── Batch Card ───────────────────────────────────────────────────────────────

class _BatchCard extends StatelessWidget {
  const _BatchCard({required this.assignment});
  final CoachAssignmentSummary assignment;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 8, offset: const Offset(0, 2)),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: const Color(0xFF8E44AD).withOpacity(0.1),
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Icon(Icons.sports_tennis, color: Color(0xFF8E44AD), size: 22),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(assignment.batchName,
                    style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
                const SizedBox(height: 2),
                Text('${assignment.sport} · ${assignment.branch}',
                    style: const TextStyle(fontSize: 12, color: Colors.grey)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Helpers ──────────────────────────────────────────────────────────────────

class _EmptyState extends StatelessWidget {
  const _EmptyState({required this.message});
  final String message;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 20),
      child: Center(
        child: Text(message, style: const TextStyle(color: Colors.grey)),
      ),
    );
  }
}

class _ErrorRetry extends StatelessWidget {
  const _ErrorRetry({required this.message, required this.onRetry});
  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.error_outline, size: 56, color: Colors.redAccent),
            const SizedBox(height: 16),
            Text(message, textAlign: TextAlign.center, style: const TextStyle(color: Colors.grey)),
            const SizedBox(height: 20),
            ElevatedButton.icon(
              onPressed: onRetry,
              icon: const Icon(Icons.refresh),
              label: const Text('Retry'),
            ),
          ],
        ),
      ),
    );
  }
}
