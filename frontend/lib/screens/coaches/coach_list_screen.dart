import 'package:flutter/material.dart';
import 'package:sportsverse_app/api/api_client.dart';
import 'dart:convert';
import 'coach_enroll_screen.dart';

class CoachListScreen extends StatefulWidget {
  const CoachListScreen({super.key});

  @override
  State<CoachListScreen> createState() => _CoachListScreenState();
}

class _CoachListScreenState extends State<CoachListScreen> {
  List<dynamic> _coaches = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _fetchCoaches();
  }

  Future<void> _fetchCoaches() async {
    final response = await apiClient.get('/api/coaches/list/');
    if (response.statusCode == 200) {
      setState(() {
        _coaches = jsonDecode(response.body);
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Enrolled Coaches"), backgroundColor: Colors.teal),
      floatingActionButton: FloatingActionButton(
        onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (context) => const CoachEnrollScreen())),
        child: const Icon(Icons.add),
      ),
      body: _isLoading 
        ? const Center(child: CircularProgressIndicator())
        : ListView.builder(
            itemCount: _coaches.length,
            itemBuilder: (context, index) => ListTile(
              leading: const CircleAvatar(child: Icon(Icons.person)),
              title: Text(_coaches[index]['full_name']),
              subtitle: Text(_coaches[index]['email']),
              trailing: const Icon(Icons.chevron_right),
            ),
          ),
    );
  }
}