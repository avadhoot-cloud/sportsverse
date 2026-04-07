import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:camera/camera.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:dio/dio.dart';
import '../../auth/providers/auth_provider.dart';

class VideoSessionScreen extends ConsumerStatefulWidget {
  const VideoSessionScreen({super.key});

  @override
  ConsumerState<VideoSessionScreen> createState() => _VideoSessionScreenState();
}

class _VideoSessionScreenState extends ConsumerState<VideoSessionScreen> {
  CameraController? _controller;
  List<CameraDescription> _cameras = [];
  bool _isInit = false;
  bool _isRecording = false;
  
  XFile? _recordedVideo;
  
  Timer? _timer;
  int _seconds = 0;
  
  bool _isUploading = false;
  double _uploadProgress = 0.0;

  @override
  void initState() {
    super.initState();
    _initCamera();
  }

  Future<void> _initCamera() async {
    _cameras = await availableCameras();
    if (_cameras.isNotEmpty) {
      _controller = CameraController(_cameras.first, ResolutionPreset.high);
      await _controller!.initialize();
      if (!mounted) return;
      setState(() => _isInit = true);
    }
  }

  Future<void> _toggleRecording() async {
    if (_controller == null || !_controller!.value.isInitialized) return;

    if (_isRecording) {
      // STOP recording
      final file = await _controller!.stopVideoRecording();
      _timer?.cancel();
      setState(() {
        _isRecording = false;
        _recordedVideo = file;
      });
    } else {
      // START recording
      await _controller!.startVideoRecording();
      _seconds = 0;
      _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
        setState(() => _seconds++);
      });
      setState(() {
        _isRecording = true;
        _recordedVideo = null;
      });
    }
  }

  Future<void> _analyzeVideo() async {
    if (_recordedVideo == null) return;
    
    setState(() => _isUploading = true);
    
    try {
      final api = ref.read(apiServiceProvider);
      
      // 1. Stub the Session dynamically
      final sessionRes = await api.client.post('/sessions/sessions/', data: {
        'date': DateTime.now().toIso8601String(),
        'duration_seconds': _seconds,
        'mode': 'video_only',
        'notes': 'Recorded physically bridging CV Pipeline'
      });
      
      final sessionId = sessionRes.data['id'];

      // 2. Wrap Multi-part parsing 
      FormData formData = FormData.fromMap({
        'session_id': sessionId,
        'video': await MultipartFile.fromFile(_recordedVideo!.path, filename: 'match.mp4')
      });
      
      await api.client.post(
        '/video/upload/',
        data: formData,
        onSendProgress: (sent, total) {
          setState(() {
            _uploadProgress = sent / total;
          });
        },
      );
      
      // 3. Move cleanly to the polling boundary sequentially
      if (mounted) {
        context.go('/video-processing/$sessionId');
      }
      
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Upload error: $e')));
      setState(() => _isUploading = false);
    }
  }

  void _discardVideo() {
    setState(() {
      _recordedVideo = null;
      _seconds = 0;
    });
  }

  @override
  void dispose() {
    _controller?.dispose();
    _timer?.cancel();
    super.dispose();
  }

  String get _timeString {
    final m = (_seconds / 60).floor().toString().padLeft(2, '0');
    final s = (_seconds % 60).toString().padLeft(2, '0');
    return '$m:$s';
  }

  @override
  Widget build(BuildContext context) {
    if (!_isInit) {
      return const Scaffold(body: Center(child: CircularProgressIndicator(color: Color(0xFF00E5A0))));
    }

    return Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: Stack(
                alignment: Alignment.center,
                children: [
                  if (_recordedVideo == null)
                    CameraPreview(_controller!)
                  else
                    Container(
                      color: const Color(0xFF161B22),
                      child: const Center(
                        child: Icon(Icons.video_file, size: 64, color: Colors.white54),
                      ),
                    ),
                    
                  if (_isRecording)
                    Positioned(
                      top: 16,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                        decoration: BoxDecoration(color: Colors.redAccent.withOpacity(0.8), borderRadius: BorderRadius.circular(16)),
                        child: Row(
                          children: [
                            const Icon(Icons.circle, color: Colors.white, size: 12),
                            const SizedBox(width: 8),
                            Text(_timeString, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                          ],
                        ),
                      ),
                    ),
                    
                  if (_isUploading)
                    Positioned.fill(
                      child: Container(
                        color: Colors.black87,
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const CircularProgressIndicator(color: Color(0xFF00E5A0)),
                            const SizedBox(height: 16),
                            Text('Uploading... ${(_uploadProgress * 100).toStringAsFixed(0)}%', style: const TextStyle(color: Colors.white, fontSize: 18))
                          ],
                        ),
                      ),
                    ),
                ],
              ),
            ),
            
            // Bottom Controls Layer
            Container(
              padding: const EdgeInsets.all(24),
              color: const Color(0xFF0D1117),
              child: _recordedVideo == null 
                  ? Center(
                      child: FloatingActionButton(
                        onPressed: _toggleRecording,
                        backgroundColor: _isRecording ? Colors.redAccent : Colors.white,
                        child: Icon(
                          _isRecording ? Icons.stop : Icons.fiber_manual_record,
                          color: _isRecording ? Colors.white : Colors.redAccent,
                          size: 32,
                        ),
                      ),
                    )
                  : Row(
                      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                      children: [
                        ElevatedButton.icon(
                          onPressed: _discardVideo,
                          icon: const Icon(Icons.delete),
                          label: const Text('Discard'),
                          style: ElevatedButton.styleFrom(backgroundColor: Colors.white12, foregroundColor: Colors.white),
                        ),
                        ElevatedButton.icon(
                          onPressed: _analyzeVideo,
                          icon: const Icon(Icons.analytics),
                          label: const Text('Analyze'),
                          style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF00E5A0), foregroundColor: Colors.black),
                        ),
                      ],
                    ),
            ),
          ],
        ),
      ),
    );
  }
}
