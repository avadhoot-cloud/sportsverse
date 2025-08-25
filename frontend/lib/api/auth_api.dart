// sportsverse/frontend/sportsverse_app/lib/api/auth_api.dart

import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:sportsverse_app/api/api_client.dart';
import 'package:sportsverse_app/models/user.dart';

class AuthApi {
  final ApiClient apiClient;

  AuthApi(this.apiClient);

  Future<AuthResponse> login(String username, String password) async {
    final response = await apiClient.post('/accounts/login/', {
      'username': username,
      'password': password,
    }, includeAuth: false);

    if (response.statusCode == 200) {
      final authResponse = AuthResponse.fromJson(json.decode(response.body));
      apiClient.setToken(authResponse.token); // Save token
      return authResponse;
    } else {
      final errorData = json.decode(response.body);
      throw Exception(
        errorData['non_field_errors']?.join(', ') ?? 'Login failed',
      );
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
      '/accounts/register-academy/',
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
      '/accounts/register-user/',
      body,
      includeAuth: true, // This requires an authenticated Academy Admin
    );

    if (response.statusCode == 201) {
      // Check if response body exists and is not empty
      if (response.body.isEmpty) {
        throw Exception('Empty response from server');
      }

      try {
        final responseData = json.decode(response.body);

        if (responseData == null) {
          throw Exception('Invalid response format from server');
        }

        // The Django backend returns: {"message": "...", "user_id": id, "username": "..."}
        // We'll create a minimal User object since full user data isn't returned
        return User(
          id: responseData['user_id'] ?? 0,
          username: responseData['username'] ?? 'unknown',
          firstName: firstName, // Use the data we sent
          lastName: lastName,
          email: email ?? '', // Handle nullable email
          userType: userType,
        );
      } catch (e) {
        print('DEBUG: Error parsing registration response: $e');
        print('DEBUG: Response body was: ${response.body}');
        throw Exception('Failed to parse server response: $e');
      }
    } else {
      // Check if response body exists for error handling
      if (response.body.isEmpty) {
        throw Exception(
          'Registration failed with status ${response.statusCode}',
        );
      }

      try {
        final errorData = json.decode(response.body);

        // Handle specific validation errors
        if (errorData != null && errorData is Map<String, dynamic>) {
          String errorMessage = '';

          // Check for field-specific errors
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

          // If no specific errors found, show general message
          if (errorMessage.isEmpty) {
            errorMessage = 'Registration failed. Please check your input.';
          }

          throw Exception(errorMessage.trim());
        } else {
          throw Exception('Registration failed. Please try again.');
        }
      } catch (e) {
        print('DEBUG: Error parsing error response: $e');
        print('DEBUG: Response body was: ${response.body}');
        throw Exception(
          'Registration failed with status ${response.statusCode}',
        );
      }
    }
  }

  Future<void> logout() async {
    apiClient.setToken(null); // Clear token
    // If you have a logout API endpoint on Django, call it here
  }

  Future<List<Sport>> getSports() async {
    final response = await apiClient.get(
      '/organizations/sports/',
      includeAuth: false,
    ); // Sports are public
    if (response.statusCode == 200) {
      List<dynamic> data = json.decode(response.body);
      return data.map((json) => Sport.fromJson(json)).toList();
    } else {
      throw Exception('Failed to load sports');
    }
  }

  /// Request password reset via email
  Future<Map<String, dynamic>> requestPasswordReset(String email) async {
    final response = await apiClient.post('/accounts/password-reset/', {
      'email': email,
    }, includeAuth: false);

    if (response.statusCode == 200) {
      return json.decode(response.body);
    } else {
      final errorData = json.decode(response.body);
      throw Exception(errorData['error'] ?? 'Failed to request password reset');
    }
  }

  /// Confirm password reset with token
  Future<Map<String, dynamic>> confirmPasswordReset({
    required String uid,
    required String token,
    required String newPassword,
  }) async {
    final response = await apiClient.post('/accounts/password-reset-confirm/', {
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
}

final authApi = AuthApi(apiClient); // Global instance
