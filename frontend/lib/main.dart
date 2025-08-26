// sportsverse/frontend/sportsverse_app/lib/main.dart

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:sportsverse_app/api/api_client.dart';
import 'package:sportsverse_app/providers/auth_provider.dart';
import 'package:sportsverse_app/screens/academy_admin/coach_dashboard_screen.dart';
import 'package:sportsverse_app/screens/academy_admin/student_dashboard_screen.dart';
import 'package:sportsverse_app/screens/auth/login_screen.dart';
import 'package:sportsverse_app/screens/auth/register_academy_screen.dart';
import 'package:sportsverse_app/screens/auth/forgot_password_screen.dart';
import 'package:sportsverse_app/screens/auth/password_reset_confirm_screen.dart';
import 'package:sportsverse_app/screens/academy_admin/admin_dashboard_screen.dart';
import 'package:sportsverse_app/screens/auth/register_user_screen.dart'; // New screen for coach/student/staff registration
import 'package:sportsverse_app/screens/academy_admin/attendance_branch_select_screen.dart';
import 'package:sportsverse_app/screens/academy_admin/take_attendance_screen.dart';
import 'package:sportsverse_app/screens/academy_admin/view_attendance_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await apiClient.init(); // Initialize API client to load token
  runApp(
    MultiProvider(
      providers: [ChangeNotifierProvider(create: (_) => AuthProvider())],
      child: const SportsVerseApp(),
    ),
  );
}

class SportsVerseApp extends StatefulWidget {
  const SportsVerseApp({super.key});

  @override
  State<SportsVerseApp> createState() => _SportsVerseAppState();
}

class _SportsVerseAppState extends State<SportsVerseApp> {
  @override
  void initState() {
    super.initState();
    // Initialize auth state on app start
    WidgetsBinding.instance.addPostFrameCallback((_) {
      Provider.of<AuthProvider>(context, listen: false).initAuth();
    });
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'SportsVerse',
      theme: ThemeData(
        primarySwatch: Colors.blue,
        visualDensity: VisualDensity.adaptivePlatformDensity,
        fontFamily: 'Inter', // Applying Inter font
        useMaterial3: true,
      ),
      debugShowCheckedModeBanner: false,
      initialRoute: '/',
      routes: {
        '/': (context) {
          final authProvider = Provider.of<AuthProvider>(context);
          if (authProvider.isLoading) {
            return const Scaffold(
              body: Center(child: CircularProgressIndicator()),
            );
          } else if (authProvider.currentUser != null) {
            // Route based on user type after login
            switch (authProvider.currentUser!.userType) {
              case 'PLATFORM_ADMIN':
                return const Text(
                  'Platform Admin Dashboard - To be implemented',
                ); // Placeholder
              case 'ACADEMY_ADMIN':
                return const AdminDashboardScreen();
              case 'COACH':
                return const CoachDashboardScreen();
              case 'STUDENT':
                return const StudentDashboardScreen();
              case 'STAFF':
                return const Text(
                  'Staff Dashboard - To be implemented',
                ); // Placeholder
              default:
                return const LoginScreen();
            }
          } else {
            return const LoginScreen();
          }
        },
        '/register-academy': (context) => const RegisterAcademyScreen(),
        '/register-user': (context) =>
            const RegisterUserScreen(), // Route for coach/student/staff registration
        '/forgot-password': (context) => const ForgotPasswordScreen(),
        '/attendance/branches': (context) => const AttendanceBranchSelectScreen(),
        '/attendance/take': (context) => const TakeAttendanceScreen(),
        '/attendance/view': (context) => const ViewAttendanceScreen(),
        // Define other routes here
      },
      builder: (context, child) {
        // Apply rounded corners and Inter font globally
        return Theme(
          data: Theme.of(context).copyWith(
            cardTheme: Theme.of(context).cardTheme.copyWith(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12.0),
              ),
            ),
            inputDecorationTheme: const InputDecorationTheme(
              border: OutlineInputBorder(
                borderRadius: BorderRadius.all(Radius.circular(12.0)),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.all(Radius.circular(12.0)),
                borderSide: BorderSide(color: Colors.blueGrey, width: 1.0),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.all(Radius.circular(12.0)),
                borderSide: BorderSide(color: Colors.blue, width: 2.0),
              ),
              errorBorder: OutlineInputBorder(
                borderRadius: BorderRadius.all(Radius.circular(12.0)),
                borderSide: BorderSide(color: Colors.red, width: 2.0),
              ),
              focusedErrorBorder: OutlineInputBorder(
                borderRadius: BorderRadius.all(Radius.circular(12.0)),
                borderSide: BorderSide(color: Colors.red, width: 2.0),
              ),
              contentPadding: EdgeInsets.symmetric(
                vertical: 16.0,
                horizontal: 16.0,
              ),
            ),
            elevatedButtonTheme: ElevatedButtonThemeData(
              style: ElevatedButton.styleFrom(
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12.0),
                ),
                padding: const EdgeInsets.symmetric(
                  horizontal: 24,
                  vertical: 12,
                ),
                textStyle: const TextStyle(fontSize: 18),
              ),
            ),
          ),
          child: child!,
        );
      },
    );
  }
}
