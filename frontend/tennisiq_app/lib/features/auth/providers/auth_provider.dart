import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import '../../../core/network/api_service.dart';
import '../../../core/constants/api_constants.dart';

enum AuthStatus { initial, authenticated, unauthenticated, loading, error }

class AuthState {
  final AuthStatus status;
  final String? errorMessage;

  AuthState({required this.status, this.errorMessage});

  AuthState copyWith({AuthStatus? status, String? errorMessage}) {
    return AuthState(
      status: status ?? this.status,
      errorMessage: errorMessage ?? this.errorMessage,
    );
  }
}

final apiServiceProvider = Provider((ref) => ApiService());

final authProvider = StateNotifierProvider<AuthNotifier, AuthState>((ref) {
  return AuthNotifier(ref.read(apiServiceProvider));
});

class AuthNotifier extends StateNotifier<AuthState> {
  final ApiService _apiService;
  final FlutterSecureStorage _secureStorage = const FlutterSecureStorage();

  AuthNotifier(this._apiService) : super(AuthState(status: AuthStatus.initial)) {
    checkAuthStatus();
  }

  Future<void> checkAuthStatus() async {
    final token = await _secureStorage.read(key: 'access_token');
    if (token != null) {
      state = state.copyWith(status: AuthStatus.authenticated, errorMessage: null);
    } else {
      state = state.copyWith(status: AuthStatus.unauthenticated, errorMessage: null);
    }
  }

  Future<void> login(String username, String password) async {
    state = state.copyWith(status: AuthStatus.loading, errorMessage: null);
    try {
      final response = await _apiService.client.post(
        ApiConstants.login,
        data: {'username': username, 'password': password},
      );
      
      final access = response.data['access'];
      final refresh = response.data['refresh'];
      
      await _secureStorage.write(key: 'access_token', value: access);
      await _secureStorage.write(key: 'refresh_token', value: refresh);
      
      state = state.copyWith(status: AuthStatus.authenticated, errorMessage: null);
    } on DioException catch (e) {
      state = state.copyWith(
        status: AuthStatus.error,
        errorMessage: e.response?.data?['detail'] ?? 'Login failed. Please check credentials.',
      );
    } catch (e) {
      state = state.copyWith(status: AuthStatus.error, errorMessage: e.toString());
    }
  }

  Future<void> register({
    required String username,
    required String email,
    required String password,
    required String firstName,
    required String lastName,
  }) async {
    state = state.copyWith(status: AuthStatus.loading, errorMessage: null);
    try {
      await _apiService.client.post(
        ApiConstants.register,
        data: {
          'username': username,
          'email': email,
          'password': password,
          'first_name': firstName,
          'last_name': lastName,
          'skill_level': 'intermediate', // Default setup, can be updated later
        },
      );
      // Automatically login post registration
      await login(username, password);
    } on DioException catch (e) {
      state = state.copyWith(
        status: AuthStatus.error,
        errorMessage: e.response?.data?.toString() ?? 'Registration failed.',
      );
    } catch (e) {
      state = state.copyWith(status: AuthStatus.error, errorMessage: e.toString());
    }
  }
  
  Future<void> logout() async {
    await _secureStorage.deleteAll();
    state = state.copyWith(status: AuthStatus.unauthenticated, errorMessage: null);
  }
}
