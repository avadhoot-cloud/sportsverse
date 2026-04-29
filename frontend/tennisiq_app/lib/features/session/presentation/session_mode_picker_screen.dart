import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

class SessionModePickerScreen extends StatelessWidget {
  const SessionModePickerScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 24.0),
                child: Text('Start Session', style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold, color: Colors.white)),
              ),
              _ModeCard(
                title: 'Video Only',
                description: 'Record your match via camera to analyze court movement, shot tracking, and unforced errors using AI.',
                icon: Icons.videocam,
                onStart: () => context.push('/session-active/video_only'),
              ),
              const SizedBox(height: 16),
              _ModeCard(
                title: 'Upload Full Video',
                description: 'Upload an existing match video from your device to analyze performance using our Computer Vision engine.',
                icon: Icons.upload_file,
                onStart: () => context.push('/session-active/video_only'),
              ),
              const SizedBox(height: 16),
              _ModeCard(
                title: 'Watch Only',
                description: 'Pair your smartwatch via BLE to track heart rate, peak acceleration, fatigue, and swing intensity.',
                icon: Icons.watch,
                onStart: () => context.push('/session-active/watch_only'),
              ),
              const SizedBox(height: 16),
              _ModeCard(
                title: 'Fusion Mode',
                description: 'Combine simultaneous Video and Watch data to get the ultimate TennisIQ analysis and timing consistency scores.',
                icon: Icons.merge_type,
                primary: true,
                onStart: () => context.push('/session-active/fusion'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ModeCard extends StatelessWidget {
  final String title;
  final String description;
  final IconData icon;
  final bool primary;
  final VoidCallback onStart;

  const _ModeCard({
    required this.title,
    required this.description,
    required this.icon,
    required this.onStart,
    this.primary = false,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF161B22),
        borderRadius: BorderRadius.circular(16),
        border: primary ? Border.all(color: const Color(0xFF00E5A0), width: 2) : null,
      ),
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, size: 40, color: primary ? const Color(0xFF00E5A0) : Colors.white),
                const SizedBox(width: 16),
                Text(title, style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: primary ? const Color(0xFF00E5A0) : Colors.white)),
              ],
            ),
            const SizedBox(height: 16),
            Text(description, style: const TextStyle(color: Colors.white70, fontSize: 14, height: 1.5)),
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: onStart,
                style: ElevatedButton.styleFrom(
                  backgroundColor: primary ? const Color(0xFF00E5A0) : Colors.white12,
                  foregroundColor: primary ? const Color(0xFF0D1117) : Colors.white,
                ),
                child: const Text('START'),
              ),
            )
          ],
        ),
      ),
    );
  }
}
