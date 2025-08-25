// sportsverse/frontend/sportsverse_app/lib/screens/student/student_dashboard_screen.dart

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:sportsverse_app/providers/auth_provider.dart';

class StudentDashboardScreen extends StatelessWidget {
  const StudentDashboardScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final authProvider = Provider.of<AuthProvider>(context);
    final user = authProvider.currentUser;
    final profile = authProvider.profileDetails;

    return Scaffold(
      appBar: AppBar(
        title: Text('Student Dashboard - ${profile?.organizationName ?? 'Your Academy'}'),
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: () {
              authProvider.logout();
              Navigator.of(context).pushReplacementNamed('/');
            },
          ),
        ],
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text('Welcome, ${user?.firstName} ${user?.lastName}!', style: Theme.of(context).textTheme.headlineMedium),
            const SizedBox(height: 10),
            Text('User Type: ${user?.userType}', style: Theme.of(context).textTheme.titleMedium),
            if (profile != null) ...[
              const SizedBox(height: 10),
              Text('Organization ID: ${profile.organizationId}', style: Theme.of(context).textTheme.bodyLarge),
              Text('Organization Name: ${profile.organizationName}', style: Theme.of(context).textTheme.bodyLarge),
              Text('Student ID: ${profile.studentId}', style: Theme.of(context).textTheme.bodyLarge),
            ],
            const SizedBox(height: 30),
            ElevatedButton(
              onPressed: () {
                // Example: Navigate to View Attendance
                // Navigator.pushNamed(context, '/student-attendance');
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('Attendance View coming soon!'),
                    backgroundColor: Colors.blue,
                  ),
                );
              },
              child: const Text('View My Attendance'),
            ),
          ],
        ),
      ),
    );
  }
}