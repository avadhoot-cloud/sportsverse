import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:web_socket_channel/web_socket_channel.dart';
import '../../auth/providers/auth_provider.dart';
import '../../../core/constants/api_constants.dart';

class VideoProcessingScreen extends ConsumerStatefulWidget {
  final String sessionId;
  const VideoProcessingScreen({super.key, required this.sessionId});

  @override
  ConsumerState<VideoProcessingScreen> createState() => _VideoProcessingScreenState();
}

class _VideoProcessingScreenState extends ConsumerState<VideoProcessingScreen>
    with SingleTickerProviderStateMixin {
  WebSocketChannel? _channel;
  late AnimationController _pulseController;

  int _stepIndex = 0;
  final List<String> _steps = [
    "Detecting player...",
    "Tracking ball...",
    "Classifying strokes...",
    "Computing metrics...",
    "Finalising results...",
  ];

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat(reverse: true);

    // Advance the step label every 5 seconds for visual feedback
    _advanceSteps();
    _connectWebSocket();
  }

  void _advanceSteps() async {
    for (var i = 0; i < _steps.length; i++) {
      await Future.delayed(const Duration(seconds: 5));
      if (!mounted) return;
      setState(() => _stepIndex = i.clamp(0, _steps.length - 1));
    }
  }

  void _connectWebSocket() {
    // Read the JWT token from the auth provider to authenticate the WS connection
    final token = ref.read(authTokenProvider);
    if (token == null) return;

    final wsBase = ApiConstants.baseUrl
        .replaceFirst('http://', 'ws://')
        .replaceFirst('https://', 'wss://');

    final uri = Uri.parse(
      '$wsBase/ws/video/status/${widget.sessionId}/?token=$token',
    );

    _channel = WebSocketChannel.connect(uri);

    _channel!.stream.listen(
      (message) {
        if (!mounted) return;
        final data = jsonDecode(message as String) as Map<String, dynamic>;
        final status = data['status'] as String?;

        if (status == 'completed') {
          _channel?.sink.close();
          context.go('/session-detail/${widget.sessionId}');
        } else if (status == 'error') {
          _channel?.sink.close();
          final errMsg = data['error'] ?? 'Unknown processing error';
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Processing failed: $errMsg')),
          );
          context.go('/dashboard');
        }
        // 'processing' status: remain on screen, no navigation
      },
      onError: (e) {
        // WebSocket error — degrade message shown; user can return manually
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Lost connection to server. Check back in History.'),
          ),
        );
      },
      cancelOnError: true,
    );
  }

  @override
  void dispose() {
    _channel?.sink.close();
    _pulseController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0D1117),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            AnimatedBuilder(
              animation: _pulseController,
              builder: (_, __) => Container(
                width: 80 + _pulseController.value * 20,
                height: 80 + _pulseController.value * 20,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: const Color(0xFF00E5A0)
                      .withValues(alpha: 0.1 + _pulseController.value * 0.15),
                ),
                child: const Center(
                  child: CircularProgressIndicator(
                    color: Color(0xFF00E5A0),
                    strokeWidth: 4,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 40),
            Text(
              _steps[_stepIndex],
              style: const TextStyle(
                color: Colors.white,
                fontSize: 22,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 12),
            const Text(
              'TennisIQ AI is analysing your recording.',
              style: TextStyle(color: Colors.white54, fontSize: 14),
            ),
            const SizedBox(height: 8),
            Text(
              'Session #${widget.sessionId}',
              style: const TextStyle(color: Colors.white24, fontSize: 11),
            ),
            const SizedBox(height: 40),
            // Step progress dots
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: List.generate(_steps.length, (i) {
                final active = i <= _stepIndex;
                return AnimatedContainer(
                  duration: const Duration(milliseconds: 300),
                  margin: const EdgeInsets.symmetric(horizontal: 4),
                  width: active ? 20 : 8,
                  height: 8,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(4),
                    color: active
                        ? const Color(0xFF00E5A0)
                        : Colors.white12,
                  ),
                );
              }),
            ),
          ],
        ),
      ),
    );
  }
}
