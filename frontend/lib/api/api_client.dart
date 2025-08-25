// sportsverse/frontend/sportsverse_app/lib/api/api_client.dart

import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

class ApiClient {
  // For Android emulator, use 10.0.2.2
  // For iOS simulator, use 127.0.0.1 or localhost
  // For physical device, use your machine's IP address
  static const String baseUrl = 'http://192.168.29.245:8000/api';

  String? _token;

  // Initialize token from SharedPreferences
  Future<void> init() async {
    final prefs = await SharedPreferences.getInstance();
    _token = prefs.getString('auth_token');
  }

  void setToken(String? token) {
    _token = token;
    _saveToken(token);
  }

  String? getToken() => _token;

  Future<void> _saveToken(String? token) async {
    final prefs = await SharedPreferences.getInstance();
    if (token != null) {
      await prefs.setString('auth_token', token);
    } else {
      await prefs.remove('auth_token');
    }
  }

  Map<String, String> _getHeaders({
    bool includeAuth = true,
    bool isMultiPart = false,
  }) {
    Map<String, String> headers = {'Content-Type': 'application/json'};
    if (isMultiPart) {
      headers.remove('Content-Type'); // Multipart handles its own content type
    }
    if (includeAuth && _token != null) {
      headers['Authorization'] = 'Token $_token';
    }
    return headers;
  }

  Future<http.Response> post(
    String path,
    Map<String, dynamic> body, {
    bool includeAuth = false,
  }) async {
    final url = Uri.parse('$baseUrl$path');
    return http.post(
      url,
      headers: _getHeaders(includeAuth: includeAuth),
      body: json.encode(body),
    );
  }

  Future<http.Response> get(String path, {bool includeAuth = true}) async {
    final url = Uri.parse('$baseUrl$path');
    return http.get(url, headers: _getHeaders(includeAuth: includeAuth));
  }

  Future<http.Response> put(
    String path,
    Map<String, dynamic> body, {
    bool includeAuth = true,
  }) async {
    final url = Uri.parse('$baseUrl$path');
    return http.put(
      url,
      headers: _getHeaders(includeAuth: includeAuth),
      body: json.encode(body),
    );
  }

  Future<http.Response> delete(String path, {bool includeAuth = true}) async {
    final url = Uri.parse('$baseUrl$path');
    return http.delete(url, headers: _getHeaders(includeAuth: includeAuth));
  }

  Future<http.StreamedResponse> postMultipart(
    String path,
    Map<String, String> fields, {
    http.MultipartFile? file,
    bool includeAuth = false,
  }) async {
    final url = Uri.parse('$baseUrl$path');
    var request = http.MultipartRequest('POST', url);
    request.headers.addAll(
      _getHeaders(includeAuth: includeAuth, isMultiPart: true),
    );
    request.fields.addAll(fields);
    if (file != null) {
      request.files.add(file);
    }
    return request.send();
  }
}

final apiClient = ApiClient(); // Global instance
