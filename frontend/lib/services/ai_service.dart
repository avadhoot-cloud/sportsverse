import 'dart:convert';
import 'package:http/http.dart' as http;

class AIService {
  // Replace with your local IP if testing on a real phone (e.g., 192.168.1.x)
  // Use 10.0.2.2 for Android Emulator
  final String _baseUrl = "http://localhost:8000/api/ai-assistant/";

  Future<String> getBotResponse(String userQuery) async {
    try {
      final response = await http.post(
        Uri.parse(_baseUrl),
        headers: {"Content-Type": "application/json"},
        body: jsonEncode({"query": userQuery}),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return data['response']; // This matches the 'response' key in your Django view
      } else {
        return "Server error: ${response.statusCode}";
      }
    } catch (e) {
      return "Connection failed. Make sure Django is running!";
    }
  }
}