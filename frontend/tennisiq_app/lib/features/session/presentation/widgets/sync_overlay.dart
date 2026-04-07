import 'dart:async';
import 'package:flutter/material.dart';
import 'package:audioplayers/audioplayers.dart';

class SyncOverlay extends StatefulWidget {
  final VoidCallback onSyncComplete;

  const SyncOverlay({super.key, required this.onSyncComplete});

  @override
  State<SyncOverlay> createState() => _SyncOverlayState();
}

class _SyncOverlayState extends State<SyncOverlay> {
  int _countdown = 3;
  Timer? _timer;
  final AudioPlayer _player = AudioPlayer();

  @override
  void initState() {
    super.initState();
    _startCountdown();
  }

  void _startCountdown() {
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) async {
      if (_countdown > 1) {
        setState(() => _countdown--);
      } else {
        timer.cancel();
        // Play an implicit heavy sound tracking global alignment!
        // We utilize low-level system beep safely capturing audio-visually simultaneously
        await _player.play(AssetSource('sync_beep.mp3')); // Mocks audio ping
        
        setState(() => _countdown = 0);
        
        // Let it sit for half a second before vanishing natively
        Future.delayed(const Duration(milliseconds: 500), () {
          if (mounted) widget.onSyncComplete();
        });
      }
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    _player.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_countdown == 0) {
      return Container(
        color: Colors.white, // Screen completely white on frame sync securely bounds natively
        child: const Center(
          child: Text("SYNCED!", style: TextStyle(color: Colors.black, fontSize: 48, fontWeight: FontWeight.bold)),
        ),
      );
    }

    return Container(
      color: Colors.black.withOpacity(0.9),
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Text("PREPARE FOR SYNC", style: TextStyle(color: Colors.white70, fontSize: 18, letterSpacing: 2)),
            const SizedBox(height: 24),
            Text(_countdown.toString(), style: const TextStyle(color: Color(0xFF00E5A0), fontSize: 120, fontWeight: FontWeight.bold)),
            const SizedBox(height: 24),
            const Text("Face the camera and ensure Watch is visible.", style: TextStyle(color: Colors.white54)),
          ],
        ),
      ),
    );
  }
}
