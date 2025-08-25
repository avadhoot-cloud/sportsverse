// sportsverse/frontend/sportsverse_app/lib/api/batch_api.dart

import 'dart:convert';
import 'package:sportsverse_app/api/api_client.dart';
import 'package:sportsverse_app/models/batch.dart';

class BatchApi {
  final ApiClient apiClient;

  BatchApi(this.apiClient);

  /// Get all batches for the logged-in academy admin
  Future<List<Batch>> getBatches() async {
    final response = await apiClient.get(
      '/organizations/batches/',
      includeAuth: true,
    );

    if (response.statusCode == 200) {
      final List<dynamic> batchesJson = json.decode(response.body);
      return batchesJson.map((json) => Batch.fromJson(json)).toList();
    } else {
      final errorData = json.decode(response.body);
      throw Exception(errorData['detail'] ?? 'Failed to load batches');
    }
  }

  /// Create a new batch
  Future<Batch> createBatch({
    required String name,
    required int branchId,
    required int sportId,
    required Map<String, dynamic> scheduleDetails,
    int maxStudents = 20,
    bool isActive = true,
  }) async {
    final batchData = {
      'name': name,
      'branch': branchId,
      'sport': sportId,
      'schedule_details': scheduleDetails,
      'max_students': maxStudents,
      'is_active': isActive,
    };

    final response = await apiClient.post(
      '/organizations/batches/',
      batchData,
      includeAuth: true,
    );

    if (response.statusCode == 201) {
      return Batch.fromJson(json.decode(response.body));
    } else {
      final errorData = json.decode(response.body);

      // Handle validation errors
      if (errorData.containsKey('name')) {
        throw Exception('Name: ${errorData['name'].join(', ')}');
      } else if (errorData.containsKey('branch')) {
        throw Exception('Branch: ${errorData['branch'].join(', ')}');
      } else if (errorData.containsKey('sport')) {
        throw Exception('Sport: ${errorData['sport'].join(', ')}');
      } else if (errorData.containsKey('schedule_details')) {
        throw Exception(
          'Schedule: ${errorData['schedule_details'].join(', ')}',
        );
      } else if (errorData.containsKey('detail')) {
        throw Exception(errorData['detail']);
      } else {
        throw Exception('Failed to create batch');
      }
    }
  }

  /// Update an existing batch
  Future<Batch> updateBatch({
    required int batchId,
    required String name,
    required int branchId,
    required int sportId,
    required Map<String, dynamic> scheduleDetails,
    required int maxStudents,
    required bool isActive,
  }) async {
    final batchData = {
      'name': name,
      'branch': branchId,
      'sport': sportId,
      'schedule_details': scheduleDetails,
      'max_students': maxStudents,
      'is_active': isActive,
    };

    final response = await apiClient.put(
      '/organizations/batches/$batchId/',
      batchData,
      includeAuth: true,
    );

    if (response.statusCode == 200) {
      return Batch.fromJson(json.decode(response.body));
    } else {
      final errorData = json.decode(response.body);

      // Handle validation errors
      if (errorData.containsKey('name')) {
        throw Exception('Name: ${errorData['name'].join(', ')}');
      } else if (errorData.containsKey('branch')) {
        throw Exception('Branch: ${errorData['branch'].join(', ')}');
      } else if (errorData.containsKey('sport')) {
        throw Exception('Sport: ${errorData['sport'].join(', ')}');
      } else if (errorData.containsKey('schedule_details')) {
        throw Exception(
          'Schedule: ${errorData['schedule_details'].join(', ')}',
        );
      } else if (errorData.containsKey('detail')) {
        throw Exception(errorData['detail']);
      } else {
        throw Exception('Failed to update batch');
      }
    }
  }

  /// Delete a batch
  Future<void> deleteBatch(int batchId) async {
    final response = await apiClient.delete(
      '/organizations/batches/$batchId/',
      includeAuth: true,
    );

    if (response.statusCode != 204) {
      final errorData = json.decode(response.body);
      throw Exception(errorData['detail'] ?? 'Failed to delete batch');
    }
  }

  /// Get a specific batch
  Future<Batch> getBatch(int batchId) async {
    final response = await apiClient.get(
      '/organizations/batches/$batchId/',
      includeAuth: true,
    );

    if (response.statusCode == 200) {
      return Batch.fromJson(json.decode(response.body));
    } else {
      final errorData = json.decode(response.body);
      throw Exception(errorData['detail'] ?? 'Failed to load batch');
    }
  }

  /// Get enrollments for the academy
  Future<List<Enrollment>> getEnrollments({
    int? batchId,
    int? studentId,
  }) async {
    String endpoint = '/organizations/enrollments/';
    List<String> queryParams = [];

    if (batchId != null) {
      queryParams.add('batch=$batchId');
    }
    if (studentId != null) {
      queryParams.add('student=$studentId');
    }

    if (queryParams.isNotEmpty) {
      endpoint += '?${queryParams.join('&')}';
    }

    final response = await apiClient.get(endpoint, includeAuth: true);

    if (response.statusCode == 200) {
      final List<dynamic> enrollmentsJson = json.decode(response.body);
      return enrollmentsJson.map((json) => Enrollment.fromJson(json)).toList();
    } else {
      final errorData = json.decode(response.body);
      throw Exception(errorData['detail'] ?? 'Failed to load enrollments');
    }
  }

  /// Enroll a student in a batch
  Future<Enrollment> enrollStudent({
    required int studentId,
    required int batchId,
    required String enrollmentType,
    required DateTime startDate,
    DateTime? endDate,
    int? totalSessions,
  }) async {
    final enrollmentData = {
      'student': studentId,
      'batch': batchId,
      'enrollment_type': enrollmentType,
      'start_date': startDate.toIso8601String().split('T')[0],
      'is_active': true,
    };

    if (endDate != null) {
      enrollmentData['end_date'] = endDate.toIso8601String().split('T')[0];
    }
    if (totalSessions != null) {
      enrollmentData['total_sessions'] = totalSessions;
    }

    final response = await apiClient.post(
      '/organizations/enrollments/',
      enrollmentData,
      includeAuth: true,
    );

    if (response.statusCode == 201) {
      return Enrollment.fromJson(json.decode(response.body));
    } else {
      final errorData = json.decode(response.body);

      // Handle validation errors
      if (errorData.containsKey('student')) {
        throw Exception('Student: ${errorData['student'].join(', ')}');
      } else if (errorData.containsKey('batch')) {
        throw Exception('Batch: ${errorData['batch'].join(', ')}');
      } else if (errorData.containsKey('non_field_errors')) {
        throw Exception(errorData['non_field_errors'].join(', '));
      } else if (errorData.containsKey('detail')) {
        throw Exception(errorData['detail']);
      } else {
        throw Exception('Failed to enroll student');
      }
    }
  }

  /// Update an enrollment
  Future<Enrollment> updateEnrollment({
    required int enrollmentId,
    required int studentId,
    required int batchId,
    required String enrollmentType,
    required DateTime startDate,
    DateTime? endDate,
    int? totalSessions,
    required bool isActive,
  }) async {
    final enrollmentData = {
      'student': studentId,
      'batch': batchId,
      'enrollment_type': enrollmentType,
      'start_date': startDate.toIso8601String().split('T')[0],
      'is_active': isActive,
    };

    if (endDate != null) {
      enrollmentData['end_date'] = endDate.toIso8601String().split('T')[0];
    }
    if (totalSessions != null) {
      enrollmentData['total_sessions'] = totalSessions;
    }

    final response = await apiClient.put(
      '/organizations/enrollments/$enrollmentId/',
      enrollmentData,
      includeAuth: true,
    );

    if (response.statusCode == 200) {
      return Enrollment.fromJson(json.decode(response.body));
    } else {
      final errorData = json.decode(response.body);
      throw Exception(errorData['detail'] ?? 'Failed to update enrollment');
    }
  }

  /// Delete an enrollment
  Future<void> deleteEnrollment(int enrollmentId) async {
    final response = await apiClient.delete(
      '/organizations/enrollments/$enrollmentId/',
      includeAuth: true,
    );

    if (response.statusCode != 204) {
      final errorData = json.decode(response.body);
      throw Exception(errorData['detail'] ?? 'Failed to delete enrollment');
    }
  }

  /// Create student with enrollment in one step
  Future<Map<String, dynamic>> createStudentEnrollment(
    Map<String, dynamic> studentEnrollmentData,
  ) async {
    final response = await apiClient.post(
      '/organizations/student-enrollments/',
      studentEnrollmentData,
      includeAuth: true,
    );

    if (response.statusCode == 201) {
      return json.decode(response.body);
    } else {
      final errorData = json.decode(response.body);

      // Handle validation errors
      if (errorData.containsKey('non_field_errors')) {
        throw Exception(errorData['non_field_errors'].join(', '));
      } else if (errorData.containsKey('first_name')) {
        throw Exception('First name: ${errorData['first_name'].join(', ')}');
      } else if (errorData.containsKey('last_name')) {
        throw Exception('Last name: ${errorData['last_name'].join(', ')}');
      } else if (errorData.containsKey('email')) {
        throw Exception('Email: ${errorData['email'].join(', ')}');
      } else if (errorData.containsKey('date_of_birth')) {
        throw Exception(
          'Date of birth: ${errorData['date_of_birth'].join(', ')}',
        );
      } else if (errorData.containsKey('batch')) {
        throw Exception('Batch: ${errorData['batch'].join(', ')}');
      } else if (errorData.containsKey('enrollment_type')) {
        throw Exception(
          'Enrollment type: ${errorData['enrollment_type'].join(', ')}',
        );
      } else if (errorData.containsKey('total_sessions')) {
        throw Exception(
          'Total sessions: ${errorData['total_sessions'].join(', ')}',
        );
      } else if (errorData.containsKey('detail')) {
        throw Exception(errorData['detail']);
      } else {
        throw Exception('Failed to create student enrollment');
      }
    }
  }
}

final batchApi = BatchApi(apiClient); // Global instance
