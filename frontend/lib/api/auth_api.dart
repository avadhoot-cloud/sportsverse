// sportsverse/frontend/sportsverse_app/lib/api/auth_api.dart

import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart'; // Added for debugPrint
import 'package:http/http.dart' as http;
import 'package:sportsverse_app/api/api_client.dart';
import 'package:sportsverse_app/models/user.dart';
import 'package:sportsverse_app/models/financials.dart';
import 'package:sportsverse_app/models/student.dart';

class AuthApi {
  final ApiClient apiClient;

  AuthApi(this.apiClient);

  Future<AuthResponse> login(String username, String password) async {
    // DEBUG: See what we are sending
    debugPrint('📡 API Request: POST /api/accounts/login/');
    debugPrint('📦 Body: {"username": "$username", "password": "..."}');

    final response = await apiClient.post('/api/accounts/login/', {
      'username': username,
      'password': password,
    }, includeAuth: false);

    // DEBUG: See what the server says
    debugPrint('📥 API Response Status: ${response.statusCode}');
    debugPrint('📥 API Response Body: ${response.body}');

    if (response.statusCode == 200) {
      final authResponse = AuthResponse.fromJson(json.decode(response.body));
      apiClient.setToken(authResponse.token); // Save token
      return authResponse;
    } else {
      final errorData = json.decode(response.body);
      
      // Look for common Django error keys
      if (errorData is Map) {
        if (errorData.containsKey('non_field_errors')) {
          throw Exception(errorData['non_field_errors'].join(', '));
        } else if (errorData.containsKey('username')) {
          throw Exception('Username error: ${errorData['username'].join(', ')}');
        } else if (errorData.containsKey('detail')) {
          throw Exception(errorData['detail']);
        }
      }
      
      throw Exception('Login failed. Please check your credentials.');
    }
  }

  Future<Organization> registerAcademy({
    required String organizationFullName,
    required String organizationAcademyName,
    required String organizationLocation,
    required String organizationMobileNumber,
    required String organizationEmailAddress,
    required String organizationSlug,
    required List<int> sportsOfferedIds,
    required String adminUsername,
    required String adminEmail,
    required String adminFirstName,
    required String adminLastName,
    required String adminPassword,
    File? academyLogoFile, // Optional logo file
  }) async {
    var requestFields = {
      'organization_full_name': organizationFullName,
      'organization_academy_name': organizationAcademyName,
      'organization_location': organizationLocation,
      'organization_mobile_number': organizationMobileNumber,
      'organization_email_address': organizationEmailAddress,
      'organization_slug': organizationSlug,
      'admin_username': adminUsername,
      'admin_email': adminEmail,
      'admin_first_name': adminFirstName,
      'admin_last_name': adminLastName,
      'admin_password': adminPassword,
    };

    // Add sports_offered_ids as individual fields for multipart
    for (int i = 0; i < sportsOfferedIds.length; i++) {
      requestFields['sports_offered_ids[$i]'] = sportsOfferedIds[i].toString();
    }

    http.MultipartFile? logoMultipartFile;
    if (academyLogoFile != null) {
      logoMultipartFile = await http.MultipartFile.fromPath(
        'academy_logo', // This must match the field name in your Django serializer/model
        academyLogoFile.path,
      );
    }

    final response = await apiClient.postMultipart(
      '/api/accounts/register-academy/',
      requestFields,
      file: logoMultipartFile,
      includeAuth: false,
    );

    if (response.statusCode == 201) {
      final responseBody = await response.stream.bytesToString();
      final responseData = json.decode(responseBody);

      // Return a minimal Organization object with the data we have
      return Organization(
        id: responseData['academy_id'],
        fullName: organizationFullName, // Use the input data
        academyName: responseData['academy_name'],
        location: organizationLocation, // Use the input data
        mobileNumber: organizationMobileNumber, // Use the input data
        emailAddress: organizationEmailAddress, // Use the input data
        slug: organizationSlug, // Use the input data
        sportsOfferedIds: sportsOfferedIds, // Use the input data
        logoUrl: null, // Logo URL not returned in registration response
      );
    } else {
      final errorBody = await response.stream.bytesToString();
      final errorData = json.decode(errorBody);
      throw Exception(
        errorData.toString(),
      ); // Handle specific errors from Django
    }
  }

  Future<User> registerCoachStudentStaff({
    required String userType,
    required String username,
    String? email,
    required String password,
    required String firstName,
    required String lastName,
    String? phoneNumber,
    String? gender,
    String? dateOfBirth, // YYYY-MM-DD
    String? parentName,
    String? parentPhoneNumber,
    String? parentEmail,
  }) async {
    final Map<String, dynamic> body = {
      'user_type': userType,
      'username': username,
      'password': password,
      'first_name': firstName,
      'last_name': lastName,
    };

    if (email != null && email.isNotEmpty) body['email'] = email;
    if (phoneNumber != null && phoneNumber.isNotEmpty)
      body['phone_number'] = phoneNumber;
    if (gender != null && gender.isNotEmpty) body['gender'] = gender;
    if (dateOfBirth != null && dateOfBirth.isNotEmpty)
      body['date_of_birth'] = dateOfBirth;
    if (parentName != null && parentName.isNotEmpty)
      body['parent_name'] = parentName;
    if (parentPhoneNumber != null && parentPhoneNumber.isNotEmpty)
      body['parent_phone_number'] = parentPhoneNumber;
    if (parentEmail != null && parentEmail.isNotEmpty)
      body['parent_email'] = parentEmail;

    final response = await apiClient.post(
      '/api/accounts/register-user/',
      body,
      includeAuth: true, // This requires an authenticated Academy Admin
    );

    if (response.statusCode == 201) {
      if (response.body.isEmpty) {
        throw Exception('Empty response from server');
      }

      try {
        final responseData = json.decode(response.body);

        if (responseData == null) {
          throw Exception('Invalid response format from server');
        }

        return User(
          id: responseData['user_id'] ?? 0,
          username: responseData['username'] ?? 'unknown',
          firstName: firstName, 
          lastName: lastName,
          email: email ?? '', 
          userType: userType,
        );
      } catch (e) {
        debugPrint('DEBUG: Error parsing registration response: $e');
        throw Exception('Failed to parse server response: $e');
      }
    } else {
      if (response.body.isEmpty) {
        throw Exception(
          'Registration failed with status ${response.statusCode}',
        );
      }

      try {
        final errorData = json.decode(response.body);

        if (errorData != null && errorData is Map<String, dynamic>) {
          String errorMessage = '';

          if (errorData.containsKey('username')) {
            errorMessage += 'Username: ${errorData['username'].join(', ')}\n';
          }
          if (errorData.containsKey('email')) {
            errorMessage += 'Email: ${errorData['email'].join(', ')}\n';
          }
          if (errorData.containsKey('password')) {
            errorMessage += 'Password: ${errorData['password'].join(', ')}\n';
          }
          if (errorData.containsKey('non_field_errors')) {
            errorMessage += errorData['non_field_errors'].join(', ');
          }
          if (errorData.containsKey('detail')) {
            errorMessage += errorData['detail'];
          }

          if (errorMessage.isEmpty) {
            errorMessage = 'Registration failed. Please check your input.';
          }

          throw Exception(errorMessage.trim());
        } else {
          throw Exception('Registration failed. Please try again.');
        }
      } catch (e) {
        throw Exception(
          'Registration failed with status ${response.statusCode}',
        );
      }
    }
  }

  Future<void> logout() async {
    apiClient.setToken(null); // Clear token
  }

  Future<List<Sport>> getSports() async {
    final response = await apiClient.get(
      '/api/organizations/sports/',
      includeAuth: false,
    ); 
    if (response.statusCode == 200) {
      List<dynamic> data = json.decode(response.body);
      return data.map((json) => Sport.fromJson(json)).toList();
    } else {
      throw Exception('Failed to load sports');
    }
  }

  Future<Map<String, dynamic>> requestPasswordReset(String email) async {
    final response = await apiClient.post('/api/accounts/password-reset/', {
      'email': email,
    }, includeAuth: false);

    if (response.statusCode == 200) {
      return json.decode(response.body);
    } else {
      final errorData = json.decode(response.body);
      throw Exception(errorData['error'] ?? 'Failed to request password reset');
    }
  }

  Future<Map<String, dynamic>> confirmPasswordReset({
    required String uid,
    required String token,
    required String newPassword,
  }) async {
    final response = await apiClient.post('/api/accounts/password-reset-confirm/', {
      'uid': uid,
      'token': token,
      'new_password': newPassword,
    }, includeAuth: false);

    if (response.statusCode == 200) {
      return json.decode(response.body);
    } else {
      final errorData = json.decode(response.body);
      throw Exception(errorData['error'] ?? 'Failed to reset password');
    }
  }

  Future<Map<String, dynamic>> changePassword(
    String currentPassword,
    String newPassword,
  ) async {
    final response = await apiClient.post('/api/accounts/change-password/', {
      'current_password': currentPassword,
      'new_password': newPassword,
    }, includeAuth: true);

    if (response.statusCode == 200) {
      return json.decode(response.body);
    } else {
      final errorData = json.decode(response.body);
      throw Exception(errorData['error'] ?? 'Failed to change password');
    }
  }

  Future<StudentFinancials> getStudentFinancials(int studentId) async {
    final response = await apiClient.get(
      '/api/accounts/students/$studentId/financials/',
      includeAuth: true,
    );

    if (response.statusCode == 200) {
      return StudentFinancials.fromJson(json.decode(response.body));
    } else {
      final errorData = json.decode(response.body);
      throw Exception(errorData['detail'] ?? 'Failed to load student financials');
    }
  }

  Future<List<Student>> getStudents() async {
    final response = await apiClient.get(
      '/api/accounts/students/',
      includeAuth: true,
    );

    if (response.statusCode == 200) {
      final List<dynamic> studentsJson = json.decode(response.body);
      return studentsJson.map((json) => Student.fromJson(json)).toList();
    } else {
      final errorData = json.decode(response.body);
      throw Exception(errorData['detail'] ?? 'Failed to load students');
    }
  }

  Future<Map<String, dynamic>> getBatchFinancials({
    required int branchId,
    required int sportId,
    required int batchId,
  }) async {
    final response = await apiClient.get(
      '/api/payments/batch-financials/?branch=$branchId&sport=$sportId&batch=$batchId',
      includeAuth: true,
    );

    if (response.statusCode == 200) {
      return json.decode(response.body) as Map<String, dynamic>;
    } else {
      final errorData = json.decode(response.body);
      throw Exception(errorData['detail'] ?? 'Failed to load batch financials');
    }
  }
}

final authApi = AuthApi(apiClient); // Global instance