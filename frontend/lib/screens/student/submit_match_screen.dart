import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'dart:convert';

import 'package:sportsverse_app/api/api_client.dart';
import 'package:sportsverse_app/providers/auth_provider.dart';

class SubmitMatchScreen extends StatefulWidget {
  const SubmitMatchScreen({Key? key}) : super(key: key);

  @override
  State<SubmitMatchScreen> createState() => _SubmitMatchScreenState();
}

class _SubmitMatchScreenState extends State<SubmitMatchScreen> {
  final TextEditingController _opponentUsernameController = TextEditingController();
  
  // Support for multiple sets
  List<Map<String, int>> _sets = [
    {'reporter_score': 0, 'opponent_score': 0}
  ];
  
  bool _isLoading = false;
  
  Future<void> _submitMatch() async {
    if (_opponentUsernameController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter an opponent username')),
      );
      return;
    }
    
    final currentUser = context.read<AuthProvider>().currentUser?.username ?? '';
    if (_opponentUsernameController.text.trim().toLowerCase() == currentUser.toLowerCase()) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('You cannot submit a match against yourself!')),
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      final response = await apiClient.post(
        '/api/ratings/matches/',
        {
          'sport_id': 1, // dynamically fetch from Context/Provider normally
          'date': DateTime.now().toIso8601String().split('T')[0],
          'format': 'SINGLES',
          'opponent_username': _opponentUsernameController.text.trim(),
          'score': {
            'sets': List.generate(_sets.length, (index) => {
              'set': index + 1,
              'reporter_score': _sets[index]['reporter_score'],
              'opponent_score': _sets[index]['opponent_score']
            })
          }
        },
      );

      if (response.statusCode == 201) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Match submitted for verification! ⏳'), backgroundColor: Colors.green),
        );
        Navigator.pop(context);
      } else {
        String errorMessage = 'Failed to submit match';
        try {
          errorMessage = json.decode(response.body)['error'] ?? errorMessage;
        } catch (_) {}
        throw Exception(errorMessage);
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
            content: Text(e.toString().replaceAll('Exception: ', '').replaceAll('FormatException: ', 'Invalid format: ')), 
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 4),
        ),
      );
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFB),
      appBar: AppBar(
        title: const Text("Record Match", style: TextStyle(color: Colors.black)),
        backgroundColor: Colors.white,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.black),
      ),
      body: _isLoading 
        ? const Center(child: CircularProgressIndicator(color: Color(0xFF1B3D2F)))
        : Padding(
            padding: const EdgeInsets.all(20.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Text("Select Opponent Username", style: TextStyle(fontWeight: FontWeight.bold)),
                const SizedBox(height: 8),
                TextField(
                  controller: _opponentUsernameController,
                  keyboardType: TextInputType.text,
                  decoration: InputDecoration(
                    hintText: "Enter Opponent Username",
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                    filled: true,
                    fillColor: Colors.white,
                  ),
                ),
                const SizedBox(height: 24),
                
                const Text("Match Score", style: TextStyle(fontWeight: FontWeight.bold)),
                const SizedBox(height: 16),
                
                // Dynamic Set list
                Expanded(
                  child: ListView.builder(
                    itemCount: _sets.length,
                    itemBuilder: (context, index) {
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 24.0),
                        child: Column(
                          children: [
                            Text("Set ${index + 1}", style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.grey)),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                              children: [
                                _buildScoreCarousel("You", _sets[index]['reporter_score']!, (val) {
                                  setState(() => _sets[index]['reporter_score'] = val);
                                }),
                                const Text(":", style: TextStyle(fontSize: 32, fontWeight: FontWeight.bold)),
                                _buildScoreCarousel("Opponent", _sets[index]['opponent_score']!, (val) {
                                  setState(() => _sets[index]['opponent_score'] = val);
                                }),
                              ],
                            ),
                          ],
                        ),
                      );
                    },
                  ),
                ),
                
                // Add/Remove buttons for sets
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    if (_sets.length > 1)
                      IconButton(
                        icon: const Icon(Icons.remove_circle_outline, color: Colors.red),
                        onPressed: () => setState(() => _sets.removeLast()),
                      ),
                    if (_sets.length < 5)
                      TextButton.icon(
                        icon: const Icon(Icons.add),
                        label: const Text("Add Set"),
                        onPressed: () => setState(() => _sets.add({'reporter_score': 0, 'opponent_score': 0})),
                      ),
                  ],
                ),
                
                const SizedBox(height: 16),
                
                ElevatedButton(
                  onPressed: _submitMatch,
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    backgroundColor: const Color(0xFF1B3D2F),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  child: const Text("Submit & Request Verification", style: TextStyle(fontSize: 16, color: Colors.white)),
                ),
              ],
            ),
          ),
    );
  }

  Widget _buildScoreCarousel(String label, int currentScore, Function(int) onChanged) {
    return Column(
      children: [
        Text(label, style: const TextStyle(color: Colors.grey, fontSize: 16)),
        const SizedBox(height: 8),
        IconButton(
          icon: const Icon(Icons.keyboard_arrow_up, size: 32),
          onPressed: () => onChanged(currentScore + 1),
        ),
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10)]
          ),
          child: Text("$currentScore", style: const TextStyle(fontSize: 40, fontWeight: FontWeight.bold)),
        ),
        IconButton(
          icon: const Icon(Icons.keyboard_arrow_down, size: 32),
          onPressed: () => onChanged(currentScore > 0 ? currentScore - 1 : 0),
        ),
      ],
    );
  }
}
