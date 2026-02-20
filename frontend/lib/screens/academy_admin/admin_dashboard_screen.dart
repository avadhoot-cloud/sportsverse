import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;

// Existing Imports
import 'package:sportsverse_app/providers/auth_provider.dart';
import 'package:sportsverse_app/screens/academy_admin/student_payment_screen.dart';
import 'package:sportsverse_app/screens/academy_admin/pay_salary_screen.dart';
import 'package:sportsverse_app/screens/academy_admin/salary_details_screen.dart';
import 'package:sportsverse_app/screens/academy_admin/branch_management_screen.dart';
import 'package:sportsverse_app/screens/academy_admin/batch_management_screen.dart';
import 'package:sportsverse_app/screens/academy_admin/add_student_enrollment_screen.dart';
import 'package:sportsverse_app/screens/academy_admin/student_management_screen.dart';
import 'package:sportsverse_app/screens/academy_admin/admin_face_attendance_screen.dart';
import 'package:sportsverse_app/screens/academy_admin/student_attendance_report_screen.dart';
import 'package:sportsverse_app/screens/academy_admin/send_video_screen.dart';
import 'package:sportsverse_app/screens/academy_admin/player_report_screen.dart';
import 'package:sportsverse_app/screens/academy_admin/view_attendance_screen.dart';
import 'package:sportsverse_app/screens/coaches/assign_coach.dart';
import 'package:sportsverse_app/screens/coaches/coach_enroll_screen.dart';
import 'package:sportsverse_app/screens/coaches/coach_list_screen.dart';

class AdminDashboardScreen extends StatefulWidget {
  const AdminDashboardScreen({super.key});

  @override
  State<AdminDashboardScreen> createState() => _AdminDashboardScreenState();
}

class _AdminDashboardScreenState extends State<AdminDashboardScreen> {
  // Expansion states
  bool _isStudentsExpanded = false;
  bool _isAttendanceExpanded = false;
  bool _isPaymentsExpanded = false;
  bool _isStaffExpanded = false;
  bool _isVideosExpanded = false;
  bool _isReportsExpanded = false;
  bool _isCoachesExpanded = false;

  // Brand Colors
  static const Color sidebarDarkGreen = Color(0xFF1B3D2F);
  static const Color brandTeal = Color(0xFF00796B);
  static const Color accentTeal = Color(0xFF00A388);

  // --- DYNAMIC DATA FETCHING ---
  Future<Map<String, dynamic>> _fetchStats() async {
    try {
      final authProvider = Provider.of<AuthProvider>(context, listen: false);
      final token = authProvider.token;

      final response = await http.get(
        Uri.parse('http://127.0.0.1:8000/api/accounts/dashboard-stats/'),
        headers: {
          'Authorization': 'Token $token',
          'Content-Type': 'application/json',
        },
      );

      if (response.statusCode == 200) {
        return json.decode(response.body);
      } else {
        return {
          'total_students': 0,
          'total_coaches': 0,
          'total_branches': 0,
          'total_batches': 0,
        };
      }
    } catch (e) {
      debugPrint("Error fetching stats: $e");
      return {
        'total_students': 0,
        'total_coaches': 0,
        'total_branches': 0,
        'total_batches': 0,
      };
    }
  }

  @override
  Widget build(BuildContext context) {
    final authProvider = Provider.of<AuthProvider>(context);
    final user = authProvider.currentUser;
    final profile = authProvider.profileDetails;

    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FA),
      body: Row(
        children: [
          _buildSidebar(context),
          Expanded(
            child: Column(
              children: [
                _buildTopHeader(context, authProvider),
                Expanded(
                  child: FutureBuilder<Map<String, dynamic>>(
                    future: _fetchStats(),
                    builder: (context, snapshot) {
                      // Handing loading state for the stats specifically
                      final bool isDataLoading = snapshot.connectionState == ConnectionState.waiting;
                      final stats = snapshot.data ?? {
                        'total_students': 0,
                        'total_coaches': 0,
                        'total_branches': 0,
                        'total_batches': 0,
                      };

                      return RefreshIndicator(
                        onRefresh: () async {
                          setState(() {}); // Trigger rebuild to refetch future
                        },
                        child: SingleChildScrollView(
                          physics: const AlwaysScrollableScrollPhysics(),
                          padding: const EdgeInsets.all(24),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              _buildWelcomeBanner(user, profile),
                              const SizedBox(height: 32),
                              _buildStatsGrid(stats, isDataLoading),
                              const SizedBox(height: 32),
                              Text(
                                'Quick Actions',
                                style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Colors.grey[800]),
                              ),
                              const SizedBox(height: 20),
                              _buildManagementGrid(context),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // --- UI COMPONENTS ---

  Widget _buildSidebar(BuildContext context) {
    return Container(
      width: 260,
      color: sidebarDarkGreen,
      child: Column(
        children: [
          const SizedBox(height: 40),
          _buildLogo(),
          const SizedBox(height: 30),
          Expanded(
            child: ListView(
              padding: EdgeInsets.zero,
              children: [
                _sidebarItem(Icons.dashboard, 'Dashboard', isSelected: true),
                _sidebarItem(Icons.assignment, 'Drill Manager'),
                _sidebarItem(Icons.calendar_month, 'Schedule Manager'),

                _buildExpansionTile(
                  title: 'Coaches',
                  icon: Icons.psychology,
                  isExpanded: _isCoachesExpanded,
                  onExpansionChanged: (val) => setState(() => _isCoachesExpanded = val),
                  children: [
                    _sidebarSubItem('Enrolled Coaches', Icons.view_list, () {
                      Navigator.push(context, MaterialPageRoute(builder: (context) => const CoachListScreen()));
                    }),
                    _sidebarSubItem('Enroll Coach', Icons.person_add, () {
                      Navigator.push(context, MaterialPageRoute(builder: (context) => const CoachEnrollScreen()));
                    }),
                    _sidebarSubItem('Assign Coach', Icons.assignment_ind, () {
                      Navigator.push(context, MaterialPageRoute(builder: (context) => const AssignCoachScreen()));
                    }),
                  ],
                ),

                _buildExpansionTile(
                  title: 'Staff',
                  icon: Icons.people,
                  isExpanded: _isStaffExpanded,
                  onExpansionChanged: (val) => setState(() => _isStaffExpanded = val),
                  children: [
                    _sidebarSubItem('Mark Attendance', Icons.how_to_reg, () {}),
                    _sidebarSubItem('Manage Staff', Icons.manage_accounts, () {}),
                    _sidebarSubItem('Assign', Icons.assignment_ind, () {}),
                  ],
                ),

                _buildExpansionTile(
                  title: 'Students',
                  icon: Icons.school,
                  isExpanded: _isStudentsExpanded,
                  onExpansionChanged: (val) => setState(() => _isStudentsExpanded = val),
                  children: [
                    _sidebarSubItem('View Students', Icons.visibility_outlined, () {
                      Navigator.push(context, MaterialPageRoute(builder: (context) => const StudentManagementScreen()));
                    }),
                    _sidebarSubItem('Extend Enrollment', Icons.history, () {}),
                  ],
                ),

                _buildExpansionTile(
                  title: 'Attendance',
                  icon: Icons.check_circle,
                  isExpanded: _isAttendanceExpanded,
                  onExpansionChanged: (val) => setState(() => _isAttendanceExpanded = val),
                  children: [
                    _sidebarSubItem('Take Attendance', Icons.camera_front, () {
                      Navigator.push(context, MaterialPageRoute(builder: (context) => const AdminFaceAttendanceScreen()));
                    }),
                    _sidebarSubItem('View Attendance', Icons.assessment_outlined, () {
                      Navigator.push(context, MaterialPageRoute(builder: (context) => const ViewAttendanceScreen()));
                    }),
                  ],
                ),

                _buildExpansionTile(
                  title: 'Payments',
                  icon: Icons.payments_outlined,
                  isExpanded: _isPaymentsExpanded,
                  onExpansionChanged: (val) => setState(() => _isPaymentsExpanded = val),
                  children: [
                    _sidebarSubItem('Students Payment', Icons.person_search_outlined, () {
                      Navigator.push(context, MaterialPageRoute(builder: (context) => const StudentPaymentScreen()));
                    }),
                    _sidebarSubItem('Salary Details', Icons.receipt_long_outlined, () {
                      Navigator.push(context, MaterialPageRoute(builder: (context) => const SalaryDetailsScreen()));
                    }),
                    _sidebarSubItem('Pay Staff', Icons.send_to_mobile_outlined, () {
                      Navigator.push(context, MaterialPageRoute(builder: (context) => const PaySalaryScreen()));
                    }),
                  ],
                ),

                _buildExpansionTile(
                  title: 'Send Videos',
                  icon: Icons.video_library,
                  isExpanded: _isVideosExpanded,
                  onExpansionChanged: (val) => setState(() => _isVideosExpanded = val),
                  children: [
                    _sidebarSubItem('Video Upload', Icons.cloud_upload_outlined, () {
                      Navigator.push(context, MaterialPageRoute(builder: (context) => const SendVideoScreen()));
                    }),
                  ],
                ),

                _buildExpansionTile(
                  title: 'Player Report',
                  icon: Icons.analytics,
                  isExpanded: _isReportsExpanded,
                  onExpansionChanged: (val) => setState(() => _isReportsExpanded = val),
                  children: [
                    _sidebarSubItem('Upload Report', Icons.upload_file, () {
                      Navigator.push(context, MaterialPageRoute(builder: (context) => const PlayerReportScreen()));
                    }),
                    _sidebarSubItem('Manage Report', Icons.edit_note, () {
                      Navigator.push(context, MaterialPageRoute(builder: (context) => const PlayerReportScreen()));
                    }),
                  ],
                ),

                const Divider(color: Colors.white24, indent: 20, endIndent: 20),
                _sidebarItem(Icons.emoji_events, 'Sports Fest'),
                _sidebarItem(Icons.event, 'Events'),
                _sidebarItem(Icons.report_problem, 'Complaints'),
                _sidebarItem(Icons.feedback, 'Feedback'),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatsGrid(Map<String, dynamic> stats, bool isLoading) {
    if (isLoading) {
      return const Center(child: Padding(
        padding: EdgeInsets.all(20.0),
        child: CircularProgressIndicator(color: brandTeal),
      ));
    }
    return Wrap(
      spacing: 20,
      runSpacing: 20,
      children: [
        _buildStatCard('Total Students', stats['total_students'].toString(), Icons.people, Colors.teal),
        _buildStatCard('Total Coaches', stats['total_coaches'].toString(), Icons.sports, Colors.indigo),
        _buildStatCard('Total Branches', stats['total_branches'].toString(), Icons.business, Colors.orange),
        _buildStatCard('Total Batches', stats['total_batches'].toString(), Icons.layers, Colors.green),
      ],
    );
  }

  Widget _buildStatCard(String title, String value, IconData icon, Color color) {
    return Container(
      width: 240,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10)]),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(color: color.withOpacity(0.1), borderRadius: BorderRadius.circular(8)),
            child: Icon(icon, color: color, size: 28),
          ),
          const SizedBox(width: 15),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(value, style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
              Text(title, style: TextStyle(color: Colors.grey[500], fontSize: 12)),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildManagementGrid(BuildContext context) {
    return GridView.count(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      crossAxisCount: 2,
      childAspectRatio: 4,
      crossAxisSpacing: 20,
      mainAxisSpacing: 20,
      children: [
        _buildActionButton(context, 'Add New Student', Icons.person_add_alt, const Color(0xFFfa709a), 
          () => Navigator.push(context, MaterialPageRoute(builder: (context) => const AddStudentEnrollmentScreen()))),
        _buildActionButton(context, 'Enroll New Coach', Icons.sports, const Color(0xFF38ef7d), 
          () => Navigator.push(context, MaterialPageRoute(builder: (context) => const CoachEnrollScreen()))),
        _buildActionButton(context, 'Batch Manager', Icons.groups, const Color(0xFFf093fb), 
          () => Navigator.push(context, MaterialPageRoute(builder: (context) => const BatchManagementScreen()))),
        _buildActionButton(context, 'Branch List', Icons.location_city, const Color(0xFF4facfe), 
          () => Navigator.push(context, MaterialPageRoute(builder: (context) => const BranchManagementScreen()))),
      ],
    );
  }

  // --- HELPERS ---

  Widget _buildExpansionTile({
    required String title,
    required IconData icon,
    required bool isExpanded,
    required Function(bool) onExpansionChanged,
    required List<Widget> children,
  }) {
    return Theme(
      data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
      child: ExpansionTile(
        onExpansionChanged: onExpansionChanged,
        leading: Icon(icon, color: Colors.white60, size: 20),
        title: Text(title, style: const TextStyle(color: Colors.white60, fontSize: 14)),
        trailing: Icon(isExpanded ? Icons.expand_less : Icons.expand_more, color: Colors.white60, size: 16),
        children: children,
      ),
    );
  }

  Widget _buildLogo() {
    return const Padding(
      padding: EdgeInsets.symmetric(horizontal: 20),
      child: Row(
        children: [
          Icon(Icons.sports_tennis, color: Colors.yellowAccent, size: 28),
          SizedBox(width: 12),
          Text('SPORTSVERSE', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 18)),
        ],
      ),
    );
  }

  Widget _sidebarItem(IconData icon, String label, {bool isSelected = false, VoidCallback? onTap}) {
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 24),
      leading: Icon(icon, color: isSelected ? Colors.white : Colors.white60, size: 20),
      title: Text(label, style: TextStyle(color: isSelected ? Colors.white : Colors.white60, fontSize: 14)),
      onTap: onTap ?? () {},
    );
  }

  Widget _sidebarSubItem(String label, IconData icon, VoidCallback onTap) {
    return ListTile(
      contentPadding: const EdgeInsets.only(left: 50),
      leading: Icon(icon, color: accentTeal, size: 18),
      title: Text(label, style: const TextStyle(color: Colors.white70, fontSize: 13)),
      onTap: onTap,
    );
  }

  Widget _buildTopHeader(BuildContext context, AuthProvider auth) {
    return Container(
      height: 70,
      color: Colors.white,
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          const Icon(Icons.menu, color: Colors.grey),
          Row(
            children: [
              IconButton(icon: const Icon(Icons.person_add_outlined, color: Colors.cyan), onPressed: () {}),
              const SizedBox(width: 10),
              const CircleAvatar(backgroundColor: Color(0xFFEEEEEE), child: Icon(Icons.person, color: Colors.grey)),
              const SizedBox(width: 10),
              IconButton(
                icon: const Icon(Icons.logout, color: Colors.redAccent),
                onPressed: () {
                  auth.logout();
                  Navigator.of(context).pushReplacementNamed('/');
                },
              ),
            ],
          )
        ],
      ),
    );
  }

  Widget _buildWelcomeBanner(dynamic user, dynamic profile) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(32),
      decoration: BoxDecoration(
        gradient: const LinearGradient(colors: [brandTeal, Color(0xFF004D40)]),
        borderRadius: BorderRadius.circular(15),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Welcome, ${user?.firstName ?? 'Admin'}',
              style: const TextStyle(color: Colors.white, fontSize: 26, fontWeight: FontWeight.bold)),
          Text(profile?.organizationName ?? 'Administrator Dashboard',
              style: TextStyle(color: Colors.white.withOpacity(0.8), fontSize: 16)),
        ],
      ),
    );
  }

  Widget _buildActionButton(BuildContext context, String title, IconData icon, Color color, VoidCallback onTap) {
    return InkWell(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.grey[200]!)),
        child: Row(children: [
          Icon(icon, color: color),
          const SizedBox(width: 15),
          Text(title, style: const TextStyle(fontWeight: FontWeight.bold)),
          const Spacer(),
          const Icon(Icons.arrow_forward_ios, size: 12, color: Colors.grey)
        ]),
      ),
    );
  }
}