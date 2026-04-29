import 'dart:async';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:camera/camera.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:dio/dio.dart';
import 'package:file_picker/file_picker.dart';
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

  Future<void> _pickVideo() async {
    FilePickerResult? result = await FilePicker.pickFiles(
      type: FileType.video,
      withData: kIsWeb,
    );

    if (result != null) {
      if (kIsWeb) {
        final bytes = result.files.single.bytes;
        if (bytes != null) {
            setState(() {
              _recordedVideo = XFile.fromData(bytes, name: result.files.single.name);
              _seconds = 0;
            });
        }
      } else {
        setState(() {
          _recordedVideo = XFile(result.files.single.path!, name: result.files.single.name);
          _seconds = 0;
        });
      }
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
      MultipartFile fileData;
      if (kIsWeb) {
        final bytes = await _recordedVideo!.readAsBytes();
        fileData = MultipartFile.fromBytes(bytes, filename: _recordedVideo!.name.isEmpty ? 'match.mp4' : _recordedVideo!.name);
      } else {
        fileData = await MultipartFile.fromFile(_recordedVideo!.path, filename: _recordedVideo!.name.isEmpty ? 'match.mp4' : _recordedVideo!.name);
      }

      FormData formData = FormData.fromMap({
        'session_id': sessionId,
        'video': fileData
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
      
    } on DioException catch (e) {
      setState(() => _isUploading = false);
      if (e.response != null && e.response?.statusCode == 400) {
        final data = e.response?.data;
        if (data != null && data['error'] == 'validation_failed') {
          final alerts = List<String>.from(data['alerts'] ?? []);
          if (!mounted) return;
          showDialog(
            context: context,
            builder: (ctx) => AlertDialog(
              backgroundColor: const Color(0xFF161B22),
              title: const Text('Validation Failed', style: TextStyle(color: Colors.redAccent)),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Your video was rejected by the tracking engine:', style: TextStyle(color: Colors.white70)),
                  const SizedBox(height: 16),
                  ...alerts.map((a) => Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Icon(Icons.error_outline, color: Colors.redAccent, size: 16),
                        const SizedBox(width: 8),
                        Expanded(child: Text(a, style: const TextStyle(color: Colors.white))),
                      ],
                    ),
                  )).toList()
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(ctx).pop(),
                  child: const Text('TRY AGAIN', style: TextStyle(color: Color(0xFF00E5A0))),
                )
              ],
            )
          );
          return;
        }
      }
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Upload error: $e')));
    } catch (e) {
      setState(() => _isUploading = false);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Upload error: $e')));
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
                    Stack(
                      fit: StackFit.expand,
                      children: [
                        CameraPreview(_controller!),
                        CustomPaint(
                          painter: _CourtSetupOverlayPainter(),
                        )
                      ],
                    )
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
                        decoration: BoxDecoration(color: Colors.redAccent.withValues(alpha: 0.8), borderRadius: BorderRadius.circular(16)),
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
                  ? SafeArea(
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                        children: [
                          ElevatedButton.icon(
                            onPressed: _pickVideo,
                            icon: const Icon(Icons.upload_file),
                            label: const Text('Upload Video'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.white12, 
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16)
                            ),
                          ),
                          FloatingActionButton(
                            onPressed: _toggleRecording,
                            backgroundColor: _isRecording ? Colors.redAccent : Colors.white,
                            child: Icon(
                              _isRecording ? Icons.stop : Icons.fiber_manual_record,
                              color: _isRecording ? Colors.white : Colors.redAccent,
                              size: 32,
                            ),
                          ),
                          const SizedBox(width: 40), // Spacer
                        ],
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

class _CourtSetupOverlayPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = const Color(0xFF00E5A0).withValues(alpha: 0.6)
      ..strokeWidth = 2
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    double dashWidth = 10, dashSpace = 8;
    
    void drawDashedLine(Offset p1, Offset p2) {
      double distance = (p2 - p1).distance;
      double dx = (p2.dx - p1.dx) / distance;
      double dy = (p2.dy - p1.dy) / distance;
      
      double currX = p1.dx;
      double currY = p1.dy;
      double drawn = 0;
      
      while (drawn < distance) {
        canvas.drawLine(
          Offset(currX, currY),
          Offset(currX + dx * dashWidth, currY + dy * dashWidth),
          paint,
        );
        currX += dx * (dashWidth + dashSpace);
        currY += dy * (dashWidth + dashSpace);
        drawn += dashWidth + dashSpace;
      }
    }

    // Court polygon boundary bounds mapping optimally the 2377x1097 cm plane mapping scaled
    final p1 = Offset(size.width * 0.2, size.height * 0.4);
    final p2 = Offset(size.width * 0.8, size.height * 0.4);
    final p3 = Offset(size.width * 0.95, size.height * 0.85);
    final p4 = Offset(size.width * 0.05, size.height * 0.85);

    drawDashedLine(p1, p2);
    drawDashedLine(p2, p3);
    drawDashedLine(p3, p4);
    drawDashedLine(p4, p1);
    
    // Draw horizon alignment line
    paint.color = Colors.redAccent.withValues(alpha: 0.5);
    drawDashedLine(Offset(0, size.height * 0.25), Offset(size.width, size.height * 0.25));
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
