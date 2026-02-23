import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'dart:convert';
import 'package:sportsverse_app/api/api_client.dart';
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
      final response = await apiClient.get('/api/accounts/dashboard-stats/');

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

    return LayoutBuilder(
      builder: (context, constraints) {
        final bool isDesktop = constraints.maxWidth >= 900;

        return Scaffold(
          key: GlobalKey<ScaffoldState>(),
          backgroundColor: const Color(0xFFF8F9FA),
          // --- MOBILE DRAWER ---
          drawer: isDesktop ? null : _buildSidebar(context),
          appBar: isDesktop 
            ? null 
            : _buildMobileAppBar(context, authProvider),
          body: Row(
            children: [
              // --- DESKTOP SIDEBAR ---
              if (isDesktop) _buildSidebar(context),
              
              Expanded(
                child: Column(
                  children: [
                    // --- DESKTOP HEADER ---
                    if (isDesktop) _buildTopHeader(context, authProvider),
                    
                    Expanded(
                      child: FutureBuilder<Map<String, dynamic>>(
                        future: _fetchStats(),
                        builder: (context, snapshot) {
                          final bool isDataLoading = snapshot.connectionState == ConnectionState.waiting;
                          final stats = snapshot.data ?? {
                            'total_students': 0,
                            'total_coaches': 0,
                            'total_branches': 0,
                            'total_batches': 0,
                          };

                          return RefreshIndicator(
                            onRefresh: () async {
                              setState(() {});
                            },
                            child: SingleChildScrollView(
                              physics: const AlwaysScrollableScrollPhysics(),
                              padding: EdgeInsets.all(isDesktop ? 24 : 16),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  _buildWelcomeBanner(user, profile, isDesktop),
                                  const SizedBox(height: 32),
                                  _buildStatsGrid(stats, isDataLoading, constraints.maxWidth),
                                  const SizedBox(height: 32),
                                  Text(
                                    'Quick Actions',
                                    style: TextStyle(
                                      fontSize: isDesktop ? 22 : 18, 
                                      fontWeight: FontWeight.bold, 
                                      color: Colors.grey[800]
                                    ),
                                  ),
                                  const SizedBox(height: 20),
                                  _buildManagementGrid(context, constraints.maxWidth),
                                  const SizedBox(height: 40),
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
    );
  }

  // --- UI COMPONENTS ---

  PreferredSizeWidget _buildMobileAppBar(BuildContext context, AuthProvider auth) {
    return AppBar(
      backgroundColor: Colors.white,
      elevation: 0.5,
      leading: Builder(
        builder: (context) => IconButton(
          icon: const Icon(Icons.menu, color: sidebarDarkGreen),
          onPressed: () => Scaffold.of(context).openDrawer(),
        ),
      ),
      title: const Text('Admin Dashboard', 
          style: TextStyle(color: sidebarDarkGreen, fontSize: 16, fontWeight: FontWeight.bold)),
      actions: [
        IconButton(
          icon: const Icon(Icons.logout, color: Colors.redAccent, size: 20),
          onPressed: () {
            auth.logout();
            Navigator.of(context).pushReplacementNamed('/');
          },
        ),
      ],
    );
  }

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

  Widget _buildStatsGrid(Map<String, dynamic> stats, bool isLoading, double maxWidth) {
    if (isLoading) {
      return const Center(child: Padding(
        padding: EdgeInsets.all(20.0),
        child: CircularProgressIndicator(color: brandTeal),
      ));
    }

    // Dynamic width calculation for cards
    double cardWidth;
    if (maxWidth > 1200) {
      cardWidth = (maxWidth - 260 - 48 - 60) / 4; // 4 cards across
    } else if (maxWidth > 600) {
      cardWidth = (maxWidth - (maxWidth > 900 ? 260 : 0) - 48 - 20) / 2; // 2 cards across
    } else {
      cardWidth = double.infinity; // 1 card across
    }

    return Wrap(
      spacing: 20,
      runSpacing: 20,
      children: [
        _buildStatCard('Total Students', stats['total_students'].toString(), Icons.people, Colors.teal, cardWidth),
        _buildStatCard('Total Coaches', stats['total_coaches'].toString(), Icons.sports, Colors.indigo, cardWidth),
        _buildStatCard('Total Branches', stats['total_branches'].toString(), Icons.business, Colors.orange, cardWidth),
        _buildStatCard('Total Batches', stats['total_batches'].toString(), Icons.layers, Colors.green, cardWidth),
      ],
    );
  }

  Widget _buildStatCard(String title, String value, IconData icon, Color color, double width) {
    return Container(
      width: width,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10)]),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(color: color.withOpacity(0.1), borderRadius: BorderRadius.circular(8)),
            child: Icon(icon, color: color, size: 28),
          ),
          const SizedBox(width: 15),
          Flexible(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(value, 
                  style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
                  overflow: TextOverflow.ellipsis),
                Text(title, 
                  style: TextStyle(color: Colors.grey[500], fontSize: 12),
                  overflow: TextOverflow.ellipsis),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildManagementGrid(BuildContext context, double maxWidth) {
    // 1 column on mobile, 2 columns on desktop
    final int crossAxisCount = maxWidth > 600 ? 2 : 1;
    final double aspectRatio = maxWidth > 1200 ? 4 : (maxWidth > 600 ? 3 : 4);

    return GridView.count(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      crossAxisCount: crossAxisCount,
      childAspectRatio: aspectRatio,
      crossAxisSpacing: 20,
      mainAxisSpacing: 20,
      children: [
        _buildActionButton(context, 'Add Student', Icons.person_add_alt, const Color(0xFFfa709a), 
          () => Navigator.push(context, MaterialPageRoute(builder: (context) => const AddStudentEnrollmentScreen()))),
        _buildActionButton(context, 'Face Attendance', Icons.face, Colors.teal, 
          () => Navigator.push(context, MaterialPageRoute(builder: (context) => const AdminFaceAttendanceScreen()))),
        _buildActionButton(context, 'Batch Manager', Icons.groups, const Color(0xFFf093fb), 
          () => Navigator.push(context, MaterialPageRoute(builder: (context) => const BatchManagementScreen()))),
        _buildActionButton(context, 'Branch List', Icons.location_city, const Color(0xFF4facfe), 
          () => Navigator.push(context, MaterialPageRoute(builder: (context) => const BranchManagementScreen()))),
        _buildActionButton(context, 'Enroll Coach', Icons.sports, const Color(0xFF38ef7d), 
          () => Navigator.push(context, MaterialPageRoute(builder: (context) => const CoachEnrollScreen()))),
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
          const Icon(Icons.search, color: Colors.grey), // Placeholder for search
          Row(
            children: [
              IconButton(icon: const Icon(Icons.notifications_none, color: Colors.grey), onPressed: () {}),
              const SizedBox(width: 10),
              const CircleAvatar(backgroundColor: Color(0xFFEEEEEE), radius: 16, child: Icon(Icons.person, color: Colors.grey, size: 20)),
              const SizedBox(width: 10),
              IconButton(
                icon: const Icon(Icons.logout, color: Colors.redAccent, size: 20),
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

  Widget _buildWelcomeBanner(dynamic user, dynamic profile, bool isDesktop) {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(isDesktop ? 32 : 24),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [brandTeal, Color(0xFF004D40)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(15),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Welcome, ${user?.firstName ?? 'Admin'}!',
              style: TextStyle(
                color: Colors.white, 
                fontSize: isDesktop ? 26 : 22, 
                fontWeight: FontWeight.bold
              )),
          const SizedBox(height: 4),
          Text(profile?.organizationName ?? 'Administrator Dashboard',
              style: TextStyle(color: Colors.white.withOpacity(0.8), fontSize: isDesktop ? 16 : 14)),
        ],
      ),
    );
  }

  Widget _buildActionButton(BuildContext context, String title, IconData icon, Color color, VoidCallback onTap) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.grey[200]!)),
        child: Row(children: [
          Icon(icon, color: color, size: 20),
          const SizedBox(width: 15),
          Expanded(child: Text(title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13), overflow: TextOverflow.ellipsis)),
          const Icon(Icons.arrow_forward_ios, size: 10, color: Colors.grey)
        ]),
    ),
    );
  }
}
