// sportsverse/frontend/sportsverse_app/lib/api/branch_api.dart

import 'dart:convert';
import 'package:sportsverse_app/api/api_client.dart';
import 'package:sportsverse_app/models/branch.dart';

class BranchApi {
  final ApiClient apiClient;

  BranchApi(this.apiClient);

  /// Get all branches for the logged-in academy admin
  Future<List<Branch>> getBranches() async {
    final response = await apiClient.get(
      '/organizations/branches/',
      includeAuth: true,
    );

    if (response.statusCode == 200) {
      final List<dynamic> branchesJson = json.decode(response.body);
      return branchesJson.map((json) => Branch.fromJson(json)).toList();
    } else {
      final errorData = json.decode(response.body);
      throw Exception(errorData['detail'] ?? 'Failed to load branches');
    }
  }

  /// Create a new branch
  Future<Branch> createBranch({
    required String name,
    required String address,
    bool isActive = true,
  }) async {
    final branchData = {
      'name': name,
      'address': address,
      'is_active': isActive,
    };

    final response = await apiClient.post(
      '/organizations/branches/',
      branchData,
      includeAuth: true,
    );

    if (response.statusCode == 201) {
      return Branch.fromJson(json.decode(response.body));
    } else {
      final errorData = json.decode(response.body);

      // Handle validation errors
      if (errorData.containsKey('name')) {
        throw Exception('Name: ${errorData['name'].join(', ')}');
      } else if (errorData.containsKey('address')) {
        throw Exception('Address: ${errorData['address'].join(', ')}');
      } else if (errorData.containsKey('detail')) {
        throw Exception(errorData['detail']);
      } else {
        throw Exception('Failed to create branch');
      }
    }
  }

  /// Update an existing branch
  Future<Branch> updateBranch({
    required int branchId,
    required String name,
    required String address,
    required bool isActive,
  }) async {
    final branchData = {
      'name': name,
      'address': address,
      'is_active': isActive,
    };

    final response = await apiClient.put(
      '/organizations/branches/$branchId/',
      branchData,
      includeAuth: true,
    );

    if (response.statusCode == 200) {
      return Branch.fromJson(json.decode(response.body));
    } else {
      final errorData = json.decode(response.body);

      // Handle validation errors
      if (errorData.containsKey('name')) {
        throw Exception('Name: ${errorData['name'].join(', ')}');
      } else if (errorData.containsKey('address')) {
        throw Exception('Address: ${errorData['address'].join(', ')}');
      } else if (errorData.containsKey('detail')) {
        throw Exception(errorData['detail']);
      } else {
        throw Exception('Failed to update branch');
      }
    }
  }

  /// Delete a branch
  Future<void> deleteBranch(int branchId) async {
    final response = await apiClient.delete(
      '/organizations/branches/$branchId/',
      includeAuth: true,
    );

    if (response.statusCode != 204) {
      final errorData = json.decode(response.body);
      throw Exception(errorData['detail'] ?? 'Failed to delete branch');
    }
  }

  /// Get a specific branch
  Future<Branch> getBranch(int branchId) async {
    final response = await apiClient.get(
      '/organizations/branches/$branchId/',
      includeAuth: true,
    );

    if (response.statusCode == 200) {
      return Branch.fromJson(json.decode(response.body));
    } else {
      final errorData = json.decode(response.body);
      throw Exception(errorData['detail'] ?? 'Failed to load branch');
    }
  }
}

final branchApi = BranchApi(apiClient); // Global instance
