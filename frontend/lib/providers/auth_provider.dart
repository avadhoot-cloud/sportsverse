// sportsverse/frontend/sportsverse_app/lib/providers/auth_provider.dart

import 'dart:io';

import 'package:flutter/material.dart';
import 'package:sportsverse_app/api/api_client.dart';
import 'package:sportsverse_app/api/auth_api.dart';
import 'package:sportsverse_app/models/user.dart';

class AuthProvider with ChangeNotifier {
  User? _currentUser;
  String? _token;
  ProfileDetails? _profileDetails;
  bool _isLoading = false;
  String? _errorMessage;

  User? get currentUser => _currentUser;
  String? get token => _token;
  ProfileDetails? get profileDetails => _profileDetails;
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;

  Future<void> initAuth() async {
    _isLoading = true;
    notifyListeners();
    await apiClient.init(); // Initialize token from storage
    _token = apiClient.getToken();
    if (_token != null) {
      // You might want to validate the token with your backend here
      // For simplicity, we'll assume a stored token means logged in
      // In a real app, fetch user profile to confirm validity
    }
    _isLoading = false;
    notifyListeners();
  }

  Future<void> login(String username, String password) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final authResponse = await authApi.login(username, password);
      _currentUser = authResponse.user;
      _token = authResponse.token;
      _profileDetails = authResponse.profileDetails;
      _isLoading = false;
      notifyListeners();
    } catch (e) {
      _errorMessage = e.toString().replaceFirst('Exception: ', '');
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> registerAcademy({
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
    File? academyLogoFile,
  }) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      await authApi.registerAcademy(
        organizationFullName: organizationFullName,
        organizationAcademyName: organizationAcademyName,
        organizationLocation: organizationLocation,
        organizationMobileNumber: organizationMobileNumber,
        organizationEmailAddress: organizationEmailAddress,
        organizationSlug: organizationSlug,
        sportsOfferedIds: sportsOfferedIds,
        adminUsername: adminUsername,
        adminEmail: adminEmail,
        adminFirstName: adminFirstName,
        adminLastName: adminLastName,
        adminPassword: adminPassword,
        academyLogoFile: academyLogoFile,
      );
      _isLoading = false;
      notifyListeners();
    } catch (e) {
      _errorMessage = e.toString().replaceFirst('Exception: ', '');
      _isLoading = false;
      notifyListeners();
      rethrow; // Re-throw to allow screen to catch and show specific error
    }
  }

  Future<void> registerCoachStudentStaff({
    required String userType,
    required String username,
    String? email,
    required String password,
    required String firstName,
    required String lastName,
    String? phoneNumber,
    String? gender,
    String? dateOfBirth,
    String? parentName,
    String? parentPhoneNumber,
    String? parentEmail,
  }) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      await authApi.registerCoachStudentStaff(
        userType: userType,
        username: username,
        email: email,
        password: password,
        firstName: firstName,
        lastName: lastName,
        phoneNumber: phoneNumber,
        gender: gender,
        dateOfBirth: dateOfBirth,
        parentName: parentName,
        parentPhoneNumber: parentPhoneNumber,
        parentEmail: parentEmail,
      );
      _isLoading = false;
      notifyListeners();
    } catch (e) {
      _errorMessage = e.toString().replaceFirst('Exception: ', '');
      _isLoading = false;
      notifyListeners();
      rethrow;
    }
  }

  void logout() {
    _currentUser = null;
    _token = null;
    _profileDetails = null;
    _errorMessage = null;
    authApi.logout();
    notifyListeners();
  }
}