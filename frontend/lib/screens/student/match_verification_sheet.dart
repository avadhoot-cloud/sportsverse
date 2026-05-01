import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'dart:convert';
import 'package:sportsverse_app/api/api_client.dart';
import 'package:sportsverse_app/providers/auth_provider.dart';

class MatchVerificationSheet extends StatefulWidget {
  final String matchId;
  final String reporterName;
  final int reporterScore;
  final int myScore;

  const MatchVerificationSheet({
    Key? key,
    required this.matchId,
    required this.reporterName,
    required this.reporterScore,
    required this.myScore,
  }) : super(key: key);

  @override
  State<MatchVerificationSheet> createState() => _MatchVerificationSheetState();
}

class _MatchVerificationSheetState extends State<MatchVerificationSheet> {
  bool _isEditing = false;
  bool _isLoading = false;
  
  late int _editedReporterScore;
  late int _editedMyScore;

  @override
  void initState() {
    super.initState();
    _editedReporterScore = widget.reporterScore;
    _editedMyScore = widget.myScore;
  }

  Future<void> _submitVerification(String action, {String evidenceUrl = ""}) async {
    setState(() => _isLoading = true);

    try {
      final body = <String, dynamic>{'action': action};
      
      if (action == 'COUNTER') {
        body['opponent_score'] = {
          'sets': [
            {'set': 1, 'reporter_score': _editedReporterScore, 'opponent_score': _editedMyScore}
          ]
        };
      } else if (action == 'DISPUTE') {
        body['evidence_url'] = evidenceUrl;
      }

      final res = await apiClient.post('/api/ratings/matches/${widget.matchId}/verify/', body);

      if (res.statusCode == 200) {
        if (!mounted) return;
        Navigator.pop(context, true); // return true = success
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Action submitted successfully!'), backgroundColor: Colors.green),
        );
      } else {
        throw Exception(json.decode(res.body)['error'] ?? 'Network Error');
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: ${e.toString()}'), backgroundColor: Colors.red),
      );
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.only(topLeft: Radius.circular(24), topRight: Radius.circular(24)),
      ),
      child: _isLoading 
        ? const SizedBox(height: 200, child: Center(child: CircularProgressIndicator(color: Color(0xFF1B3D2F))))
        : Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                "Match Verification",
                style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),
              Text(
                "${widget.reporterName} reported the following score. Do you agree?",
                style: TextStyle(color: Colors.grey[600], fontSize: 14),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 24),

              // Score Display OR Editing
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                   _buildScoreCol(widget.reporterName, _isEditing ? _editedReporterScore : widget.reporterScore, 
                        (val) => setState(() => _editedReporterScore = val)),
                   const Text(":", style: TextStyle(fontSize: 32, fontWeight: FontWeight.bold)),
                   _buildScoreCol("You", _isEditing ? _editedMyScore : widget.myScore, 
                        (val) => setState(() => _editedMyScore = val)),
                ],
              ),
              
              const SizedBox(height: 32),

              if (!_isEditing) ...[
                ElevatedButton(
                  onPressed: () => _submitVerification('CONFIRM'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF2E7D32),
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  child: const Text("Confirm Match Score", style: TextStyle(fontSize: 16)),
                ),
                const SizedBox(height: 12),
                OutlinedButton(
                  onPressed: () => setState(() => _isEditing = true),
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  child: const Text("Edit Score (Counter)", style: TextStyle(color: Colors.black, fontSize: 16)),
                ),
                TextButton(
                  onPressed: () => _submitVerification('DISPUTE', evidenceUrl: "upload/path/placeholder.jpg"),
                  child: const Text("Dispute Match", style: TextStyle(color: Colors.red)),
                )
              ] else ...[
                ElevatedButton(
                  onPressed: () => _submitVerification('COUNTER'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFE65100), // Orange for counter
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  child: const Text("Submit Counter Score", style: TextStyle(fontSize: 16)),
                ),
                TextButton(
                  onPressed: () => setState(() => _isEditing = false),
                  child: const Text("Cancel editing", style: TextStyle(color: Colors.grey)),
                )
              ]
            ],
          ),
    );
  }

  Widget _buildScoreCol(String label, int val, Function(int) onChange) {
    if (!_isEditing) {
      return Column(
        children: [
          Text(label, style: const TextStyle(fontWeight: FontWeight.w600)),
          const SizedBox(height: 8),
          Text("$val", style: const TextStyle(fontSize: 40, fontWeight: FontWeight.bold)),
        ],
      );
    }
    // Editable view
    return Column(
      children: [
        Text(label, style: const TextStyle(color: Colors.grey)),
        IconButton(icon: const Icon(Icons.keyboard_arrow_up), onPressed: () => onChange(val + 1)),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          decoration: BoxDecoration(color: Colors.grey[100], borderRadius: BorderRadius.circular(12)),
          child: Text("$val", style: const TextStyle(fontSize: 28, fontWeight: FontWeight.bold)),
        ),
        IconButton(icon: const Icon(Icons.keyboard_arrow_down), onPressed: () => onChange(val > 0 ? val - 1 : 0)),
      ],
    );
  }
}
