import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'auth_provider.dart';
import 'package:provider/provider.dart';
import '/api/api_client.dart';
// ✅ USE YOUR EXISTING API CLIENT (VERY IMPORTANT)

// ✅ Your model file
import '/models/student_models.dart';

class AdminProvider with ChangeNotifier {
  List<StudentEnrollment> _allEnrollments = [];
  List<StudentEnrollment> _filteredEnrollments = [];
  bool _isLoading = false;

  List<StudentEnrollment> get enrollments => _filteredEnrollments;
  bool get isLoading => _isLoading;

  // 🔥 FETCH STUDENTS WITH FILTERS + AUTH TOKEN
  Future<void> fetchAllStudents(BuildContext context,
      {String? branch, String? batch}) async {
    _isLoading = true;
    notifyListeners();

    try {
      String path = '/api/accounts/students/';
      List<String> queryParams = [];

      if (branch != null) queryParams.add('branch=$branch');
      if (batch != null) queryParams.add('batch=$batch');

      if (queryParams.isNotEmpty) {
        path += '?${queryParams.join('&')}';
      }

      // ✅ USE GLOBAL API CLIENT
      final response = await apiClient.get(path, includeAuth: true);

      if (response.statusCode == 200) {
        final List<dynamic> data = json.decode(response.body);

        _allEnrollments =
            data.map((e) => StudentEnrollment.fromJson(e)).toList();

        _filteredEnrollments = _allEnrollments;
      } else {
        debugPrint("API ERROR: ${response.statusCode}");
      }
    } catch (e) {
      debugPrint("Error fetching students: $e");
    }

    _isLoading = false;
    notifyListeners();
  }
}