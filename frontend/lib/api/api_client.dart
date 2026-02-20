// sportsverse/frontend/sportsverse_app/lib/api/api_client.dart

import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

class ApiClient {
  // For Android emulator, use 10.0.2.2
  // For iOS simulator, use 127.0.0.1 or localhost
  // For physical device, use your machine's IP address
//static const String baseUrl = 'http://127.0.0.1:8000'; 
 //static const String baseUrl = 'http://192.168.29.245:8000';
  //static const String baseUrl = 'http://192.168.29.245:8000';
     static const String baseUrl = 'http://192.168.1.33:8000';

// 192.168.0.115-- madhura
  String? _token;
  bool _isInitialized = false; // Added to track initialization

  // Initialize token from SharedPreferences
  Future<void> init() async {
    if (_isInitialized) return;
    final prefs = await SharedPreferences.getInstance();
    _token = prefs.getString('auth_token');
    _isInitialized = true;
    print("🔑 ApiClient Initialized. Token: ${_token != null ? 'Found' : 'Not Found'}");
  }

  // New helper to ensure we don't send a request before the token is loaded
  Future<void> _ensureInitialized() async {
    if (!_isInitialized) {
      await init();
    }
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
    bool includeAuth = true,
  }) async {
    await _ensureInitialized(); // Added check
    final url = Uri.parse('$baseUrl$path');
    return http.post(
      url,
      headers: _getHeaders(includeAuth: includeAuth),
      body: json.encode(body),
    );
  }

  Future<http.Response> get(String path, {bool includeAuth = true}) async {
    await _ensureInitialized(); // Added check
    final url = Uri.parse('$baseUrl$path');
    return http.get(url, headers: _getHeaders(includeAuth: includeAuth));
  }

  Future<http.Response> put(
    String path,
    Map<String, dynamic> body, {
    bool includeAuth = true,
  }) async {
    await _ensureInitialized(); // Added check
    final url = Uri.parse('$baseUrl$path');
    return http.put(
      url,
      headers: _getHeaders(includeAuth: includeAuth),
      body: json.encode(body),
    );
  }

  Future<http.Response> delete(String path, {bool includeAuth = true}) async {
    await _ensureInitialized(); // Added check
    final url = Uri.parse('$baseUrl$path');
    return http.delete(url, headers: _getHeaders(includeAuth: includeAuth));
  }

  Future<http.Response> patch(
    String path,
    Map<String, dynamic> body, {
    bool includeAuth = true,
  }) async {
    await _ensureInitialized(); // Added check
    final url = Uri.parse('$baseUrl$path');
    return http.patch(
      url,
      headers: _getHeaders(includeAuth: includeAuth),
      body: json.encode(body),
    );
  }

  Future<http.StreamedResponse> postMultipart(
    String path,
    Map<String, String> fields, {
    http.MultipartFile? file,
    bool includeAuth = true,
  }) async {
    await _ensureInitialized(); // Added check
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

  Future<http.Response> uploadFile(String path, String filePath) async {
    try {
      await _ensureInitialized(); // Added check
      print('📤 Uploading file: $filePath to $path');
      final url = Uri.parse('$baseUrl$path');
      var request = http.MultipartRequest('POST', url);
      request.headers.addAll(_getHeaders(includeAuth: true, isMultiPart: true));
      
      print('📤 Headers: ${request.headers}');
      request.files.add(await http.MultipartFile.fromPath('profile_photo', filePath));
      
      final streamedResponse = await request.send();
      final response = await http.Response.fromStream(streamedResponse);
      return response;
    } catch (e) {
      print('📤 Upload file error: $e');
      throw Exception('Error uploading file: $e');
    }
  }

  Future<http.Response> uploadFileWithData(String path, String filePath, String fileFieldName, Map<String, dynamic> formData) async {
    try {
      await _ensureInitialized(); // Added check
      print('📤 Uploading file with data: $filePath to $path');
      final url = Uri.parse('$baseUrl$path');
      var request = http.MultipartRequest('POST', url);
      request.headers.addAll(_getHeaders(includeAuth: true, isMultiPart: true));
      
      request.files.add(await http.MultipartFile.fromPath(fileFieldName, filePath));
      
      formData.forEach((key, value) {
        request.fields[key] = value.toString();
      });
      
      final streamedResponse = await request.send();
      final response = await http.Response.fromStream(streamedResponse);
      return response;
    } catch (e) {
      print('📤 Upload file with data error: $e');
      throw Exception('Error uploading file with data: $e');
    }
  }

  Future<http.Response> uploadFileWithFieldName(String path, String filePath, String fieldName) async {
    try {
      await _ensureInitialized(); // Added check
      print('📤 Uploading file with custom field name: $filePath to $path');
      final url = Uri.parse('$baseUrl$path');
      var request = http.MultipartRequest('POST', url);
      request.headers.addAll(_getHeaders(includeAuth: true, isMultiPart: true));
      
      request.files.add(await http.MultipartFile.fromPath(fieldName, filePath));
      
      final streamedResponse = await request.send();
      final response = await http.Response.fromStream(streamedResponse);
      return response;
    } catch (e) {
      print('📤 Upload file with custom field name error: $e');
      throw Exception('Error uploading file with custom field name: $e');
    }
  }
}

final apiClient = ApiClient(); // Global instance