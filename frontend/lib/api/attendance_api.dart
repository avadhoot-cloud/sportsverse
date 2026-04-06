import 'dart:convert';
import 'api_client.dart';

class AttendanceApi {
  final ApiClient apiClient;

  AttendanceApi(this.apiClient);

  // ✅ GET STUDENTS FOR ATTENDANCE
  Future<List<dynamic>> getStudentsForAttendance({
    required int batchId,
    required String date,
  }) async {
    try {
      final res = await apiClient.get(
        "/api/organizations/attendance/students/?batch=$batchId&date=$date",
      );

      if (res.statusCode == 200) {
        final decoded = jsonDecode(res.body);

        // ✅ Ensure always List
        if (decoded is List) {
          return decoded;
        } else {
          print("⚠️ Unexpected response format: $decoded");
          return [];
        }
      } else {
        print("❌ ERROR STATUS: ${res.statusCode}");
        print("❌ ERROR BODY: ${res.body}");
        return [];
      }
    } catch (e) {
      print("🔥 EXCEPTION in getStudentsForAttendance: $e");
      return [];
    }
  }

  // ✅ BULK MARK ATTENDANCE
  Future<Map<String, dynamic>> markBulkAttendance(
      List<dynamic> data) async {
    try {
      final res = await apiClient.post(
        "/api/organizations/attendance/mark-bulk/",
        {"attendance": data},
      );

      if (res.statusCode == 200 || res.statusCode == 201) {
        return jsonDecode(res.body);
      } else {
        print("❌ BULK ERROR STATUS: ${res.statusCode}");
        print("❌ BULK ERROR BODY: ${res.body}");
        throw Exception("Failed to mark attendance");
      }
    } catch (e) {
      print("🔥 EXCEPTION in markBulkAttendance: $e");
      throw Exception("Error marking attendance");
    }
  }
}