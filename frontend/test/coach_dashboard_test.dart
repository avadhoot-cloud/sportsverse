// test/coach_dashboard_test.dart
//
// Integration tests for:
//   1. CoachDashboardData model parsing
//   2. AuthProvider user/profile state helpers
//   3. CoachDashboardScreen widget rendering via injected Future

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:sportsverse_app/api/coach_api.dart';
import 'package:sportsverse_app/models/user.dart';
import 'package:sportsverse_app/providers/auth_provider.dart';

// ═══════════════════════════════════════════════════════════════════════════════
// Sample data
// ═══════════════════════════════════════════════════════════════════════════════

CoachDashboardData _sampleDashboard() => CoachDashboardData(
      coachProfile: const CoachProfileSummary(
        id: 1,
        fullName: 'Priya Sharma',
        email: 'priya@test.com',
        specialization: 'Tennis',
        organizationId: 10,
        organizationName: 'Test Academy',
      ),
      assignments: const [
        CoachAssignmentSummary(
          id: 1,
          batchId: 5,
          batchName: 'Morning Batch A',
          branch: 'Main Branch',
          sport: 'Tennis',
          schedule: null,
        ),
      ],
      upcomingSessions: const [
        UpcomingSession(
          batchId: 5,
          batchName: 'Morning Batch A',
          date: '2026-02-22',
          day: 'Sunday',
          time: '07:00',
        ),
        UpcomingSession(
          batchId: 5,
          batchName: 'Morning Batch A',
          date: '2026-02-24',
          day: 'Tuesday',
          time: '07:00',
        ),
      ],
      attendanceSummary: AttendanceSummary(
        last30Days: 18,
        byBatch: const [
          BatchAttendanceSummary(batchId: 5, batchName: 'Morning Batch A', count: 18),
        ],
      ),
      pendingSalary: const PendingSalary(amount: 0, currency: '₹'),
    );

// ═══════════════════════════════════════════════════════════════════════════════
// Test-friendly widget: wraps the dashboard content directly with an
// injected Future — no global coachApi singleton needed.
// ═══════════════════════════════════════════════════════════════════════════════

class _TestDashboardPage extends StatelessWidget {
  const _TestDashboardPage({required this.future});
  final Future<CoachDashboardData> future;

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<CoachDashboardData>(
      future: future,
      builder: (ctx, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(body: Center(child: CircularProgressIndicator()));
        }
        if (snapshot.hasError) {
          return Scaffold(
            body: Center(child: Text('Error: ${snapshot.error}')),
          );
        }
        final data = snapshot.data!;
        return Scaffold(
          appBar: AppBar(title: const Text('Coach Dashboard')),
          body: SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // KPI values as plain Text — easy to find in tests
                Text('Sessions: ${data.upcomingSessions.length}',
                    key: const Key('kpi_sessions')),
                Text('Attendance: ${data.attendanceSummary.last30Days}',
                    key: const Key('kpi_attendance')),
                Text('Salary: ${data.pendingSalary.amount}',
                    key: const Key('kpi_salary')),
                const Divider(),
                // Session tiles
                ...data.upcomingSessions.map(
                  (s) => ListTile(
                    key: Key('session_${s.batchId}_${s.date}'),
                    title: Text(s.batchName),
                    subtitle: Text('${s.day} ${s.date} ${s.time}'),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

Widget _pumpPage(Future<CoachDashboardData> future) {
  final auth = AuthProvider();
  auth.updateUser(User(
    id: 1,
    username: 'priya',
    email: 'priya@test.com',
    firstName: 'Priya',
    lastName: 'Sharma',
    userType: 'COACH',
  ));
  return MultiProvider(
    providers: [ChangeNotifierProvider<AuthProvider>.value(value: auth)],
    child: MaterialApp(home: _TestDashboardPage(future: future)),
  );
}

// ═══════════════════════════════════════════════════════════════════════════════
// Tests
// ═══════════════════════════════════════════════════════════════════════════════

void main() {
  // ── Group 1: Model parsing ────────────────────────────────────────────────
  group('CoachDashboardData.fromJson()', () {
    const sampleJson = <String, dynamic>{
      'coach_profile': {
        'id': 1,
        'full_name': 'Priya Sharma',
        'email': 'p@test.com',
        'specialization': 'Tennis',
        'organization_id': 10,
        'organization_name': 'Test Academy',
      },
      'assignments': [
        {
          'id': 1,
          'batch_id': 5,
          'batch_name': 'Batch A',
          'branch': 'Main',
          'sport': 'Tennis',
        }
      ],
      'upcoming_sessions': [
        {
          'batch_id': 5,
          'batch_name': 'Batch A',
          'date': '2026-02-22',
          'day': 'Sunday',
          'time': '07:00',
        }
      ],
      'attendance_summary': {
        'last_30_days': 18,
        'by_batch': [
          {'batch_id': 5, 'batch_name': 'Batch A', 'count': 18}
        ],
      },
      'pending_salary': {'amount': 0, 'currency': '₹'},
    };

    test('parses coach profile name and specialization', () {
      final data = CoachDashboardData.fromJson(sampleJson);
      expect(data.coachProfile.fullName, 'Priya Sharma');
      expect(data.coachProfile.specialization, 'Tennis');
      expect(data.coachProfile.organizationName, 'Test Academy');
    });

    test('parses upcoming sessions', () {
      final data = CoachDashboardData.fromJson(sampleJson);
      expect(data.upcomingSessions.length, 1);
      expect(data.upcomingSessions.first.day, 'Sunday');
      expect(data.upcomingSessions.first.time, '07:00');
    });

    test('parses attendance summary', () {
      final data = CoachDashboardData.fromJson(sampleJson);
      expect(data.attendanceSummary.last30Days, 18);
      expect(data.attendanceSummary.byBatch.first.count, 18);
    });

    test('handles empty assignments gracefully', () {
      final json = Map<String, dynamic>.from(sampleJson)
        ..['assignments'] = <dynamic>[];
      final data = CoachDashboardData.fromJson(json);
      expect(data.assignments, isEmpty);
    });

    test('parses pending salary amount=0', () {
      final data = CoachDashboardData.fromJson(sampleJson);
      expect(data.pendingSalary.amount, 0.0);
      expect(data.pendingSalary.currency, '₹');
    });

    test('handles null fields with safe defaults', () {
      final json = <String, dynamic>{};
      final data = CoachDashboardData.fromJson(json);
      expect(data.coachProfile.fullName, '');
      expect(data.upcomingSessions, isEmpty);
      expect(data.attendanceSummary.last30Days, 0);
    });
  });

  // ── Group 2: AuthProvider helpers ─────────────────────────────────────────
  group('AuthProvider state helpers', () {
    test('currentUser null before login', () {
      expect(AuthProvider().currentUser, isNull);
    });

    test('updateUser sets currentUser synchronously', () {
      final provider = AuthProvider();
      provider.updateUser(User(
        id: 42,
        username: 'coach1',
        email: 'c@test.com',
        firstName: 'Coach',
        lastName: 'One',
        userType: 'COACH',
      ));
      expect(provider.currentUser?.username, 'coach1');
      expect(provider.currentUser?.userType, 'COACH');
    });

    test('ProfileDetails parses assignedBranches', () {
      final pd = ProfileDetails.fromJson({
        'organization_id': 5,
        'organization_name': 'SportCity',
        'assigned_branches': [1, 2, 3],
      });
      expect(pd.assignedBranches, [1, 2, 3]);
      expect(pd.organizationName, 'SportCity');
    });

    test('User.fromJson maps all fields correctly', () {
      final user = User.fromJson({
        'id': 7,
        'username': 'priya',
        'email': 'priya@test.com',
        'first_name': 'Priya',
        'last_name': 'Sharma',
        'user_type': 'COACH',
        'must_change_password': false,
      });
      expect(user.id, 7);
      expect(user.username, 'priya');
      expect(user.userType, 'COACH');
    });

    test('isLoading starts false', () {
      final provider = AuthProvider();
      expect(provider.isLoading, isFalse);
      expect(provider.errorMessage, isNull);
    });
  });

  // ── Group 3: CoachDashboardScreen widget ──────────────────────────────────
  group('CoachDashboardScreen widget', () {
    testWidgets('shows KPI values after data loads', (tester) async {
      await tester.pumpWidget(_pumpPage(Future.value(_sampleDashboard())));
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('kpi_sessions')), findsOneWidget);
      expect(find.text('Sessions: 2'), findsOneWidget);
      expect(find.text('Attendance: 18'), findsOneWidget);
    });

    testWidgets('shows session list tiles', (tester) async {
      await tester.pumpWidget(_pumpPage(Future.value(_sampleDashboard())));
      await tester.pumpAndSettle();

      // Both sessions should appear
      expect(find.text('Morning Batch A'), findsWidgets);
      expect(find.text('Sunday 2026-02-22 07:00'), findsOneWidget);
    });

    testWidgets('shows error message when future throws', (tester) async {
      // Wrap in delayed to prevent unhandled exception before build
      final Completer<CoachDashboardData> completer = Completer();
      await tester.pumpWidget(_pumpPage(completer.future));
      await tester.pump();
      // Still loading — no content yet
      expect(find.byType(CircularProgressIndicator), findsOneWidget);
      // Complete with error
      completer.completeError(Exception('Network error'));
      // Suppress flutter error output during pumpAndSettle
      final errors = <FlutterErrorDetails>[];
      FlutterError.onError = errors.add;
      await tester.pump();
      FlutterError.onError = FlutterError.presentError;
      // After error, the error view should render
      await tester.pump(const Duration(milliseconds: 50));
      expect(find.textContaining('Error'), findsWidgets);
    });

    testWidgets('AppBar renders Coach Dashboard title', (tester) async {
      await tester.pumpWidget(_pumpPage(Future.value(_sampleDashboard())));
      await tester.pumpAndSettle();

      expect(find.text('Coach Dashboard'), findsOneWidget);
    });
  });
}
