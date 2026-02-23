// lib/api/coach_api.dart — extended with attendance, student roster, ratings, match submit

import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:sportsverse_app/api/api_client.dart';

// ═══════════════════════════════════════════════════════════════════════════════
// Original models (unchanged)
// ═══════════════════════════════════════════════════════════════════════════════

class Coach {
  final int id;
  final String coachName;
  final List<int> assignedBranches;
  final List<String> assignedBranchNames;

  const Coach({
    required this.id,
    required this.coachName,
    required this.assignedBranches,
    required this.assignedBranchNames,
  });

  factory Coach.fromJson(Map<String, dynamic> json) => Coach(
        id: json['id'] as int,
        coachName: json['coach_name'] as String? ?? '',
        assignedBranches:
            List<int>.from(json['branches'] as List? ?? const []),
        assignedBranchNames:
            List<String>.from(json['assigned_branch_names'] as List? ?? const []),
      );
}

class CoachProfileSummary {
  final int id;
  final String fullName;
  final String email;
  final String specialization;
  final int organizationId;
  final String organizationName;

  const CoachProfileSummary({
    required this.id,
    required this.fullName,
    required this.email,
    required this.specialization,
    required this.organizationId,
    required this.organizationName,
  });

  factory CoachProfileSummary.fromJson(Map<String, dynamic> j) =>
      CoachProfileSummary(
        id: j['id'] as int? ?? 0,
        fullName: j['full_name'] as String? ?? '',
        email: j['email'] as String? ?? '',
        specialization: j['specialization'] as String? ?? '',
        organizationId: j['organization_id'] as int? ?? 0,
        organizationName: j['organization_name'] as String? ?? '',
      );
}

class CoachAssignmentSummary {
  final int id;
  final int batchId;
  final String batchName;
  final String branch;
  final String sport;
  final Map<String, dynamic>? schedule;

  const CoachAssignmentSummary({
    required this.id,
    required this.batchId,
    required this.batchName,
    required this.branch,
    required this.sport,
    this.schedule,
  });

  factory CoachAssignmentSummary.fromJson(Map<String, dynamic> j) =>
      CoachAssignmentSummary(
        id: j['assignment_id'] as int? ?? 0,
        batchId: j['batch_id'] as int? ?? 0,
        batchName: j['batch_name'] as String? ?? '',
        branch: j['branch_name'] as String? ?? j['branch'] as String? ?? '',
        sport: j['sport_name'] as String? ?? j['sport'] as String? ?? '',
        schedule: j['schedule'] as Map<String, dynamic>?,
      );
}

class UpcomingSession {
  final int batchId;
  final String batchName;
  final String date;
  final String day;
  final String time;

  const UpcomingSession({
    required this.batchId,
    required this.batchName,
    required this.date,
    required this.day,
    required this.time,
  });

  factory UpcomingSession.fromJson(Map<String, dynamic> j) => UpcomingSession(
        batchId: j['batch_id'] as int? ?? 0,
        batchName: j['batch_name'] as String? ?? '',
        date: j['date'] as String? ?? '',
        day: j['day'] as String? ?? '',
        time: j['start_time'] as String? ?? j['time'] as String? ?? '',
      );
}

class BatchAttendanceSummary {
  final int batchId;
  final String batchName;
  final int count;

  const BatchAttendanceSummary({
    required this.batchId,
    required this.batchName,
    required this.count,
  });

  factory BatchAttendanceSummary.fromJson(Map<String, dynamic> j) =>
      BatchAttendanceSummary(
        batchId: j['batch_id'] as int? ?? 0,
        batchName: j['batch_name'] as String? ?? '',
        count: j['sessions_marked'] as int? ?? j['count'] as int? ?? 0,
      );
}

class AttendanceSummary {
  final int last30Days;
  final List<BatchAttendanceSummary> byBatch;

  const AttendanceSummary({
    required this.last30Days,
    required this.byBatch,
  });

  factory AttendanceSummary.fromJson(Map<String, dynamic> j) =>
      AttendanceSummary(
        last30Days: j['total_sessions_marked'] as int? ?? j['last_30_days'] as int? ?? 0,
        byBatch: (j['by_batch'] as List? ?? const [])
            .map((b) => BatchAttendanceSummary.fromJson(b as Map<String, dynamic>))
            .toList(),
      );
}

class PendingSalary {
  final double amount;
  final String currency;

  const PendingSalary({required this.amount, required this.currency});

  factory PendingSalary.fromJson(Map<String, dynamic> j) => PendingSalary(
        amount: (j['amount'] as num? ?? 0).toDouble(),
        currency: j['currency'] as String? ?? '₹',
      );
}

class CoachDashboardData {
  final CoachProfileSummary coachProfile;
  final List<CoachAssignmentSummary> assignments;
  final List<UpcomingSession> upcomingSessions;
  final AttendanceSummary attendanceSummary;
  final PendingSalary pendingSalary;

  const CoachDashboardData({
    required this.coachProfile,
    required this.assignments,
    required this.upcomingSessions,
    required this.attendanceSummary,
    required this.pendingSalary,
  });

  factory CoachDashboardData.fromJson(Map<String, dynamic> j) =>
      CoachDashboardData(
        coachProfile: CoachProfileSummary.fromJson(
          j['coach_profile'] as Map<String, dynamic>? ?? const {},
        ),
        assignments: (j['assignments'] as List? ?? const [])
            .map((a) => CoachAssignmentSummary.fromJson(a as Map<String, dynamic>))
            .toList(),
        upcomingSessions: (j['upcoming_sessions'] as List? ?? const [])
            .map((s) => UpcomingSession.fromJson(s as Map<String, dynamic>))
            .toList(),
        attendanceSummary: AttendanceSummary.fromJson(
          j['attendance_summary'] as Map<String, dynamic>? ?? const {},
        ),
        pendingSalary: PendingSalary.fromJson(
          j['pending_salary'] as Map<String, dynamic>? ?? const {},
        ),
      );
}

// ═══════════════════════════════════════════════════════════════════════════════
// New models — Student roster, attendance, DUPR ratings, match scoring
// ═══════════════════════════════════════════════════════════════════════════════

class CoachStudent {
  final int enrollmentId;
  final int studentId;
  final int userId;
  final String username;
  final String firstName;
  final String lastName;
  final int batchId;
  final String batchName;
  final String sportName;
  final String branchName;
  final String enrollmentType;
  final int sessionsAttended;
  final int? totalSessions;

  const CoachStudent({
    required this.enrollmentId,
    required this.studentId,
    required this.userId,
    required this.username,
    required this.firstName,
    required this.lastName,
    required this.batchId,
    required this.batchName,
    required this.sportName,
    required this.branchName,
    required this.enrollmentType,
    required this.sessionsAttended,
    this.totalSessions,
  });

  String get displayName {
    final full = '$firstName $lastName'.trim();
    return full.isNotEmpty ? full : username;
  }

  factory CoachStudent.fromJson(Map<String, dynamic> j) => CoachStudent(
        enrollmentId: j['enrollment_id'] as int,
        studentId: j['student_id'] as int,
        userId: j['user_id'] as int,
        username: j['username'] as String? ?? '',
        firstName: j['first_name'] as String? ?? '',
        lastName: j['last_name'] as String? ?? '',
        batchId: j['batch_id'] as int,
        batchName: j['batch_name'] as String? ?? '',
        sportName: j['sport_name'] as String? ?? '',
        branchName: j['branch_name'] as String? ?? '',
        enrollmentType: j['enrollment_type'] as String? ?? '',
        sessionsAttended: j['sessions_attended'] as int? ?? 0,
        totalSessions: j['total_sessions'] as int?,
      );
}

class StudentRatingItem {
  final int userId;
  final String username;
  final String firstName;
  final String lastName;
  final int? sportId;
  final String sportName;
  final double duprRatingSingles;
  final double duprRatingDoubles;
  final int matchesPlayedSingles;
  final int matchesPlayedDoubles;
  final int reliability;
  final bool isProvisional;
  final String? updatedAt;

  const StudentRatingItem({
    required this.userId,
    required this.username,
    required this.firstName,
    required this.lastName,
    this.sportId,
    required this.sportName,
    required this.duprRatingSingles,
    required this.duprRatingDoubles,
    required this.matchesPlayedSingles,
    required this.matchesPlayedDoubles,
    required this.reliability,
    required this.isProvisional,
    this.updatedAt,
  });

  String get displayName {
    final full = '$firstName $lastName'.trim();
    return full.isNotEmpty ? full : username;
  }

  factory StudentRatingItem.fromJson(Map<String, dynamic> j) =>
      StudentRatingItem(
        userId: j['user_id'] as int,
        username: j['username'] as String? ?? '',
        firstName: j['first_name'] as String? ?? '',
        lastName: j['last_name'] as String? ?? '',
        sportId: j['sport_id'] as int?,
        sportName: j['sport_name'] as String? ?? 'N/A',
        duprRatingSingles: (j['dupr_rating_singles'] as num? ?? 4.0).toDouble(),
        duprRatingDoubles: (j['dupr_rating_doubles'] as num? ?? 4.0).toDouble(),
        matchesPlayedSingles: j['matches_played_singles'] as int? ?? 0,
        matchesPlayedDoubles: j['matches_played_doubles'] as int? ?? 0,
        reliability: j['reliability'] as int? ?? 0,
        isProvisional: j['is_provisional'] as bool? ?? true,
        updatedAt: j['updated_at'] as String?,
      );
}

class MatchResult {
  final int matchId;
  final String format;
  final Map<String, dynamic> raw;

  const MatchResult({required this.matchId, required this.format, required this.raw});

  factory MatchResult.fromJson(Map<String, dynamic> j) => MatchResult(
        matchId: j['match_id'] as int,
        format: j['format'] as String? ?? 'SINGLES',
        raw: j,
      );
}

class MatchHistoryItem {
  final int matchId;
  final String sport;
  final String date;
  final String format;
  final String importance;
  final String status;
  final Map<String, dynamic> score;

  const MatchHistoryItem({
    required this.matchId,
    required this.sport,
    required this.date,
    required this.format,
    required this.importance,
    required this.status,
    required this.score,
  });

  factory MatchHistoryItem.fromJson(Map<String, dynamic> j) => MatchHistoryItem(
        matchId: j['match_id'] as int,
        sport: j['sport'] as String? ?? '',
        date: j['date'] as String? ?? '',
        format: j['format'] as String? ?? 'SINGLES',
        importance: j['importance'] as String? ?? 'CASUAL',
        status: j['status'] as String? ?? 'PENDING',
        score: j['score'] as Map<String, dynamic>? ?? {},
      );
}

// ═══════════════════════════════════════════════════════════════════════════════
// API class
// ═══════════════════════════════════════════════════════════════════════════════

class CoachApi {
  final ApiClient apiClient;
  const CoachApi(this.apiClient);

  // ── Original methods ────────────────────────────────────────────────────────

  Future<List<Coach>> getCoaches() async {
    final response = await apiClient.get('/api/accounts/coaches/', includeAuth: true);
    if (response.statusCode == 200) {
      return (json.decode(response.body) as List)
          .map((j) => Coach.fromJson(j as Map<String, dynamic>))
          .toList();
    }
    final err = json.decode(response.body);
    throw Exception(err['detail'] ?? 'Failed to load coaches');
  }

  Future<Coach> assignBranches({required int coachId, required List<int> branchIds}) async {
    final response = await apiClient.put(
      '/api/accounts/coaches/$coachId/assign-branches/',
      {'branches': branchIds},
      includeAuth: true,
    );
    if (response.statusCode == 200) {
      return Coach.fromJson(
        (json.decode(response.body) as Map<String, dynamic>)['coach'] as Map<String, dynamic>,
      );
    }
    final err = json.decode(response.body);
    if (err is Map && err.containsKey('branches')) {
      throw Exception('Branches: ${(err['branches'] as List).join(', ')}');
    }
    throw Exception((err is Map ? err['detail'] : null) ?? 'Failed to assign branches');
  }

  Future<CoachDashboardData> getCoachDashboard() async {
    debugPrint('📡 CoachApi: GET /api/accounts/coach-dashboard/');
    final response = await apiClient.get('/api/accounts/coach-dashboard/', includeAuth: true);
    debugPrint('📥 CoachApi: status ${response.statusCode}');
    if (response.statusCode == 200) {
      return CoachDashboardData.fromJson(json.decode(response.body) as Map<String, dynamic>);
    }
    final err = json.decode(response.body);
    throw Exception(
      (err is Map ? err['detail'] ?? err['error'] : null) ??
          'Failed to load coach dashboard (${response.statusCode})',
    );
  }

  // ── New: Student roster ─────────────────────────────────────────────────────

  Future<List<CoachStudent>> getCoachStudents({int? batchId}) async {
    final query = batchId != null ? '?batch_id=$batchId' : '';
    final response = await apiClient.get('/api/accounts/coach/students/$query', includeAuth: true);
    if (response.statusCode == 200) {
      return (json.decode(response.body) as List)
          .map((j) => CoachStudent.fromJson(j as Map<String, dynamic>))
          .toList();
    }
    final err = json.decode(response.body);
    throw Exception((err is Map ? err['error'] ?? err['detail'] : null) ?? 'Failed to load students');
  }

  // ── New: Attendance marking ─────────────────────────────────────────────────

  Future<Map<String, dynamic>> markAttendance({
    required int batchId,
    required String date,
    required List<Map<String, dynamic>> records,
  }) async {
    final response = await apiClient.post(
      '/api/accounts/coach/attendance/',
      {'batch_id': batchId, 'date': date, 'records': records},
      includeAuth: true,
    );
    if (response.statusCode == 201) {
      return json.decode(response.body) as Map<String, dynamic>;
    }
    final err = json.decode(response.body);
    throw Exception((err is Map ? err['error'] ?? err['detail'] : null) ?? 'Failed to mark attendance');
  }

  // ── New: DUPR ratings ───────────────────────────────────────────────────────

  Future<List<StudentRatingItem>> getStudentRatings({int? sportId, int? batchId}) async {
    final params = <String>[];
    if (sportId != null) params.add('sport_id=$sportId');
    if (batchId != null) params.add('batch_id=$batchId');
    final query = params.isNotEmpty ? '?${params.join('&')}' : '';
    final response = await apiClient.get('/api/ratings/students/$query', includeAuth: true);
    if (response.statusCode == 200) {
      return (json.decode(response.body) as List)
          .map((j) => StudentRatingItem.fromJson(j as Map<String, dynamic>))
          .toList();
    }
    final err = json.decode(response.body);
    throw Exception((err is Map ? err['error'] ?? err['detail'] : null) ?? 'Failed to load ratings');
  }

  // ── New: Submit match (triggers DUPR recalc) ────────────────────────────────

  Future<MatchResult> submitMatch(Map<String, dynamic> payload) async {
    final response = await apiClient.post('/api/ratings/matches/', payload, includeAuth: true);
    if (response.statusCode == 201) {
      return MatchResult.fromJson(json.decode(response.body) as Map<String, dynamic>);
    }
    final err = json.decode(response.body);
    throw Exception((err is Map ? err['error'] ?? err['detail'] : null) ?? 'Failed to submit match');
  }

  // ── New: Match history ──────────────────────────────────────────────────────

  Future<List<MatchHistoryItem>> getMyMatches() async {
    final response = await apiClient.get('/api/ratings/matches/list/', includeAuth: true);
    if (response.statusCode == 200) {
      return (json.decode(response.body) as List)
          .map((j) => MatchHistoryItem.fromJson(j as Map<String, dynamic>))
          .toList();
    }
    final err = json.decode(response.body);
    throw Exception((err is Map ? err['error'] ?? err['detail'] : null) ?? 'Failed to load match history');
  }

  // ── New: Forecast (simulate rating change before match) ─────────────────────

  Future<Map<String, dynamic>> forecastMatch({
    required int player1Id,
    required int player2Id,
    String format = 'SINGLES',
    String importance = 'CASUAL',
  }) async {
    final response = await apiClient.post(
      '/api/ratings/forecast/',
      {
        'player1_id': player1Id,
        'player2_id': player2Id,
        'format': format,
        'importance': importance,
      },
      includeAuth: true,
    );
    if (response.statusCode == 200) {
      return json.decode(response.body) as Map<String, dynamic>;
    }
    final err = json.decode(response.body);
    throw Exception((err is Map ? err['error'] ?? err['detail'] : null) ?? 'Forecast failed');
  }

  // ── New: My rating audit history (for students) ─────────────────────────────

  Future<List<Map<String, dynamic>>> getMyRatingHistory() async {
    final response = await apiClient.get('/api/ratings/my-history/', includeAuth: true);
    if (response.statusCode == 200) {
      return (json.decode(response.body) as List)
          .map((j) => j as Map<String, dynamic>)
          .toList();
    }
    final err = json.decode(response.body);
    throw Exception((err is Map ? err['error'] ?? err['detail'] : null) ?? 'Failed to load rating history');
  }
}

final coachApi = CoachApi(apiClient);

