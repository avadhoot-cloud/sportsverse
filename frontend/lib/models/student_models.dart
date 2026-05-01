class StudentEnrollment {
  final int id;
  final int studentId;
  final int batchId;
  final String enrollmentType;
  final DateTime? startDate;
  final DateTime? endDate;
  final int? totalSessions;
  final int sessionsAttended;
  final bool isActive;
  final bool enrollmentStarted;
  final DateTime dateEnrolled;
  final DateTime? dateFirstAttendance;
  final String enrollmentStatus;
  final String progressDisplay;
  final String studentName;
  final String studentLastName;
  final String batchName;
  final String branchName;
  final String organizationName;

  StudentEnrollment({
    required this.id,
    required this.studentId,
    required this.batchId,
    required this.enrollmentType,
    this.startDate,
    this.endDate,
    this.totalSessions,
    required this.sessionsAttended,
    required this.isActive,
    required this.enrollmentStarted,
    required this.dateEnrolled,
    this.dateFirstAttendance,
    required this.enrollmentStatus,
    required this.progressDisplay,
    required this.studentName,
    required this.studentLastName,
    required this.batchName,
    required this.branchName,
    required this.organizationName,
  });

factory StudentEnrollment.fromJson(Map<String, dynamic> json) {
  return StudentEnrollment(
    id: json['id'] ?? 0,
    studentId: json['student'] ?? 0,
    batchId: json['batch'] ?? 0,

    enrollmentType: json['enrollment_type'] ?? '',

    startDate: json['start_date'] != null
        ? DateTime.tryParse(json['start_date'])
        : null,

    endDate: json['end_date'] != null
        ? DateTime.tryParse(json['end_date'])
        : null,

    totalSessions: json['total_sessions'],

    sessionsAttended: json['sessions_attended'] ?? 0,
    isActive: json['is_active'] ?? false,
    enrollmentStarted: json['enrollment_started'] ?? false,

    // 🔥 FIX CRASH HERE
    dateEnrolled: json['date_enrolled'] != null
        ? DateTime.tryParse(json['date_enrolled']) ?? DateTime.now()
        : DateTime.now(),

    dateFirstAttendance: json['date_first_attendance'] != null
        ? DateTime.tryParse(json['date_first_attendance'])
        : null,

    enrollmentStatus: json['enrollment_status'] ?? '',

    // ✅ MATCH BACKEND KEYS
    progressDisplay: json['progress_display'] ?? '0%',

    studentName: json['student_name'] ?? '',
    studentLastName: json['student_last_name'] ?? '',

    batchName: json['batch_name'] ?? 'N/A',
    branchName: json['branch_name'] ?? 'N/A',
    organizationName: json['organization_name'] ?? '',
  );
}

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'student': studentId,
      'batch': batchId,
      'enrollment_type': enrollmentType,
      'start_date': startDate?.toIso8601String(),
      'end_date': endDate?.toIso8601String(),
      'total_sessions': totalSessions,
      'sessions_attended': sessionsAttended,
      'is_active': isActive,
      'enrollment_started': enrollmentStarted,
      'date_enrolled': dateEnrolled.toIso8601String(),
      'date_first_attendance': dateFirstAttendance?.toIso8601String(),
      'enrollment_status': enrollmentStatus,
      'progress_display': progressDisplay,
      'student_name': studentName,
      'student_last_name': studentLastName,
      'batch_name': batchName,
      'branch_name': branchName,
      'organization_name': organizationName,
    };
  }
}

class StudentAttendance {
  final int id;
  final String status; // Ensure this is named 'status'
  final int enrollmentId;
  final int batchId;
  final int studentId;
  final int organizationId;
  final DateTime date;
  final bool isPresent;
  final DateTime timestamp;

  StudentAttendance({
    required this.id,
    required this.enrollmentId,
    required this.status,
    required this.batchId,
    required this.studentId,
    required this.organizationId,
    required this.date,
    required this.isPresent,
    required this.timestamp,
  });

  factory StudentAttendance.fromJson(Map<String, dynamic> json) {
    return StudentAttendance(
      id: json['id'] ?? 0,
      status: json['status'] ?? 'unknown', // Ensure this matches backend field
      enrollmentId: json['enrollment'] ?? 0,
      batchId: json['batch'] ?? 0,
      studentId: json['student'] ?? 0,
      organizationId: json['organization'] ?? 0,
      date: DateTime.parse(json['date']),
      isPresent: json['is_present'] ?? false,
      timestamp: DateTime.parse(json['timestamp']),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'enrollment': enrollmentId,
      'batch': batchId,
      'student': studentId,
      'organization': organizationId,
      'date': date.toIso8601String().split('T')[0], // Date only
      'is_present': isPresent,
      'timestamp': timestamp.toIso8601String(),
    };
  }
}

class StudentPayment {
  final int id;
  final int organizationId;
  final int studentId;
  final int enrollmentId;
  final double amount;
  final DateTime dueDate;
  final DateTime? paidDate;
  final bool isPaid;
  final String? paymentMethod;
  final String? transactionId;
  final String? notes;

  StudentPayment({
    required this.id,
    required this.organizationId,
    required this.studentId,
    required this.enrollmentId,
    required this.amount,
    required this.dueDate,
    this.paidDate,
    required this.isPaid,
    this.paymentMethod,
    this.transactionId,
    this.notes,
  });

  factory StudentPayment.fromJson(Map<String, dynamic> json) {
    return StudentPayment(
      id: json['id'] ?? 0,
      organizationId: json['organization'] ?? 0,
      studentId: json['student'] ?? 0,
      enrollmentId: json['enrollment'] ?? 0,
      amount: (json['amount'] ?? 0).toDouble(),
      dueDate: DateTime.parse(json['due_date']),
      paidDate: json['paid_date'] != null ? DateTime.parse(json['paid_date']) : null,
      isPaid: json['is_paid'] ?? false,
      paymentMethod: json['payment_method'],
      transactionId: json['transaction_id'],
      notes: json['notes'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'organization': organizationId,
      'student': studentId,
      'enrollment': enrollmentId,
      'amount': amount,
      'due_date': dueDate.toIso8601String().split('T')[0], // Date only
      'paid_date': paidDate?.toIso8601String().split('T')[0],
      'is_paid': isPaid,
      'payment_method': paymentMethod,
      'transaction_id': transactionId,
      'notes': notes,
    };
  }
}

class StudentDashboardData {
  final String currentEnrollment;
  final int sessionsCompleted;
  final int sessionsRemaining;
  final String? branchName;        // ADD THIS LINE
  final String enrollmentCycle;
  final List<StudentEnrollment> currentEnrollments;
  final List<StudentEnrollment> previousEnrollments;
  final List<StudentAttendance> recentAttendance;
  
  // DUPR Stats
  final double duprSinglesRating;
  final double duprDoublesRating;
  final int duprMatchesSingles;
  final int duprMatchesDoubles;
  final double duprReliability;
  final Map<String, dynamic>? duprFairness;

  StudentDashboardData({
    required this.currentEnrollment,
    required this.sessionsCompleted,
    required this.sessionsRemaining,
    required this.enrollmentCycle,
    required this.branchName,
    required this.currentEnrollments,
    required this.previousEnrollments,
    required this.recentAttendance,
    required this.duprSinglesRating,
    required this.duprDoublesRating,
    required this.duprMatchesSingles,
    required this.duprMatchesDoubles,
    required this.duprReliability,
    this.duprFairness,
  });

  factory StudentDashboardData.fromJson(Map<String, dynamic> json) {
     final dupr = json['dupr'] as Map<String, dynamic>? ?? {};
    return StudentDashboardData(
      currentEnrollment: json['current_enrollment'] ?? 'No Active Enrollment',
      sessionsCompleted: json['sessions_completed'] ?? 0,
      sessionsRemaining: json['sessions_remaining'] ?? 0,
      enrollmentCycle: json['enrollment_cycle'] ?? 'N/A',
      branchName: json['branch_name'] ?? 'N/A', // ADD THIS LINE
      currentEnrollments: (json['current_enrollments'] as List<dynamic>?)
          ?.map((e) => StudentEnrollment.fromJson(e))
          .toList() ?? [],
      previousEnrollments: (json['previous_enrollments'] as List<dynamic>?)
          ?.map((e) => StudentEnrollment.fromJson(e))
          .toList() ?? [],
      recentAttendance: (json['recent_attendance'] as List<dynamic>?)
          ?.map((e) => StudentAttendance.fromJson(e))
          .toList() ?? [],
      duprSinglesRating: (dupr['singles_rating'] ?? 4.000).toDouble(),
      duprDoublesRating: (dupr['doubles_rating'] ?? 4.000).toDouble(),
      duprMatchesSingles: dupr['matches_played_singles'] ?? 0,
      duprMatchesDoubles: dupr['matches_played_doubles'] ?? 0,
      duprReliability: (dupr['reliability'] ?? 50.0).toDouble(),
      duprFairness: dupr['fairness'] as Map<String, dynamic>?,
    );
  }
}
