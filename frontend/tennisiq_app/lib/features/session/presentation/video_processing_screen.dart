import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../auth/providers/auth_provider.dart';

class VideoProcessingScreen extends ConsumerStatefulWidget {
  final String sessionId;
  const VideoProcessingScreen({super.key, required this.sessionId});

  @override
  ConsumerState<VideoProcessingScreen> createState() => _VideoProcessingScreenState();
}

class _VideoProcessingScreenState extends ConsumerState<VideoProcessingScreen> {
  Timer? _pollingTimer;
  int _stepIndex = 0;
  
  final List<String> _steps = [
    "Detecting player...",
    "Tracking ball...",
    "Classifying shots...",
    "Computing metrics..."
  ];

  @override
  void initState() {
    super.initState();
    _startPolling();
    
    // Aesthetic simulated step progression bounding visually
    Timer.periodic(const Duration(seconds: 4), (t) {
      if (!mounted) return;
      if (_stepIndex < _steps.length - 1) {
        setState(() => _stepIndex++);
      }
    });
  }

  void _startPolling() {
    _pollingTimer = Timer.periodic(const Duration(seconds: 3), (timer) async {
      try {
        final api = ref.read(apiServiceProvider);
        final res = await api.client.get('/video/status/${widget.sessionId}/');
        final status = res.data['status'];
        
        if (status == 'done') {
          timer.cancel();
          if (mounted) {
            // Push directly to detailed arrays preventing unmounting crashes
            context.go('/session-detail/${widget.sessionId}', extra: {'metrics': res.data['metrics']});
          }
        } else if (status == 'error') {
          timer.cancel();
          if (mounted) {
             ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Processing Error: ${res.data['error']}')));
             context.go('/dashboard');
          }
        }
      } catch (e) {
        // Quiet poll failures on timeouts resolving asynchronously
      }
    });
  }

  @override
  void dispose() {
    _pollingTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const CircularProgressIndicator(color: Color(0xFF00E5A0), strokeWidth: 6),
            const SizedBox(height: 32),
            Text(
              _steps[_stepIndex], 
              style: const TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.bold)
            ),
            const SizedBox(height: 16),
            const Text(
              "Our AI algorithms are evaluating your recording.", 
              style: TextStyle(color: Colors.white54, fontSize: 14)
            ),
            const SizedBox(height: 8),
            Text(
              "Session Ref: #${widget.sessionId}", 
              style: const TextStyle(color: Colors.white24, fontSize: 12)
            ),
          ],
        ),
      ),
    );
  }
}
