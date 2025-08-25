// sportsverse/frontend/sportsverse_app/lib/api/coach_api.dart

import 'dart:convert';
import 'package:sportsverse_app/api/api_client.dart';

class Coach {
  final int id;
  final String coachName;
  final List<int> assignedBranches;
  final List<String> assignedBranchNames;

  Coach({
    required this.id,
    required this.coachName,
    required this.assignedBranches,
    required this.assignedBranchNames,
  });

  factory Coach.fromJson(Map<String, dynamic> json) {
    return Coach(
      id: json['id'],
      coachName: json['coach_name'] ?? '',
      assignedBranches: List<int>.from(json['branches'] ?? []),
      assignedBranchNames: List<String>.from(
        json['assigned_branch_names'] ?? [],
      ),
    );
  }
}

class CoachApi {
  final ApiClient apiClient;

  CoachApi(this.apiClient);

  /// Get all coaches in the organization
  Future<List<Coach>> getCoaches() async {
    final response = await apiClient.get(
      '/accounts/coaches/',
      includeAuth: true,
    );

    if (response.statusCode == 200) {
      final List<dynamic> coachesJson = json.decode(response.body);
      return coachesJson.map((json) => Coach.fromJson(json)).toList();
    } else {
      final errorData = json.decode(response.body);
      throw Exception(errorData['detail'] ?? 'Failed to load coaches');
    }
  }

  /// Assign branches to a coach
  Future<Coach> assignBranches({
    required int coachId,
    required List<int> branchIds,
  }) async {
    final assignmentData = {'branches': branchIds};

    final response = await apiClient.put(
      '/accounts/coaches/$coachId/assign-branches/',
      assignmentData,
      includeAuth: true,
    );

    if (response.statusCode == 200) {
      final responseData = json.decode(response.body);
      return Coach.fromJson(responseData['coach']);
    } else {
      final errorData = json.decode(response.body);

      if (errorData.containsKey('branches')) {
        throw Exception('Branches: ${errorData['branches'].join(', ')}');
      } else if (errorData.containsKey('detail')) {
        throw Exception(errorData['detail']);
      } else {
        throw Exception('Failed to assign branches');
      }
    }
  }
}

final coachApi = CoachApi(apiClient); // Global instance
