// lib/api/api_client.dart
//
// Centralised HTTP client.
// Compile-time base URL:
//   flutter run --dart-define=API_BASE_URL=http://192.168.1.33:8000
// Falls back to Android-emulator alias when not defined.

import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

class ApiClient {
  // Resolved at compile time via --dart-define; falls back to localhost (for Chrome/Web).
  // For Android Emulator, use --dart-define=API_BASE_URL=http://10.0.2.2:8000
  static const String baseUrl = String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: 'http://localhost:8000/',
  );

  static const Duration _kTimeout = Duration(seconds: 30);

  String? _token;
  bool _isInitialized = false;

  // ── Initialisation ────────────────────────────────────────────────────────

  Future<void> init() async {
    if (_isInitialized) return;
    final prefs = await SharedPreferences.getInstance();
    _token = prefs.getString('auth_token');
    _isInitialized = true;
    debugPrint('🌐 ApiClient: baseUrl is $baseUrl');
    debugPrint('🔑 ApiClient: token ${_token != null ? 'loaded' : 'not found'}');
  }

  Future<void> _ensureInitialized() async {
    if (!_isInitialized) await init();
  }

  // ── Token management ──────────────────────────────────────────────────────

  void setToken(String? token) {
    _token = token;
    _persistToken(token);
  }

  String? getToken() => _token;

  Future<void> _persistToken(String? token) async {
    final prefs = await SharedPreferences.getInstance();
    if (token != null) {
      await prefs.setString('auth_token', token);
    } else {
      await prefs.remove('auth_token');
    }
  }

  // ── Headers ───────────────────────────────────────────────────────────────

Map<String, String> _headers({
  bool withAuth = true,
  bool multipart = false,
}) {
  final h = <String, String>{};

  if (!multipart) {
    h['Content-Type'] = 'application/json';
  }

  // 👉 ADD THIS PRINT
  print("TOKEN VALUE: $_token");

  if (withAuth && _token != null) {
    h['Authorization'] = 'Token $_token';
  }

  // 👉 ADD THIS PRINT
  print("HEADERS BEING SENT: $h");

  return h;
}
  // ── Error / timeout helpers ───────────────────────────────────────────────

  /// Wraps a future in a human-readable timeout exception.
  Future<T> _withTimeout<T>(Future<T> future) async {
    try {
      return await future.timeout(_kTimeout);
    } on TimeoutException {
      throw Exception('Request timed out. Please check your connection.');
    }
  }

  // ── HTTP verbs ────────────────────────────────────────────────────────────

  Future<http.Response> get(String path, {bool includeAuth = true}) async {
    await _ensureInitialized();
    final url = Uri.parse('$baseUrl$path');
    return _withTimeout(http.get(url, headers: _headers(withAuth: includeAuth)));
  }

  Future<http.Response> post(
    String path,
    Map<String, dynamic> body, {
    bool includeAuth = true,
  }) async {
    await _ensureInitialized();
    final url = Uri.parse('$baseUrl$path');
    return _withTimeout(http.post(
      url,
      headers: _headers(withAuth: includeAuth),
      body: json.encode(body),
    ));
  }

  Future<http.Response> put(
    String path,
    Map<String, dynamic> body, {
    bool includeAuth = true,
  }) async {
    await _ensureInitialized();
    final url = Uri.parse('$baseUrl$path');
    return _withTimeout(http.put(
      url,
      headers: _headers(withAuth: includeAuth),
      body: json.encode(body),
    ));
  }

  Future<http.Response> patch(
    String path,
    Map<String, dynamic> body, {
    bool includeAuth = true,
  }) async {
    await _ensureInitialized();
    final url = Uri.parse('$baseUrl$path');
    return _withTimeout(http.patch(
      url,
      headers: _headers(withAuth: includeAuth),
      body: json.encode(body),
    ));
  }

  Future<http.Response> delete(String path, {bool includeAuth = true}) async {
    await _ensureInitialized();
    final url = Uri.parse('$baseUrl$path');
    return _withTimeout(http.delete(url, headers: _headers(withAuth: includeAuth)));
  }

  // ── Multipart ─────────────────────────────────────────────────────────────

  Future<http.StreamedResponse> postMultipart(
    String path,
    Map<String, String> fields, {
    http.MultipartFile? file,
    bool includeAuth = true,
  }) async {
    await _ensureInitialized();
    final url = Uri.parse('$baseUrl$path');
    final request = http.MultipartRequest('POST', url)
      ..headers.addAll(_headers(withAuth: includeAuth, multipart: true))
      ..fields.addAll(fields);
    if (file != null) request.files.add(file);
    return _withTimeout(request.send());
  }

  Future<http.Response> uploadFile(String path, String filePath) async {
    await _ensureInitialized();
    debugPrint('📤 uploadFile: $filePath → $path');
    final url = Uri.parse('$baseUrl$path');
    final request = http.MultipartRequest('POST', url)
      ..headers.addAll(_headers(withAuth: true, multipart: true))
      ..files.add(await http.MultipartFile.fromPath('profile_photo', filePath));
    final streamed = await _withTimeout(request.send());
    return http.Response.fromStream(streamed);
  }

  Future<http.Response> uploadFileWithData(
    String path,
    String filePath,
    String fileFieldName,
    Map<String, dynamic> formData,
  ) async {
    await _ensureInitialized();
    debugPrint('📤 uploadFileWithData: $filePath → $path');
    final url = Uri.parse('$baseUrl$path');
    final request = http.MultipartRequest('POST', url)
      ..headers.addAll(_headers(withAuth: true, multipart: true))
      ..files.add(await http.MultipartFile.fromPath(fileFieldName, filePath));
    formData.forEach((k, v) => request.fields[k] = v.toString());
    final streamed = await _withTimeout(request.send());
    return http.Response.fromStream(streamed);
  }

  Future<http.Response> uploadFileWithFieldName(
    String path,
    String filePath,
    String fieldName,
  ) async {
    await _ensureInitialized();
    debugPrint('📤 uploadFileWithFieldName: $filePath → $path');
    final url = Uri.parse('$baseUrl$path');
    final request = http.MultipartRequest('POST', url)
      ..headers.addAll(_headers(withAuth: true, multipart: true))
      ..files.add(await http.MultipartFile.fromPath(fieldName, filePath));
    final streamed = await _withTimeout(request.send());
    return http.Response.fromStream(streamed);
  }

  
}

/// Global singleton — all API classes share this instance.
final apiClient = ApiClient();