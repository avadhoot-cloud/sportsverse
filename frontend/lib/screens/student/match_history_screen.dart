import 'package:flutter/material.dart';
import 'dart:convert';
import 'package:sportsverse_app/api/api_client.dart';
import 'package:provider/provider.dart';
import 'package:sportsverse_app/providers/auth_provider.dart';
import 'package:sportsverse_app/screens/student/match_verification_sheet.dart';

class MatchHistoryScreen extends StatefulWidget {
  const MatchHistoryScreen({super.key});

  @override
  State<MatchHistoryScreen> createState() => _MatchHistoryScreenState();
}

class _MatchHistoryScreenState extends State<MatchHistoryScreen> {
  List<dynamic> _matches = [];
  bool _isLoading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _fetchHistory();
  }

  Future<void> _fetchHistory() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final response = await apiClient.get('/api/ratings/matches/history/');
      if (response.statusCode == 200) {
        setState(() {
          _matches = json.decode(response.body);
          _isLoading = false;
        });
      } else {
        throw Exception("Failed to load history");
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString().replaceAll('Exception: ', '');
        _isLoading = false;
      });
    }
  }

  void _openVerificationSheet(String matchId, String reporterName, int reporterScore, int myScore) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => MatchVerificationSheet(
        matchId: matchId,
        reporterName: reporterName,
        reporterScore: reporterScore,
        myScore: myScore,
      ),
    ).then((_) => _fetchHistory()); // refresh on close
  }

  Color _getStatusColor(String status) {
    switch (status) {
      case 'PENDING': return Colors.orange;
      case 'CONFIRMED': return Colors.green;
      case 'AUTO_RESOLVED': return Colors.teal;
      case 'DISPUTED': return Colors.red;
      case 'REJECTED': return Colors.grey;
      case 'PROCESSED': return Colors.blue;
      default: return Colors.black;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F7F9),
      appBar: AppBar(
        title: const Text("Match History", style: TextStyle(color: Colors.black)),
        backgroundColor: Colors.white,
        elevation: 0.5,
        iconTheme: const IconThemeData(color: Colors.black),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _fetchHistory,
          )
        ],
      ),
      body: _isLoading 
        ? const Center(child: CircularProgressIndicator(color: Color(0xFF1B3D2F)))
        : _error != null
            ? Center(child: Text("Error: $_error\nPull to refresh", textAlign: TextAlign.center))
            : RefreshIndicator(
                onRefresh: _fetchHistory,
                child: _matches.isEmpty
                  ? ListView(
                      physics: const AlwaysScrollableScrollPhysics(),
                      children: const [
                        SizedBox(height: 100),
                        Center(child: Text("No matches found."))
                      ],
                    )
                  : ListView.builder(
                      padding: const EdgeInsets.all(16),
                      itemCount: _matches.length,
                      itemBuilder: (context, index) {
                        final m = _matches[index];
                        final isPending = m['status'] == 'PENDING';
                        
                        // Parse score JSON safely
                        String scoreDisplay = "No Score";
                        int reporterScore = 0;
                        int myScore = 0;
                        try {
                           final sets = m['score']['sets'] as List<dynamic>;
                           if (sets.isNotEmpty) {
                             reporterScore = sets[0]['reporter_score'] ?? 0;
                             myScore = sets[0]['opponent_score'] ?? 0;
                           }
                           scoreDisplay = sets.map((s) => "${s['reporter_score']}-${s['opponent_score']}").join(', ');
                        } catch (_) {}

                        final currentUser = context.read<AuthProvider>().currentUser?.username ?? '';
                        final isReporter = m['reporter'].toString().toLowerCase() == currentUser.toLowerCase();

                        return Card(
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                          elevation: 2,
                          margin: const EdgeInsets.only(bottom: 16),
                          child: InkWell(
                            borderRadius: BorderRadius.circular(16),
                            onTap: (isPending && !isReporter) ? () => _openVerificationSheet(m['match_id'].toString(), m['reporter'].toString(), reporterScore, myScore) : null,
                            child: Padding(
                              padding: const EdgeInsets.all(16.0),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                    children: [
                                      Text(
                                        "vs pending opponent", // Simplification: we might want opponent username 
                                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                                      ),
                                      Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                        decoration: BoxDecoration(
                                          color: _getStatusColor(m['status']).withValues(alpha: 0.15),
                                          borderRadius: BorderRadius.circular(20),
                                        ),
                                        child: Text(
                                          m['status'],
                                          style: TextStyle(
                                            color: _getStatusColor(m['status']),
                                            fontWeight: FontWeight.bold,
                                            fontSize: 12
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 8),
                                  Row(
                                    children: [
                                      const Icon(Icons.sports_tennis, size: 16, color: Colors.grey),
                                      const SizedBox(width: 4),
                                      Text(m['format'], style: const TextStyle(color: Colors.grey)),
                                      const Spacer(),
                                      const Icon(Icons.calendar_today, size: 14, color: Colors.grey),
                                      const SizedBox(width: 4),
                                      Text(m['date'], style: const TextStyle(color: Colors.grey, fontSize: 13)),
                                    ],
                                  ),
                                  const SizedBox(height: 12),
                                  Container(
                                    width: double.infinity,
                                    padding: const EdgeInsets.all(12),
                                    decoration: BoxDecoration(
                                      color: const Color(0xFFF5F7F9),
                                      borderRadius: BorderRadius.circular(10),
                                    ),
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text("Reporter: ${m['reporter']}", style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                                        const SizedBox(height: 4),
                                        Text("Score: $scoreDisplay", style: const TextStyle(fontSize: 14)),
                                      ],
                                    ),
                                  ),
                                  if (isPending) ...[
                                    const SizedBox(height: 12),
                                    Center(
                                      child: Text(
                                        isReporter ? "Waiting for Opponent to Verify" : "Tap to Verify or Dispute", 
                                        style: TextStyle(
                                          color: isReporter ? Colors.grey : const Color(0xFF1B3D2F), 
                                          fontWeight: FontWeight.bold, 
                                          fontSize: 13
                                        )
                                      ),
                                    )
                                  ]
                                ],
                              ),
                            ),
                          ),
                        );
                      }
                    ),
              )
    );
  }
}
