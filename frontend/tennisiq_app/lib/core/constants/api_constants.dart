class ApiConstants {
  // Use 10.0.2.2 for Android emulator testing against localhost
  // Alternatively, use exact IP if testing on physical device
  static const String baseUrl = 'http://10.0.2.2:8000/api';
  
  static const String register = '/auth/register/';
  static const String login = '/auth/login/';
  static const String refresh = '/auth/refresh/';
  static const String sessions = '/sessions/sessions/';
}
