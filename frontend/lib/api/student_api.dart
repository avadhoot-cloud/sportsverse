import 'package:sportsverse_app/api/api_client.dart';
import 'package:sportsverse_app/models/student_models.dart';
import 'dart:convert';

class StudentApi {
  static const String _basePath = '/api/student';

  // Get student dashboard data
  static Future<StudentDashboardData> getDashboardData() async {
    try {
      final response = await apiClient.get('$_basePath/dashboard/');
      
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return StudentDashboardData.fromJson(data);
      } else {
        throw Exception('Failed to load dashboard data: ${response.statusCode}');
      }
    } catch (e) {
      throw Exception('Error loading dashboard data: $e');
    }
  }

  // Get student enrollments
  static Future<List<StudentEnrollment>> getEnrollments({
    String? status,
    int? batchId,
    int? limit,
    int? offset,
  }) async {
    try {
      String url = '$_basePath/enrollments/';
      List<String> queryParams = [];
      
      if (status != null) queryParams.add('status=$status');
      if (batchId != null) queryParams.add('batch=$batchId');
      if (limit != null) queryParams.add('limit=$limit');
      if (offset != null) queryParams.add('offset=$offset');
      
      if (queryParams.isNotEmpty) {
        url += '?${queryParams.join('&')}';
      }

      final response = await apiClient.get(url);
      
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final List<dynamic> enrollments = data is List ? data : (data['results'] ?? []);
        return enrollments.map((e) => StudentEnrollment.fromJson(e)).toList();
      } else {
        throw Exception('Failed to load enrollments: ${response.statusCode}');
      }
    } catch (e) {
      throw Exception('Error loading enrollments: $e');
    }
  }

  // Get student attendance records
  static Future<List<StudentAttendance>> getAttendance({
    int? enrollmentId,
    int? batchId,
    DateTime? startDate,
    DateTime? endDate,
    int? limit,
    int? offset,
  }) async {
    try {
      String url = '$_basePath/attendance/';
      List<String> queryParams = [];
      
      if (enrollmentId != null) queryParams.add('enrollment=$enrollmentId');
      if (batchId != null) queryParams.add('batch=$batchId');
      if (startDate != null) queryParams.add('start_date=${startDate.toIso8601String().split('T')[0]}');
      if (endDate != null) queryParams.add('end_date=${endDate.toIso8601String().split('T')[0]}');
      if (limit != null) queryParams.add('limit=$limit');
      if (offset != null) queryParams.add('offset=$offset');
      
      if (queryParams.isNotEmpty) {
        url += '?${queryParams.join('&')}';
      }

      final response = await apiClient.get(url);
      
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final List<dynamic> attendance = data is List ? data : (data['results'] ?? []);
        return attendance.map((e) => StudentAttendance.fromJson(e)).toList();
      } else {
        throw Exception('Failed to load attendance: ${response.statusCode}');
      }
    } catch (e) {
      throw Exception('Error loading attendance: $e');
    }
  }

  // Get student payment records
  static Future<List<StudentPayment>> getPayments({
    int? enrollmentId,
    bool? isPaid,
    int? limit,
    int? offset,
  }) async {
    try {
      String url = '$_basePath/payments/';
      List<String> queryParams = [];
      
      if (enrollmentId != null) queryParams.add('enrollment=$enrollmentId');
      if (isPaid != null) queryParams.add('is_paid=$isPaid');
      if (limit != null) queryParams.add('limit=$limit');
      if (offset != null) queryParams.add('offset=$offset');
      
      if (queryParams.isNotEmpty) {
        url += '?${queryParams.join('&')}';
      }

      final response = await apiClient.get(url);
      
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final List<dynamic> payments = data is List ? data : (data['results'] ?? []);
        return payments.map((e) => StudentPayment.fromJson(e)).toList();
      } else {
        throw Exception('Failed to load payments: ${response.statusCode}');
      }
    } catch (e) {
      throw Exception('Error loading payments: $e');
    }
  }

  // Process payment
  static Future<Map<String, dynamic>> processPayment({
    required int enrollmentId,
    required double amount,
    String? paymentMethod,
    String? transactionId,
  }) async {
    try {
      final payload = {
        'enrollment': enrollmentId,
        'amount': amount,
        'payment_method': paymentMethod ?? 'online',
        'transaction_id': transactionId,
      };

      final response = await apiClient.post(
        '$_basePath/payments/process/',
        payload,
        includeAuth: true,
      );
      
      if (response.statusCode == 200 || response.statusCode == 201) {
        return jsonDecode(response.body);
      } else {
        throw Exception('Failed to process payment: ${response.statusCode}');
      }
    } catch (e) {
      throw Exception('Error processing payment: $e');
    }
  }

  // Get attendance summary
  static Future<Map<String, dynamic>> getAttendanceSummary() async {
    try {
      final response = await apiClient.get('$_basePath/attendance/summary/');
      
      if (response.statusCode == 200) {
        return jsonDecode(response.body);
      } else {
        throw Exception('Failed to load attendance summary: ${response.statusCode}');
      }
    } catch (e) {
      throw Exception('Error loading attendance summary: $e');
    }
  }

  // Get payment summary
  static Future<Map<String, dynamic>> getPaymentSummary() async {
    try {
      final response = await apiClient.get('$_basePath/payments/summary/');
      
      if (response.statusCode == 200) {
        return jsonDecode(response.body);
      } else {
        throw Exception('Failed to load payment summary: ${response.statusCode}');
      }
    } catch (e) {
      throw Exception('Error loading payment summary: $e');
    }
  }

  // Get staff list associated with student's academy/batches
  static Future<List<dynamic>> getStaffList() async {
    try {
      final response = await apiClient.get('$_basePath/staff/');
      
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return data is List ? data : (data['results'] ?? []);
      } else {
        throw Exception('Failed to load staff list: ${response.statusCode}');
      }
    } catch (e) {
      throw Exception('Error loading staff list: $e');
    }
  }

  // Get enrollment details
  static Future<StudentEnrollment> getEnrollmentDetails(int enrollmentId) async {
    try {
      final response = await apiClient.get('$_basePath/enrollments/$enrollmentId/');
      
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return StudentEnrollment.fromJson(data);
      } else {
        throw Exception('Failed to load enrollment details: ${response.statusCode}');
      }
    } catch (e) {
      throw Exception('Error loading enrollment details: $e');
    }
  }

  // Get attendance by enrollment
  static Future<List<StudentAttendance>> getAttendanceByEnrollment(int enrollmentId) async {
    try {
      final response = await apiClient.get('$_basePath/attendance/?enrollment=$enrollmentId');
      
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final List<dynamic> attendance = data is List ? data : (data['results'] ?? []);
        return attendance.map((e) => StudentAttendance.fromJson(e)).toList();
      } else {
        throw Exception('Failed to load attendance for enrollment: ${response.statusCode}');
      }
    } catch (e) {
      throw Exception('Error loading attendance for enrollment: $e');
    }
  }

  // Get student profile
  static Future<Map<String, dynamic>> getProfile() async {
    try {
      final response = await apiClient.get('$_basePath/profile/');
      
      if (response.statusCode == 200) {
        return jsonDecode(response.body);
      } else {
        throw Exception('Failed to load profile: ${response.statusCode}');
      }
    } catch (e) {
      throw Exception('Error loading profile: $e');
    }
  }

  // Update student profile
  static Future<Map<String, dynamic>> updateProfile(Map<String, dynamic> profileData) async {
    try {
      print('📝 Sending profile update request: $profileData');
      final response = await apiClient.put('$_basePath/profile/', profileData);
      
      print('📝 Profile update response status: ${response.statusCode}');
      print('📝 Profile update response body: ${response.body}');
      
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        print('📝 Profile update successful: $data');
        return data;
      } else {
        print('📝 Profile update failed with status: ${response.statusCode}');
        print('📝 Error body: ${response.body}');
        throw Exception('Failed to update profile: ${response.statusCode}');
      }
    } catch (e) {
      print('📝 Profile update error: $e');
      throw Exception('Error updating profile: $e');
    }
  }

  // Upload profile photo
  static Future<String> uploadProfilePhoto(String imagePath) async {
    try {
      print('📸 Starting photo upload for: $imagePath');
      final response = await apiClient.uploadFile('$_basePath/profile/photo/', imagePath);
      
      print('📸 Upload response status: ${response.statusCode}');
      print('📸 Upload response body: ${response.body}');
      
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        print('📸 Upload successful, profile_photo: ${data['profile_photo']}');
        return data['profile_photo'] ?? '';
      } else {
        print('📸 Upload failed with status: ${response.statusCode}');
        print('📸 Error body: ${response.body}');
        throw Exception('Failed to upload photo: ${response.statusCode}');
      }
    } catch (e) {
      print('📸 Upload error: $e');
      throw Exception('Error uploading photo: $e');
    }
  }

  // Debug profile data
  static Future<Map<String, dynamic>> debugProfile() async {
    try {
      print('🔍 Getting debug profile data...');
      final response = await apiClient.get('$_basePath/profile/debug/');
      
      print('🔍 Debug response status: ${response.statusCode}');
      print('🔍 Debug response body: ${response.body}');
      
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        print('🔍 Debug data received: $data');
        return data;
      } else {
        print('🔍 Debug failed with status: ${response.statusCode}');
        throw Exception('Failed to get debug data: ${response.statusCode}');
      }
    } catch (e) {
      print('🔍 Debug error: $e');
      throw Exception('Error getting debug data: $e');
    }
  }

  // Upload face image for encoding
  static Future<Map<String, dynamic>> uploadFaceForEncoding(String imagePath) async {
    try {
      print('🔍 Starting face encoding upload for: $imagePath');
      
      // Use custom upload method with correct field name
      final response = await apiClient.uploadFileWithFieldName('$_basePath/face-encoding/', imagePath, 'face_image');
      
      print('🔍 Face encoding response status: ${response.statusCode}');
      print('🔍 Face encoding response body: ${response.body}');
      
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        print('🔍 Face encoding successful: $data');
        return data;
      } else {
        print('🔍 Face encoding failed with status: ${response.statusCode}');
        print('🔍 Error body: ${response.body}');
        throw Exception('Failed to upload face for encoding: ${response.statusCode}');
      }
    } catch (e) {
      print('🔍 Face encoding error: $e');
      throw Exception('Error uploading face for encoding: $e');
    }
  }
}