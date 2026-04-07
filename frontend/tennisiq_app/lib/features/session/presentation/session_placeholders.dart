import 'package:flutter/material.dart';

class SessionDetailScreen extends StatelessWidget {
  final String sessionId;
  const SessionDetailScreen({super.key, required this.sessionId});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('Session #$sessionId Details')),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.analytics, size: 64, color: Color(0xFF00E5A0)),
            const SizedBox(height: 24),
            const Text('Comprehensive Stat Report Placeholder', style: TextStyle(color: Colors.white, fontSize: 18)),
            const SizedBox(height: 12),
            Text('Evaluating DB Ref: $sessionId', style: const TextStyle(color: Colors.white54)),
          ],
        ),
      ),
    );
  }
}

class SessionActiveScreen extends StatelessWidget {
  final String mode;
  const SessionActiveScreen({super.key, required this.mode});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('Active Match: ${mode.toUpperCase()}'), automaticallyImplyLeading: false),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const CircularProgressIndicator(color: Color(0xFF00E5A0)),
            const SizedBox(height: 24),
            const Text('Recording live analytical models...', style: TextStyle(color: Colors.white)),
            const SizedBox(height: 48),
            ElevatedButton(
              onPressed: () => Navigator.of(context).pop(),
              style: ElevatedButton.styleFrom(backgroundColor: Colors.redAccent),
              child: const Text('STOP MATCH', style: TextStyle(color: Colors.white)),
            )
          ],
        ),
      ),
    );
  }
}
