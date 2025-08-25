// sportsverse/frontend/sportsverse_app/lib/screens/academy_admin/admin_dashboard_screen.dart

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:sportsverse_app/providers/auth_provider.dart';
import 'package:sportsverse_app/screens/academy_admin/branch_management_screen.dart';
import 'package:sportsverse_app/screens/academy_admin/batch_management_screen.dart';
import 'package:sportsverse_app/screens/academy_admin/coach_assignment_screen.dart';
import 'package:sportsverse_app/screens/academy_admin/student_enrollment_screen.dart';
import 'package:sportsverse_app/screens/academy_admin/add_student_enrollment_screen.dart';

class AdminDashboardScreen extends StatelessWidget {
  const AdminDashboardScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final authProvider = Provider.of<AuthProvider>(context);
    final user = authProvider.currentUser;
    final profile = authProvider.profileDetails;

    return Scaffold(
      appBar: AppBar(
        title: Text(
          'Admin Dashboard - ${profile?.organizationName ?? 'Your Academy'}',
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.person_add),
            onPressed: () {
              Navigator.pushNamed(
                context,
                '/register-user',
              ); // Navigate to register coach/student
            },
            tooltip: 'Register New User',
          ),
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: () {
              authProvider.logout();
              Navigator.of(
                context,
              ).pushReplacementNamed('/'); // Go back to login
            },
          ),
        ],
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              'Welcome, ${user?.firstName} ${user?.lastName}!',
              style: Theme.of(context).textTheme.headlineMedium,
            ),
            const SizedBox(height: 10),
            Text(
              'User Type: ${user?.userType}',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            if (profile != null) ...[
              const SizedBox(height: 10),
              Text(
                'Organization ID: ${profile.organizationId}',
                style: Theme.of(context).textTheme.bodyLarge,
              ),
              Text(
                'Organization Name: ${profile.organizationName}',
                style: Theme.of(context).textTheme.bodyLarge,
              ),
            ],
            const SizedBox(height: 30),
            ElevatedButton(
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => const BranchManagementScreen(),
                  ),
                );
              },
              child: const Text('Manage Branches'),
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => const BatchManagementScreen(),
                  ),
                );
              },
              style: ElevatedButton.styleFrom(backgroundColor: Colors.green),
              child: const Text('Manage Batches'),
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => const CoachAssignmentScreen(),
                  ),
                );
              },
              style: ElevatedButton.styleFrom(backgroundColor: Colors.orange),
              child: const Text('Assign Coaches'),
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => const StudentEnrollmentScreen(),
                  ),
                );
              },
              style: ElevatedButton.styleFrom(backgroundColor: Colors.purple),
              child: const Text('Manage Enrollments'),
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: () async {
                final result = await Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => const AddStudentEnrollmentScreen(),
                  ),
                );

                if (result == true) {
                  // Refresh UI or show success message
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text(
                        'Student enrollment completed successfully!',
                      ),
                      backgroundColor: Colors.green,
                    ),
                  );
                }
              },
              style: ElevatedButton.styleFrom(backgroundColor: Colors.teal),
              child: const Text('Add New Student'),
            ),
          ],
        ),
      ),
    );
  }
}
