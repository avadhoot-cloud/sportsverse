import 'package:flutter/material.dart';

class AdminDisputeQueueScreen extends StatefulWidget {
  const AdminDisputeQueueScreen({Key? key}) : super(key: key);

  @override
  State<AdminDisputeQueueScreen> createState() => _AdminDisputeQueueScreenState();
}

class _AdminDisputeQueueScreenState extends State<AdminDisputeQueueScreen> {
  // Mock data representing the dispute queue from Django backend
  final List<Map<String, dynamic>> _disputes = [
    {
      "id": "match-8f92-a1b2",
      "reporter": {"name": "Alice", "rel": 90.0, "score": 11},
      "opponent": {"name": "Bob", "rel": 45.0, "score": 8},
      "fraud_score": 0.35,
      "date": "2026-02-28",
      "evidence": "https://s3.url/video_clip.mp4"
    },
    {
      "id": "match-9c1a-d4f5",
      "reporter": {"name": "Charlie", "rel": 60.0, "score": 11},
      "opponent": {"name": "Dave", "rel": 85.0, "score": 9},
      "fraud_score": 0.88, // Highly anomalous
      "date": "2026-02-28",
      "evidence": null
    }
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F7F9),
      appBar: AppBar(
        title: const Text("Admin Dispute Queue", style: TextStyle(color: Colors.black)),
        backgroundColor: Colors.white,
        elevation: 1,
        iconTheme: const IconThemeData(color: Colors.black),
      ),
      body: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: _disputes.length,
        itemBuilder: (context, index) {
          final d = _disputes[index];
          final r = d["reporter"];
          final o = d["opponent"];
          final bool highFraud = d["fraud_score"] > 0.7;

          return Card(
            margin: const EdgeInsets.only(bottom: 16),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text("Match ID: ${d["id"].split('-')[1]}", style: TextStyle(color: Colors.grey[600], fontSize: 12)),
                      if (highFraud)
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(color: Colors.red[50], borderRadius: BorderRadius.circular(8)),
                          child: Text("! High Fraud Score: ${d["fraud_score"]}", style: const TextStyle(color: Colors.red, fontSize: 12, fontWeight: FontWeight.bold)),
                        ),
                    ],
                  ),
                  const Divider(height: 24),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      _buildPlayerSide("Reporter", r),
                      const Text(" VS ", style: TextStyle(fontWeight: FontWeight.bold, color: Colors.grey)),
                      _buildPlayerSide("Opponent", o),
                    ],
                  ),
                  const SizedBox(height: 16),
                  if (d["evidence"] != null)
                    TextButton.icon(
                      icon: const Icon(Icons.attachment),
                      label: const Text("View Evidence Attachment"),
                      onPressed: () {},
                    ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton(
                          onPressed: () {},
                          style: OutlinedButton.styleFrom(foregroundColor: Colors.green),
                          child: const Text("Favor Reporter"),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: OutlinedButton(
                          onPressed: () {},
                          style: OutlinedButton.styleFrom(foregroundColor: Colors.orange),
                          child: const Text("Favor Opponent"),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: ElevatedButton(
                          onPressed: () {},
                          style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
                          child: const Text("Nullify Match", style: TextStyle(color: Colors.white)),
                        ),
                      ),
                    ],
                  )
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildPlayerSide(String role, Map<String, dynamic> player) {
    return Column(
      children: [
        Text(role, style: TextStyle(fontSize: 12, color: Colors.grey[600])),
        const SizedBox(height: 4),
        Text(player["name"], style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
        Text("Reported: ${player["score"]}", style: const TextStyle(color: Colors.black87)),
        const SizedBox(height: 4),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
          decoration: BoxDecoration(
            color: player["rel"] > 70 ? Colors.green[50] : Colors.orange[50],
            borderRadius: BorderRadius.circular(6)
          ),
          child: Text("Rel: ${player["rel"]}", 
            style: TextStyle(
              fontSize: 11, 
              color: player["rel"] > 70 ? Colors.green[800] : Colors.orange[800],
              fontWeight: FontWeight.bold
            )
          ),
        )
      ],
    );
  }
}
