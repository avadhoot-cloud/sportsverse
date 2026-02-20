// lib/screens/student/student_dashboard_screen.dart

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:sportsverse_app/providers/student_provider.dart';
import 'package:sportsverse_app/screens/student/attendance_screen.dart';
import 'package:sportsverse_app/screens/student/payment_screen.dart';

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
      final provider = Provider.of<StudentProvider>(context, listen: false);
      provider.loadDashboardData();
    });
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<StudentProvider>();
    final data = provider.dashboardData;

    return Scaffold(
      backgroundColor: const Color(0xFFF5F7F9),
      // --- THE HAMBURGER DRAWER ---
      drawer: _buildHamburgerMenu(context),
      
      appBar: AppBar(
        title: const Text("Student Dashboard", 
          style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold, fontSize: 18)),
        backgroundColor: Colors.white,
        elevation: 0.5,
        iconTheme: const IconThemeData(color: Colors.black), 
        actions: [
          IconButton(onPressed: () {}, icon: const Icon(Icons.notifications_none)),
          const CircleAvatar(radius: 15, child: Icon(Icons.person, size: 18)),
          const SizedBox(width: 16),
        ],
      ),

      body: provider.isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text("My Enrollment", 
                    style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Color(0xFF1B3D2F))),
                  const SizedBox(height: 20),
                  
                  // DASHBOARD CARDS
                  _buildEnrollmentCard(
                    title: "Selected Sport",
                    value: "Football", 
                    icon: Icons.sports_soccer,
                    color: const Color(0xFF1B3D2F),
                  ),
                  const SizedBox(height: 12),
                  _buildEnrollmentCard(
                    title: "Current Branch",
                    value: data?.branchName ?? "Main Stadium",
                    icon: Icons.location_on,
                    color: const Color(0xFF2E7D32),
                  ),
                  const SizedBox(height: 12),
                  _buildEnrollmentCard(
                    title: "Assigned Batch",
                    value: data?.currentEnrollment ?? "9:00 AM - Morning",
                    icon: Icons.timer,
                    color: const Color(0xFF1565C0),
                  ),
                ],
              ),
            ),
    );
  }

  // --- REUSABLE ENROLLMENT CARD ---
  Widget _buildEnrollmentCard({required String title, required String value, required IconData icon, required Color color}) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(15),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10, offset: const Offset(0, 4))],
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(color: color.withOpacity(0.1), borderRadius: BorderRadius.circular(10)),
            child: Icon(icon, color: color, size: 28),
          ),
          const SizedBox(width: 20),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: TextStyle(color: Colors.grey[600], fontSize: 14)),
              const SizedBox(height: 4),
              Text(value, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.black87)),
            ],
          ),
        ],
      ),
    );
  }

  // --- THE SLIDEBAR (DRAWER) ---
  Widget _buildHamburgerMenu(BuildContext context) {
    return Drawer(
      child: Column(
        children: [
          const UserAccountsDrawerHeader(
            decoration: BoxDecoration(color: Color(0xFF1B3D2F)),
            accountName: Text("Student Name", style: TextStyle(fontWeight: FontWeight.bold)),
            accountEmail: Text("student@sportsverse.com"),
            currentAccountPicture: CircleAvatar(backgroundColor: Colors.white, child: Icon(Icons.person, color: Color(0xFF1B3D2F))),
          ),
          _drawerTile(context, Icons.dashboard, "Dashboard", () => Navigator.pop(context)),
          _drawerTile(context, Icons.fact_check, "Attendance", () => _navigateTo(context, "Attendance")),
          _drawerTile(context, Icons.payment, "Payments", () => _navigateTo(context, "Payments")),
          _drawerTile(context, Icons.video_library, "Videos", () => _navigateTo(context, "Videos")),
          _drawerTile(context, Icons.event, "Events", () => _navigateTo(context, "Events")),
          _drawerTile(context, Icons.analytics, "Progress", () => _navigateTo(context, "Progress")),
          _drawerTile(context, Icons.description, "Reports", () => _navigateTo(context, "Reports")),
          const Spacer(),
          const Divider(),
          _drawerTile(context, Icons.logout, "Logout", () {}, isLogout: true),
          const SizedBox(height: 10),
        ],
      ),
    );
  }

  Widget _drawerTile(BuildContext context, IconData icon, String title, VoidCallback onTap, {bool isLogout = false}) {
    return ListTile(
      leading: Icon(icon, color: isLogout ? Colors.red : const Color(0xFF1B3D2F)),
      title: Text(title, style: TextStyle(color: isLogout ? Colors.red : Colors.black87, fontWeight: FontWeight.w500)),
      onTap: onTap,
    );
  }

  // --- NAVIGATION LOGIC ---
  void _navigateTo(BuildContext context, String page) {
    Navigator.pop(context); // Close drawer first
    
    if (page == "Attendance") {
      Navigator.push(
        context, 
        MaterialPageRoute(builder: (context) => const AttendanceScreen())
      );
    } else if (page == "Payments") {
      Navigator.push(
        context, 
        MaterialPageRoute(builder: (context) => const PaymentScreen())
      );
    }
    // As you build Videos, Events, etc., add their conditions here
  }
}