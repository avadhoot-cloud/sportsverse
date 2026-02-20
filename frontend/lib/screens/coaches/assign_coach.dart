import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:provider/provider.dart';
import 'package:sportsverse_app/providers/auth_provider.dart';

class AssignCoachScreen extends StatefulWidget {
  const AssignCoachScreen({super.key});

  @override
  _AssignCoachPageState createState() => _AssignCoachPageState();
}

class _AssignCoachPageState extends State<AssignCoachScreen> {
  // Brand Colors
  static const Color brandTeal = Color(0xFF00796B);
  static const Color accentTeal = Color(0xFF00A388);

  // Lists for Dropdowns
  List coaches = [];
  List branches = [];
  List sports = [];
  List batches = [];

  // Selected Values
  String? selectedCoach;
  String? selectedBranch;
  String? selectedSport;
  String? selectedBatch;

  bool isLoading = true;

  @override
  void initState() {
    super.initState();
    // Use Future.microtask to access Provider safely in initState
    Future.microtask(() => fetchInitialData());
  }

  // 1. Fetch Coaches, Branches, and Sports on Load
  Future<void> fetchInitialData() async {
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final token = authProvider.token;

    try {
      final response = await http.get(
        Uri.parse('http://127.0.0.1:8000/api/coaches/assign/'),
        headers: {
          'Authorization': 'Token $token',
          'Content-Type': 'application/json',
        },
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        setState(() {
          coaches = data['coaches'] ?? [];
          branches = data['branches'] ?? [];
          sports = data['sports'] ?? [];
          isLoading = false;
        });
      }
    } catch (e) {
      debugPrint("Error fetching data: $e");
      setState(() => isLoading = false);
    }
  }

  // 2. Fetch Batches dynamically
  Future<void> fetchBatches() async {
    if (selectedBranch != null && selectedSport != null) {
      final authProvider = Provider.of<AuthProvider>(context, listen: false);
      final token = authProvider.token;

      final response = await http.get(
        Uri.parse('http://127.0.0.1:8000/api/coaches/batches-lookup/?branch_id=$selectedBranch&sport_id=$selectedSport'),
        headers: {'Authorization': 'Token $token'},
      );

      if (response.statusCode == 200) {
        setState(() {
          batches = json.decode(response.body);
          selectedBatch = null; 
        });
      }
    }
  }

  // 3. Submit Assignment
  Future<void> assignCoach() async {
    if (selectedCoach == null || selectedBatch == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Please select all fields")));
      return;
    }

    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final token = authProvider.token;

    final response = await http.post(
      Uri.parse('http://127.0.0.1:8000/api/coaches/assign/'),
      headers: {
        "Content-Type": "application/json",
        "Authorization": "Token $token",
      },
      body: jsonEncode({
        "coach_id": selectedCoach,
        "branch_id": selectedBranch,
        "sport_id": selectedSport,
        "batch_id": selectedBatch,
      }),
    );

    if (response.statusCode == 201) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(backgroundColor: Colors.green, content: Text("Coach Assigned Successfully!")),
      );
      Navigator.pop(context);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F7F9),
      appBar: AppBar(
        title: const Text("Assignment Manager", style: TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: brandTeal,
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      body: isLoading 
        ? const Center(child: CircularProgressIndicator(color: brandTeal))
        : SingleChildScrollView(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildHeader(),
                const SizedBox(height: 25),
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(15),
                    boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 15)],
                  ),
                  child: Column(
                    children: [
                      _buildLabel("Select Professional Coach"),
                      _buildDropdown(
                        hint: "Search Coach...",
                        value: selectedCoach,
                        items: coaches,
                        icon: Icons.psychology,
                        onChanged: (val) => setState(() => selectedCoach = val),
                      ),
                      const SizedBox(height: 20),
                      
                      _buildLabel("Academy Branch"),
                      _buildDropdown(
                        hint: "Select Location",
                        value: selectedBranch,
                        items: branches,
                        icon: Icons.location_on,
                        onChanged: (val) {
                          setState(() => selectedBranch = val);
                          fetchBatches();
                        },
                      ),
                      const SizedBox(height: 20),

                      _buildLabel("Sports Discipline"),
                      _buildDropdown(
                        hint: "Select Sport",
                        value: selectedSport,
                        items: sports,
                        icon: Icons.sports_tennis,
                        onChanged: (val) {
                          setState(() => selectedSport = val);
                          fetchBatches();
                        },
                      ),
                      const SizedBox(height: 20),

                      _buildLabel("Available Batch"),
                      _buildDropdown(
                        hint: (selectedBranch == null || selectedSport == null) 
                            ? "Complete filters above..." 
                            : "Select Batch Time",
                        value: selectedBatch,
                        items: batches,
                        icon: Icons.access_time_filled,
                        isBatch: true,
                        onChanged: (val) => setState(() => selectedBatch = val),
                      ),
                      const SizedBox(height: 40),

                      SizedBox(
                        width: double.infinity,
                        height: 55,
                        child: ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: brandTeal,
                            shape: RoundedRectangleType(12),
                            elevation: 2,
                          ),
                          onPressed: assignCoach,
                          child: const Text("CONFIRM ASSIGNMENT", 
                            style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold, letterSpacing: 1.2)),
                        ),
                      )
                    ],
                  ),
                ),
              ],
            ),
          ),
    );
  }

  Widget _buildHeader() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text("Assign Coach", style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold, color: Color(0xFF1B3D2F))),
        const SizedBox(height: 4),
        Text("Link a coach to a specific branch and batch schedule.", 
          style: TextStyle(fontSize: 14, color: Colors.grey[600])),
      ],
    );
  }

  Widget _buildLabel(String text) {
    return Align(
      alignment: Alignment.centerLeft,
      child: Padding(
        padding: const EdgeInsets.only(bottom: 8.0, left: 4),
        child: Text(text, style: const TextStyle(fontWeight: FontWeight.w600, color: Colors.black87)),
      ),
    );
  }

  Widget _buildDropdown({
    required String hint,
    required String? value,
    required List items,
    required IconData icon,
    required ValueChanged<String?> onChanged,
    bool isBatch = false,
  }) {
    return DropdownButtonFormField<String>(
      value: value,
      decoration: InputDecoration(
        prefixIcon: Icon(icon, color: brandTeal, size: 20),
        filled: true,
        fillColor: const Color(0xFFF8F9FA),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      ),
      hint: Text(hint, style: TextStyle(fontSize: 14, color: Colors.grey[500])),
      isExpanded: true,
      items: items.map((item) {
        String displayText = isBatch 
            ? "${item['name']} (${item['time']})" 
            : (item['name'] ?? "Unknown");
        return DropdownMenuItem<String>(
          value: item['id'].toString(),
          child: Text(displayText, style: const TextStyle(fontSize: 14)),
        );
      }).toList(),
      onChanged: onChanged,
    );
  }

  RoundedRectangleBorder RoundedRectangleType(double radius) => 
      RoundedRectangleBorder(borderRadius: BorderRadius.circular(radius));
}