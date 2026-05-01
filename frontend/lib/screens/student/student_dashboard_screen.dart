// lib/screens/student/student_dashboard_screen.dart

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:sportsverse_app/models/student_models.dart';
import 'package:sportsverse_app/providers/auth_provider.dart';
import 'package:sportsverse_app/providers/student_provider.dart';
import 'package:sportsverse_app/screens/student/attendance_screen.dart';
import 'package:sportsverse_app/screens/student/events_screen.dart';
import 'package:sportsverse_app/screens/student/notifications_screen.dart';
import 'package:sportsverse_app/screens/student/payment_screen.dart';
import 'package:sportsverse_app/screens/student/progress_screen.dart';
import 'package:sportsverse_app/screens/student/reports_screen.dart';
import 'package:sportsverse_app/screens/student/student_profile_screen.dart';
import 'package:sportsverse_app/screens/student/videos_screen.dart';
import 'package:sportsverse_app/screens/student/submit_match_screen.dart';
import 'package:sportsverse_app/screens/student/match_history_screen.dart';

// ─── DUPR tier helpers ────────────────────────────────────────────────────────

String _duprTierLabel(double rating) {
  if (rating >= 6.0) return 'Elite';
  if (rating >= 4.5) return 'Advanced';
  if (rating >= 3.0) return 'Intermediate';
  return 'Beginner';
}

Color _duprTierColor(double rating) {
  if (rating >= 6.0) return const Color(0xFFE65100); // gold/orange
  if (rating >= 4.5) return const Color(0xFF2E7D32); // green
  if (rating >= 3.0) return const Color(0xFF1565C0); // blue
  return const Color(0xFF6A1B9A);                    // purple
}

// ─── Screen ───────────────────────────────────────────────────────────────────

class StudentDashboardScreen extends StatefulWidget {
  const StudentDashboardScreen({super.key});

  @override
  State<StudentDashboardScreen> createState() => _StudentDashboardScreenState();
}

class _StudentDashboardScreenState extends State<StudentDashboardScreen> {
  @override
  void initState() {
    super.initState();
    Future.microtask(() {
      if (!mounted) return;
      Provider.of<StudentProvider>(context, listen: false).loadDashboardData();
    });
  }

  // ── Navigation helpers ────────────────────────────────────────────────────

  void _go(Widget screen) {
    Navigator.pop(context); // close drawer
    Navigator.push(context, MaterialPageRoute(builder: (_) => screen));
  }

  void _goWithoutDrawer(Widget screen) {
    Navigator.push(context, MaterialPageRoute(builder: (_) => screen));
  }

  void _logout() {
    Navigator.pop(context); // close drawer
    final auth = Provider.of<AuthProvider>(context, listen: false);
    auth.logout();
    if (mounted) {
      Navigator.of(context).pushNamedAndRemoveUntil('/login', (route) => false);
    }
  }

  // ── Build ─────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<StudentProvider>();
    final auth = context.watch<AuthProvider>();
    final data = provider.dashboardData;
    final user = auth.currentUser;

    return Scaffold(
      backgroundColor: const Color(0xFFF5F7F9),
      drawer: _buildDrawer(context, user),
      appBar: AppBar(
        title: const Text(
          "Student Dashboard",
          style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold, fontSize: 18),
        ),
        backgroundColor: Colors.white,
        elevation: 0.5,
        iconTheme: const IconThemeData(color: Colors.black),
        actions: [
          // Notification bell
          IconButton(
            tooltip: "Notifications",
            onPressed: () => _goWithoutDrawer(const NotificationsScreen()),
            icon: const Icon(Icons.notifications_none, color: Colors.black),
          ),
          // Profile avatar
          GestureDetector(
            onTap: () => _goWithoutDrawer(const StudentProfileScreen()),
            child: Padding(
              padding: const EdgeInsets.only(right: 16, left: 4),
              child: CircleAvatar(
                radius: 16,
                backgroundColor: const Color(0xFF1B3D2F),
                backgroundImage: (user?.profilePhoto != null &&
                        user!.profilePhoto!.isNotEmpty)
                    ? NetworkImage(user.profilePhoto!)
                    : null,
                child: (user?.profilePhoto == null || user!.profilePhoto!.isEmpty)
                    ? const Icon(Icons.person, size: 18, color: Colors.white)
                    : null,
              ),
            ),
          ),
        ],
      ),

      body: provider.isLoading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: () =>
                  Provider.of<StudentProvider>(context, listen: false)
                      .loadDashboardData(),
              child: SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Greeting
                    Text(
                      "Hello, ${user?.firstName?.isNotEmpty == true ? user!.firstName! : user?.username ?? 'Student'} 👋",
                      style: const TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF1B3D2F)),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      data != null
                          ? "You have ${data.currentEnrollments.length} active batch(es)"
                          : "Loading your dashboard…",
                      style: const TextStyle(color: Colors.grey, fontSize: 13),
                    ),
                    const SizedBox(height: 20),

                    // ── Enrollment cards ────────────────────────────────────
                    if (data != null && data.currentEnrollments.isNotEmpty) ...[
                      ...data.currentEnrollments.map(
                        (e) => Padding(
                          padding: const EdgeInsets.only(bottom: 12),
                          child: _buildEnrollmentCard(
                            sportName: e.batchName,
                            branchName: e.branchName,
                            sessionsAttended: e.sessionsAttended,
                            totalSessions: e.totalSessions,
                          ),
                        ),
                      ),
                    ] else if (data != null) ...[
                      _buildEnrollmentCard(
                        sportName: "No active enrollment",
                        branchName: "—",
                        sessionsAttended: 0,
                        totalSessions: null,
                      ),
                    ] else ...[
                      // Fallback placeholder while loading
                      _buildEnrollmentCard(
                        sportName: "—",
                        branchName: "—",
                        sessionsAttended: 0,
                        totalSessions: null,
                      ),
                    ],

                    const SizedBox(height: 24),

                    // ── Quick Actions ────────────────────────────────────────
                    const Text(
                      "Quick Actions",
                      style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF1B3D2F)),
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: _buildActionTile(
                            context: context,
                            icon: Icons.sports_tennis,
                            label: "Record Match",
                            color: const Color(0xFF2E7D32),
                            onTap: () => _goWithoutDrawer(const SubmitMatchScreen()),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: _buildActionTile(
                            context: context,
                            icon: Icons.history,
                            label: "Match History",
                            color: const Color(0xFF1565C0),
                            onTap: () => _goWithoutDrawer(const MatchHistoryScreen()),
                          ),
                        ),
                      ],
                    ),
                    
                    const SizedBox(height: 24),

                    // ── DUPR Section ─────────────────────────────────────────
                    const Text(
                      "My DUPR Rating",
                      style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF1B3D2F)),
                    ),
                    const SizedBox(height: 12),
                    _buildDuprCard(data),
                  ],
                ),
              ),
            ),
    );
  }

  // ── Enrollment Card ──────────────────────────────────────────────────────

  Widget _buildEnrollmentCard({
    required String sportName,
    required String branchName,
    required int sessionsAttended,
    required int? totalSessions,
  }) {
    final progress = (totalSessions != null && totalSessions > 0)
        ? sessionsAttended / totalSessions
        : 0.0;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withOpacity(0.05),
              blurRadius: 12,
              offset: const Offset(0, 4))
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: const Color(0xFF1B3D2F).withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(Icons.sports, color: Color(0xFF1B3D2F), size: 24),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(sportName,
                        style: const TextStyle(
                            fontSize: 16, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 2),
                    Row(
                      children: [
                        const Icon(Icons.location_on,
                            size: 13, color: Colors.grey),
                        const SizedBox(width: 3),
                        Text(branchName,
                            style: const TextStyle(
                                color: Colors.grey, fontSize: 12)),
                      ],
                    ),
                  ],
                ),
              ),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                decoration: BoxDecoration(
                  color: const Color(0xFF1B3D2F).withOpacity(0.08),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  "${sessionsAttended}/${totalSessions ?? '∞'}",
                  style: const TextStyle(
                      color: Color(0xFF1B3D2F),
                      fontWeight: FontWeight.bold,
                      fontSize: 13),
                ),
              ),
            ],
          ),
          if (totalSessions != null) ...[
            const SizedBox(height: 14),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text("Sessions Progress",
                    style: TextStyle(color: Colors.grey[600], fontSize: 12)),
                Text("${(progress * 100).toInt()}%",
                    style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 12,
                        color: Color(0xFF1B3D2F))),
              ],
            ),
            const SizedBox(height: 6),
            ClipRRect(
              borderRadius: BorderRadius.circular(6),
              child: LinearProgressIndicator(
                value: progress,
                backgroundColor: const Color(0xFF1B3D2F).withOpacity(0.1),
                color: const Color(0xFF1B3D2F),
                minHeight: 7,
              ),
            ),
          ],
        ],
      ),
    );
  }

  // ── Quick Action Tile ──────────────────────────────────────────────────────
  
  Widget _buildActionTile({
    required BuildContext context,
    required IconData icon,
    required String label,
    required Color color,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: color.withOpacity(0.2), width: 1.5),
          boxShadow: [
            BoxShadow(
              color: color.withOpacity(0.05),
              blurRadius: 10,
              offset: const Offset(0, 4),
            )
          ],
        ),
        child: Column(
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: color.withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, color: color, size: 28),
            ),
            const SizedBox(height: 10),
            Text(
              label,
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  // ── DUPR Card ─────────────────────────────────────────────────────────────

  Widget _buildDuprCard(StudentDashboardData? data) {
    
    // Safely pull stats from backend response, otherwise fallback to defaults
    final double singlesRating = data?.duprSinglesRating ?? 4.000;
    final double doublesRating = data?.duprDoublesRating ?? 4.000;
    final int matchesPlayedS = data?.duprMatchesSingles ?? 0;
    final int matchesPlayedD = data?.duprMatchesDoubles ?? 0;
    final int matchesPlayed = matchesPlayedS + matchesPlayedD;
    final int reliability = data?.duprReliability.toInt() ?? 50;
    
    final bool isProvisional = matchesPlayed < 10;

    final tierColor = _duprTierColor(singlesRating);
    final tierLabel = _duprTierLabel(singlesRating);
    
    final fairness = data?.duprFairness;

    return Column(
      children: [
        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [Color(0xFF1B3D2F), Color(0xFF2D5A46)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(20),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFF1B3D2F).withOpacity(0.3),
                blurRadius: 16,
                offset: const Offset(0, 8),
              )
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header row
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text("DUPR Rating",
                      style: TextStyle(
                          color: Colors.white70,
                          fontSize: 13,
                          fontWeight: FontWeight.w500)),
                  if (isProvisional)
                    Container(
                      padding:
                          const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: Colors.white24,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Text("PROVISIONAL",
                          style: TextStyle(
                              color: Colors.white,
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                              letterSpacing: 0.5)),
                    ),
                ],
              ),
              const SizedBox(height: 16),

              // Ratings row – Singles & Doubles
              Row(
                children: [
                  Expanded(
                    child: _duprRatingBadge(
                        "Singles", singlesRating, tierColor, tierLabel),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _duprRatingBadge("Doubles", doublesRating,
                        _duprTierColor(doublesRating),
                        _duprTierLabel(doublesRating)),
                  ),
                ],
              ),
              const SizedBox(height: 18),

              // Reliability bar
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text("Reliability",
                      style: TextStyle(color: Colors.white70, fontSize: 12)),
                  Text("$reliability%",
                      style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 12)),
                ],
              ),
              const SizedBox(height: 6),
              ClipRRect(
                borderRadius: BorderRadius.circular(6),
                child: LinearProgressIndicator(
                  value: reliability / 100,
                  backgroundColor: Colors.white24,
                  color: Colors.white,
                  minHeight: 7,
                ),
              ),
              const SizedBox(height: 14),

              // Matches played + notice
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.sports_tennis, size: 14, color: Colors.white70),
                      const SizedBox(width: 5),
                      Text("$matchesPlayed matches played",
                          style: const TextStyle(color: Colors.white70, fontSize: 12)),
                    ],
                  ),
                  Text(
                    isProvisional ? "${10 - matchesPlayed} more to establish" : "",
                    style: const TextStyle(color: Colors.white54, fontSize: 11),
                  )
                ],
              ),
              if (isProvisional) ...[
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: Colors.white10,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Row(
                    children: [
                      Icon(Icons.info_outline, color: Colors.white70, size: 14),
                      SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          "Play your first 10 matches to establish a reliable DUPR rating.",
                          style: TextStyle(color: Colors.white70, fontSize: 11),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ],
          ),
        ),
        
        if (fairness != null) ...[
          const SizedBox(height: 24),
          const Align(
            alignment: Alignment.centerLeft,
            child: Text(
              "Match Fairness Index",
              style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF1B3D2F)),
            ),
          ),
          const SizedBox(height: 12),
          _buildFairnessCard(fairness),
        ]
      ],
    );
  }

  Widget _buildFairnessCard(Map<String, dynamic> fairness) {
    Color labelColor = Colors.grey;
    IconData iconData = Icons.help_outline;
    
    switch (fairness['color']) {
      case 'blue':
        labelColor = const Color(0xFF1565C0);
        iconData = Icons.verified_user;
        break;
      case 'yellow':
        labelColor = const Color(0xFFF57F17);
        iconData = Icons.warning_amber_rounded;
        break;
      case 'red':
        labelColor = const Color(0xFFD32F2F);
        iconData = Icons.gavel;
        break;
      case 'gray':
      default:
        labelColor = Colors.grey;
        break;
    }

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withOpacity(0.05),
              blurRadius: 12,
              offset: const Offset(0, 4))
        ],
      ),
      child: Column(
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: labelColor.withOpacity(0.1),
                  shape: BoxShape.circle,
                ),
                child: Icon(iconData, color: labelColor, size: 24),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      fairness['category'] ?? 'Calculating...',
                      style: TextStyle(
                        fontSize: 16, 
                        fontWeight: FontWeight.bold, 
                        color: fairness['category'] == 'Insufficient Data' ? Colors.black87 : labelColor
                      ),
                    ),
                    const SizedBox(height: 2),
                    const Text(
                      "Based on your last 20 singles matches",
                      style: TextStyle(fontSize: 12, color: Colors.grey),
                    ),
                  ],
                ),
              ),
            ],
          ),
          
          if (fairness['category'] != 'Insufficient Data') ...[
            const SizedBox(height: 20),
            Row(
              children: [
                Expanded(
                  child: _fairnessStat(
                    "Avg Rating Diff", 
                    fairness['avg_rating_diff'] > 0 ? "+${fairness['avg_rating_diff']}" : "${fairness['avg_rating_diff']}"
                  ),
                ),
                Expanded(
                  child: _fairnessStat(
                    "Lower Rated %", 
                    "${fairness['lower_rated_pct']}%"
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: _fairnessStat(
                    "Blowout Wins %", 
                    "${fairness['blowout_pct']}%"
                  ),
                ),
                Expanded(
                  child: _fairnessStat(
                    "Close Matches %", 
                    "${fairness['close_match_pct']}%"
                  ),
                ),
              ],
            ),
          ]
        ],
      ),
    );
  }

  Widget _fairnessStat(String label, String value) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(value, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18, color: Color(0xFF1B3D2F))),
        const SizedBox(height: 2),
        Text(label, style: const TextStyle(fontSize: 11, color: Colors.grey, fontWeight: FontWeight.w500)),
      ],
    );
  }



  Widget _duprRatingBadge(
      String label, double rating, Color color, String tier) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white12,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label,
              style: const TextStyle(color: Colors.white60, fontSize: 11)),
          const SizedBox(height: 6),
          Text(rating.toStringAsFixed(3),
              style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 26)),
          const SizedBox(height: 4),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            decoration: BoxDecoration(
              color: color.withOpacity(0.3),
              borderRadius: BorderRadius.circular(6),
            ),
            child: Text(tier,
                style: TextStyle(
                    color: color,
                    fontWeight: FontWeight.bold,
                    fontSize: 10)),
          ),
        ],
      ),
    );
  }

  // ── Drawer ────────────────────────────────────────────────────────────────

  Widget _buildDrawer(BuildContext context, dynamic user) {
    final username = user?.username ?? 'Student';
    final email = user?.email ?? '';

    return Drawer(
      child: ListView(
        padding: EdgeInsets.zero,
        children: [
          UserAccountsDrawerHeader(
            decoration: const BoxDecoration(color: Color(0xFF1B3D2F)),
            accountName: Text(username,
                style: const TextStyle(fontWeight: FontWeight.bold)),
            accountEmail: Text(email),
            currentAccountPicture: CircleAvatar(
              backgroundColor: Colors.white,
              backgroundImage: (user?.profilePhoto != null &&
                      user.profilePhoto.isNotEmpty)
                  ? NetworkImage(user.profilePhoto)
                  : null,
              child: (user?.profilePhoto == null || user.profilePhoto.isEmpty)
                  ? const Icon(Icons.person, color: Color(0xFF1B3D2F), size: 32)
                  : null,
            ),
            onDetailsPressed: () {
              Navigator.pop(context);
              Navigator.push(
                context,
                MaterialPageRoute(
                    builder: (_) => const StudentProfileScreen()),
              );
            },
          ),
          _tile(Icons.dashboard, "Dashboard", () => Navigator.pop(context)),
          _tile(Icons.fact_check, "Attendance",
              () => _go(const AttendanceScreen())),
          _tile(Icons.payment, "Payments", () => _go(const PaymentScreen())),
          _tile(Icons.video_library, "Videos",
              () => _go(const VideosScreen())),
          _tile(Icons.event, "Events", () => _go(const EventsScreen())),
          _tile(Icons.analytics, "Progress",
              () => _go(const ProgressScreen())),
          _tile(Icons.sports_tennis, "Record Match", () => _go(const SubmitMatchScreen())),
          _tile(Icons.history, "Match History", () => _go(const MatchHistoryScreen())),
          _tile(Icons.description, "Reports", () => _go(const ReportsScreen())),
          const Divider(),
          _tile(Icons.notifications_none, "Notifications",
              () => _go(const NotificationsScreen())),
          const Divider(),
          _tile(Icons.logout, "Logout", _logout, isLogout: true),
        ],
      ),
    );
  }

  Widget _tile(IconData icon, String title, VoidCallback onTap,
      {bool isLogout = false}) {
    final color = isLogout ? Colors.red : const Color(0xFF1B3D2F);
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