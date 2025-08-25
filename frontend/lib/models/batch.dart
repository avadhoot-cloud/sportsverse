// sportsverse/frontend/sportsverse_app/lib/models/batch.dart

class Batch {
  final int id;
  final String name;
  final int branchId;
  final int sportId;
  final Map<String, dynamic> scheduleDetails;
  final int maxStudents;
  final bool isActive;
  final String organizationName;
  final String branchName;
  final String sportName;

  Batch({
    required this.id,
    required this.name,
    required this.branchId,
    required this.sportId,
    required this.scheduleDetails,
    required this.maxStudents,
    required this.isActive,
    required this.organizationName,
    required this.branchName,
    required this.sportName,
  });

  factory Batch.fromJson(Map<String, dynamic> json) {
    return Batch(
      id: json['id'],
      name: json['name'],
      branchId: json['branch'],
      sportId: json['sport'],
      scheduleDetails: Map<String, dynamic>.from(json['schedule_details']),
      maxStudents: json['max_students'],
      isActive: json['is_active'],
      organizationName: json['organization_name'] ?? '',
      branchName: json['branch_name'] ?? '',
      sportName: json['sport_name'] ?? '',
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'branch': branchId,
      'sport': sportId,
      'schedule_details': scheduleDetails,
      'max_students': maxStudents,
      'is_active': isActive,
    };
  }

  // Helper methods for schedule display
  List<String> get scheduleDays {
    if (scheduleDetails['days'] is List) {
      return List<String>.from(scheduleDetails['days']);
    }
    return [];
  }

  String get scheduleTime {
    final startTime = scheduleDetails['start_time'] ?? '';
    final endTime = scheduleDetails['end_time'] ?? '';
    if (startTime.isNotEmpty && endTime.isNotEmpty) {
      return '$startTime - $endTime';
    }
    return '';
  }

  String get scheduleDisplay {
    final days = scheduleDays.join(', ');
    final time = scheduleTime;
    if (days.isNotEmpty && time.isNotEmpty) {
      return '$days: $time';
    }
    return 'No schedule set';
  }
}

class Enrollment {
  final int id;
  final int studentId;
  final int batchId;
  final String enrollmentType;
  final DateTime? startDate;
  final DateTime? endDate;
  final int? totalSessions;
  final int sessionsAttended;
  final bool isActive;
  final DateTime dateEnrolled;
  final bool enrollmentStarted;
  final DateTime? dateFirstAttendance;
  final String studentName;
  final String studentLastName;
  final String batchName;
  final String? branchName;
  final String organizationName;
  final String? enrollmentStatus;
  final String? progressDisplay;

  Enrollment({
    required this.id,
    required this.studentId,
    required this.batchId,
    required this.enrollmentType,
    this.startDate,
    this.endDate,
    this.totalSessions,
    required this.sessionsAttended,
    required this.isActive,
    required this.dateEnrolled,
    required this.enrollmentStarted,
    this.dateFirstAttendance,
    required this.studentName,
    required this.studentLastName,
    required this.batchName,
    this.branchName,
    required this.organizationName,
    this.enrollmentStatus,
    this.progressDisplay,
  });

  factory Enrollment.fromJson(Map<String, dynamic> json) {
    return Enrollment(
      id: json['id'],
      studentId: json['student'],
      batchId: json['batch'],
      enrollmentType: json['enrollment_type'],
      startDate: json['start_date'] != null
          ? DateTime.parse(json['start_date'])
          : null,
      endDate: json['end_date'] != null
          ? DateTime.parse(json['end_date'])
          : null,
      totalSessions: json['total_sessions'],
      sessionsAttended: json['sessions_attended'],
      isActive: json['is_active'],
      dateEnrolled: DateTime.parse(json['date_enrolled']),
      enrollmentStarted: json['enrollment_started'] ?? false,
      dateFirstAttendance: json['date_first_attendance'] != null
          ? DateTime.parse(json['date_first_attendance'])
          : null,
      studentName: json['student_name'] ?? '',
      studentLastName: json['student_last_name'] ?? '',
      batchName: json['batch_name'] ?? '',
      branchName: json['branch_name'],
      organizationName: json['organization_name'] ?? '',
      enrollmentStatus: json['enrollment_status'],
      progressDisplay: json['progress_display'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'student': studentId,
      'batch': batchId,
      'enrollment_type': enrollmentType,
      'start_date': startDate?.toIso8601String().split('T')[0],
      'end_date': endDate?.toIso8601String().split('T')[0],
      'total_sessions': totalSessions,
      'is_active': isActive,
    };
  }

  String get fullStudentName => '$studentName $studentLastName'.trim();

  String get enrollmentTypeDisplay {
    switch (enrollmentType) {
      case 'SESSION_BASED':
        return 'Session Based';
      case 'DURATION_BASED':
        return 'Duration Based';
      default:
        return enrollmentType;
    }
  }
}
