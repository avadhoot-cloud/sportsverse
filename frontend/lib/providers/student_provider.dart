import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:sportsverse_app/api/student_api.dart';
import 'package:sportsverse_app/models/student_models.dart';

// Dynamically mapped Staff model - No more hardcoded names
class StaffMember {
  final String id;
  final String name;
  final String? role;
  
  StaffMember({required this.id, required this.name, this.role});

  factory StaffMember.fromJson(Map<String, dynamic> json) {
    return StaffMember(
      id: json['id'].toString(),
      name: json['full_name'] ?? 'Staff',
      role: json['role'] ?? 'Coach',
    );
  }
}

class StudentProvider with ChangeNotifier {
  // --- State Variables ---
  bool _isLoading = false;
  String? _error; 

  // Dashboard data
  StudentDashboardData? _dashboardData;
  
  // Staff & Enrollments
  List<StaffMember> _staffList = [];
  List<StudentEnrollment> _currentEnrollments = [];
  List<StudentEnrollment> _previousEnrollments = [];
  
  // Attendance
  List<StudentAttendance> _attendanceRecords = [];
  Map<int, List<StudentAttendance>> _attendanceByEnrollment = {};

  // Payments
  List<StudentPayment> _payments = [];
  Map<String, dynamic> _paymentSummary = {};
  Map<String, dynamic> _attendanceSummary = {};

  // --- Getters ---
  bool get isLoading => _isLoading;
  String? get error => _error;
  
  List<StaffMember> get staffList => _staffList;
  StudentDashboardData? get dashboardData => _dashboardData;
  List<StudentEnrollment> get currentEnrollments => _currentEnrollments;
  List<StudentEnrollment> get previousEnrollments => _previousEnrollments;
  List<StudentAttendance> get attendanceRecords => _attendanceRecords;
  Map<int, List<StudentAttendance>> get attendanceByEnrollment => _attendanceByEnrollment;
  List<StudentPayment> get payments => _payments;
  Map<String, dynamic> get paymentSummary => _paymentSummary;
  Map<String, dynamic> get attendanceSummary => _attendanceSummary;

  // --- State Helpers ---
  void _setError(String? error) {
    _error = error;
    notifyListeners();
  }

  void clearError() {
    _error = null;
    notifyListeners();
  }

  void _setLoading(bool loading) {
    _isLoading = loading;
    notifyListeners();
  }

  // --- Dynamic Data Methods ---

  /// Fetches real staff from the organization folder dynamically
  Future<void> fetchStaffList() async {
    try {
      final List<dynamic> data = await StudentApi.getStaffList();
      _staffList = data.map((item) => StaffMember.fromJson(item)).toList();
      notifyListeners();
    } catch (e) {
      _setError("Failed to load staff: ${e.toString()}");
    }
  }

  Future<void> loadDashboardData() async {
    _setLoading(true);
    _setError(null);
    try {
      _dashboardData = await StudentApi.getDashboardData();
      if (_dashboardData != null) {
        _currentEnrollments = _dashboardData!.currentEnrollments;
        _previousEnrollments = _dashboardData!.previousEnrollments;
        _attendanceRecords = _dashboardData!.recentAttendance;
      }
    } catch (e) {
      _setError(e.toString());
    } finally {
      _setLoading(false);
    }
  }

  Future<void> loadEnrollments({String? status}) async {
    _setLoading(true);
    _setError(null);
    try {
      final enrollments = await StudentApi.getEnrollments(status: status);
      if (status == 'active' || status == null) {
        _currentEnrollments = enrollments.where((e) => e.isActive).toList();
      } else if (status == 'completed') {
        _previousEnrollments = enrollments.where((e) => !e.isActive).toList();
      }
    } catch (e) {
      _setError(e.toString());
    } finally {
      _setLoading(false);
    }
  }

  Future<void> loadAttendance({
    int? enrollmentId,
    DateTime? startDate,
    DateTime? endDate,
  }) async {
    _setLoading(true);
    _setError(null);
    try {
      final attendance = await StudentApi.getAttendance(
        enrollmentId: enrollmentId,
        startDate: startDate,
        endDate: endDate,
      );
      _attendanceRecords = attendance;
      _attendanceByEnrollment.clear();
      for (var record in attendance) {
        if (!_attendanceByEnrollment.containsKey(record.enrollmentId)) {
          _attendanceByEnrollment[record.enrollmentId] = [];
        }
        _attendanceByEnrollment[record.enrollmentId]!.add(record);
      }
    } catch (e) {
      _setError(e.toString());
    } finally {
      _setLoading(false);
    }
  }

  Future<void> loadPayments({int? enrollmentId}) async {
    _setLoading(true);
    _setError(null);
    try {
      _payments = await StudentApi.getPayments(enrollmentId: enrollmentId);
    } catch (e) {
      _setError(e.toString());
    } finally {
      _setLoading(false);
    }
  }

  Future<void> loadPaymentSummary() async {
    _setLoading(true);
    _setError(null);
    try {
      _paymentSummary = await StudentApi.getPaymentSummary();
    } catch (e) {
      _setError(e.toString());
    } finally {
      _setLoading(false);
    }
  }

  Future<void> loadAttendanceSummary() async {
    _setLoading(true);
    _setError(null);
    try {
      // This is now dynamic and fetches from your Organizations backend
      _attendanceSummary = await StudentApi.getAttendanceSummary();
    } catch (e) {
      _setError(e.toString());
    } finally {
      _setLoading(false);
    }
  }

  Future<bool> processPayment({
    required int enrollmentId,
    required double amount,
    String? paymentMethod,
    String? transactionId,
  }) async {
    _setLoading(true);
    _setError(null);
    try {
      await StudentApi.processPayment(
        enrollmentId: enrollmentId,
        amount: amount,
        paymentMethod: paymentMethod,
        transactionId: transactionId,
      );
      await loadPayments();
      await loadPaymentSummary();
      return true;
    } catch (e) {
      _setError(e.toString());
      return false;
    } finally {
      _setLoading(false);
    }
  }

  // --- Utility Methods (RESTORED) ---

  List<StudentAttendance> getAttendanceForEnrollment(int enrollmentId) {
    return _attendanceByEnrollment[enrollmentId] ?? [];
  }

  List<StudentPayment> getPaymentsForEnrollment(int enrollmentId) {
    return _payments.where((p) => p.enrollmentId == enrollmentId).toList();
  }

  bool hasPendingPayments(int enrollmentId) {
    return _payments.any((p) => p.enrollmentId == enrollmentId && !p.isPaid);
  }

  double calculateEnrollmentAmount(int enrollmentId) {
    return _payments
        .where((p) => p.enrollmentId == enrollmentId)
        .fold(0.0, (sum, p) => sum + p.amount);
  }

  double calculatePaidAmount(int enrollmentId) {
    return _payments
        .where((p) => p.enrollmentId == enrollmentId && p.isPaid)
        .fold(0.0, (sum, p) => sum + p.amount);
  }

  double calculatePendingAmount(int enrollmentId) {
    return calculateEnrollmentAmount(enrollmentId) - calculatePaidAmount(enrollmentId);
  }

  double getAttendancePercentage(int enrollmentId) {
    final attendance = getAttendanceForEnrollment(enrollmentId);
    if (attendance.isEmpty) return 0.0;
    final presentCount = attendance.where((a) => a.isPresent).length;
    return (presentCount / attendance.length) * 100;
  }

  Future<void> refreshAll() async {
    await Future.wait([
      loadDashboardData(),
      loadAttendanceSummary(),
      loadPaymentSummary(),
      fetchStaffList(),
    ]);
  }

  void clearAll() {
    _dashboardData = null;
    _currentEnrollments.clear();
    _previousEnrollments.clear();
    _attendanceRecords.clear();
    _attendanceByEnrollment.clear();
    _staffList.clear();
    _payments.clear();
    _paymentSummary.clear();
    _attendanceSummary.clear();
    _error = null;
    notifyListeners();
  }
}