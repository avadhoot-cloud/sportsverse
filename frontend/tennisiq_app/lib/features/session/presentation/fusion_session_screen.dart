import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:camera/camera.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:dio/dio.dart';
import '../../watch/providers/watch_connection_provider.dart';
import '../../auth/providers/auth_provider.dart';
import 'widgets/sync_overlay.dart';

class FusionSessionScreen extends ConsumerStatefulWidget {
  const FusionSessionScreen({super.key});

  @override
  ConsumerState<FusionSessionScreen> createState() => _FusionSessionScreenState();
}

class _FusionSessionScreenState extends ConsumerState<FusionSessionScreen> {
  // Camera bounds
  CameraController? _cameraController;
  List<CameraDescription> _cameras = [];
  bool _isInit = false;
  XFile? _recordedVideo;

  // Watch bounds
  final List<Map<String, dynamic>> _imuAccumulator = [];

  // System State logic
  bool _isRecording = false;
  bool _showSyncOverlay = true;
  bool _isUploading = false;
  double _uploadProgress = 0.0;
  
  Timer? _sessionTimer;
  int _seconds = 0;
  int _internalStrokesMock = 0;

  @override
  void initState() {
    super.initState();
    _initCamera();
  }

  Future<void> _initCamera() async {
    _cameras = await availableCameras();
    if (_cameras.isNotEmpty) {
      // Bounding resolution specifically limiting physical MP4 bloat structurally executing upload checks natively faster!
      _cameraController = CameraController(_cameras.first, ResolutionPreset.high); // 1280x720 natively
      await _cameraController!.initialize();
      if (!mounted) return;
      setState(() => _isInit = true);
    }
  }

  void _onSyncResolved() async {
    setState(() => _showSyncOverlay = false);
    
    // Auto-Start immediately securely mapping timing blocks explicitly
    await _cameraController!.startVideoRecording();
    _sessionTimer = Timer.periodic(const Duration(seconds: 1), (_) => setState(() => _seconds++));
    setState(() => _isRecording = true);
  }

  Future<void> _stopFusion() async {
    _sessionTimer?.cancel();
    final file = await _cameraController!.stopVideoRecording();
    setState(() {
      _isRecording = false;
      _recordedVideo = file;
    });

    _uploadAndAnalyze();
  }

  Future<void> _uploadAndAnalyze() async {
    setState(() => _isUploading = true);
    final api = ref.read(apiServiceProvider);

    try {
      // 1. Session Instantiation
      final sessionRes = await api.client.post('/sessions/sessions/', data: {
        'date': DateTime.now().toIso8601String(),
        'duration_seconds': _seconds,
        'mode': 'fusion',
        'notes': 'Deep Fusion Processing Matrix'
      });
      final sessionId = sessionRes.data['id'];

      // 2. Transmit accumulated IMU chunks synchronously explicitly checking bounds 
      // (Chunk array slicing bypassing memory overloads securely)
      final batchSize = 1000; 
      for(int i=0; i<_imuAccumulator.length; i+=batchSize) {
        final chunk = _imuAccumulator.sublist(i, i+batchSize > _imuAccumulator.length ? _imuAccumulator.length : i+batchSize);
        await api.client.post('/sessions/process-imu/', data: {
           'session_id': sessionId,
           'imu_windows': [chunk] // Wrapper
        });
      }

      // 3. Post Video Stream File explicitly utilizing MultiPart
      FormData formData = FormData.fromMap({
        'session_id': sessionId,
        'video': await MultipartFile.fromFile(_recordedVideo!.path, filename: 'fusion_capture.mp4')
      });
      
      await api.client.post(
        '/video/upload/',
        data: formData,
        onSendProgress: (sent, total) {
          setState(() => _uploadProgress = sent / total);
        },
      );

      // 4. Force specific Fusion endpoint sequentially tracking manual fallbacks
      // (Even though backend Signals might trigger automatically, triggering securely via HTTP parses visual statuses correctly)
      api.client.post('/fusion/analyze/', data: {'session_id': sessionId});

      // 5. Navigate to polling
      if (mounted) context.go('/video-processing/$sessionId');

    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Upload failed natively: $e')));
        setState(() => _isUploading = false);
      }
    }
  }

  String get _timeString {
    final m = (_seconds / 60).floor().toString().padLeft(2, '0');
    final s = (_seconds % 60).toString().padLeft(2, '0');
    return '$m:$s';
  }

  @override
  void dispose() {
    _cameraController?.dispose();
    _sessionTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!_isInit) return const Scaffold(body: Center(child: CircularProgressIndicator()));

    // Bind real-time Watch telemetry silently adding into global buffer
    ref.listen(imuStreamProvider, (prev, next) {
      if (next.hasValue && _isRecording) {
        final sample = next.value!;
        _imuAccumulator.add({
          'timestampMs': sample.timestampMs,
          'accelX': sample.accelX, 'accelY': sample.accelY, 'accelZ': sample.accelZ,
          'gyroX': sample.gyroX, 'gyroY': sample.gyroY, 'gyroZ': sample.gyroZ,
          'hrBpm': sample.hrBpm
        });
        
        // Mock stroke counts visually tracking 
        if (_imuAccumulator.length % 75 == 0) {
            setState(() => _internalStrokesMock++);
            HapticFeedback.mediumImpact(); // Implicit Haptics natively bouncing triggers structurally
        }
      }
    });

    final hr = ref.watch(imuStreamProvider).value?.hrBpm ?? '--';
    final watchState = ref.watch(watchConnectionProvider).status;

    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          Column(
            children: [
              // Top Half: Camera Context Native Bindings
              Expanded(
                flex: 5,
                child: Container(
                  width: double.infinity,
                  color: const Color(0xFF161B22),
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                       CameraPreview(_cameraController!),
                       if (_isRecording)
                         Positioned(
                           top: 40,
                           child: Container(
                             padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                             decoration: BoxDecoration(color: Colors.redAccent, borderRadius: BorderRadius.circular(16)),
                             child: Text(_timeString, style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.white)),
                           ),
                         )
                    ],
                  ),
                ),
              ),
              
              // Bottom Half: Telemetry Dash
              Expanded(
                flex: 4,
                child: Container(
                  padding: const EdgeInsets.all(24),
                  color: const Color(0xFF0D1117),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text('BLE CONNECTION', style: TextStyle(color: Colors.white54, fontSize: 12)),
                          Text(
                            watchState.name.toUpperCase(), 
                            style: TextStyle(color: watchState.name == 'connected' ? const Color(0xFF00E5A0) : Colors.redAccent, fontWeight: FontWeight.bold)
                          ),
                        ],
                      ),
                      
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceAround,
                        children: [
                          _StatDash(icon: Icons.monitor_heart, title: 'HEART RATE', value: hr.toString(), color: Colors.redAccent),
                          _StatDash(icon: Icons.sports_tennis, title: 'STROKES', value: _internalStrokesMock.toString(), color: const Color(0xFF00E5A0)),
                        ],
                      ),
                      
                      const SizedBox(height: 16),
                      ElevatedButton(
                        onPressed: _showSyncOverlay ? null : _stopFusion,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.redAccent,
                          minimumSize: const Size(double.infinity, 60),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16))
                        ),
                        child: const Text('FINISH & SYNC', style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
                      )
                    ],
                  ),
                ),
              )
            ],
          ),
          
          if (_showSyncOverlay)
            Positioned.fill(
              child: SyncOverlay(onSyncComplete: _onSyncResolved),
            ),
            
          if (_isUploading)
            Positioned.fill(
              child: Container(
                color: Colors.black87,
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const CircularProgressIndicator(color: Color(0xFF00E5A0)),
                    const SizedBox(height: 24),
                    Text('Fusing Match Data... ${(_uploadProgress * 100).toStringAsFixed(0)}%', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold))
                  ],
                ),
              ),
            )
        ],
      ),
    );
  }
}

class _StatDash extends StatelessWidget {
  final IconData icon;
  final String title;
  final String value;
  final Color color;

  const _StatDash({required this.icon, required this.title, required this.value, required this.color});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Icon(icon, color: color, size: 36),
        const SizedBox(height: 8),
        Text(value, style: TextStyle(color: color, fontSize: 32, fontWeight: FontWeight.bold)),
        Text(title, style: const TextStyle(color: Colors.white54, fontSize: 10, letterSpacing: 1)),
      ],
    );
  }
}
