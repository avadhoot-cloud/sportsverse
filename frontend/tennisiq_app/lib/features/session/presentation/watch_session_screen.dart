import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../watch/providers/watch_connection_provider.dart';
import '../../auth/providers/auth_provider.dart';
import 'package:dio/dio.dart';

class WatchSessionScreen extends ConsumerStatefulWidget {
  final String mode; // watch_only or fusion
  const WatchSessionScreen({super.key, required this.mode});

  @override
  ConsumerState<WatchSessionScreen> createState() => _WatchSessionScreenState();
}

class _WatchSessionScreenState extends ConsumerState<WatchSessionScreen> {
  int _strokeCount = 0;
  List<Map<String, dynamic>> _imuBuffer = [];
  String? _sessionId;
  
  // Timer vars
  Timer? _sessionTimer;
  int _elapsedSeconds = 0;
  
  // Recent detections log visually
  List<String> _recentLogs = [];

  @override
  void initState() {
    super.initState();
    _startSession();
  }

  Future<void> _startSession() async {
    // 1. Inform Django a new session started
    final api = ref.read(apiServiceProvider);
    try {
      final res = await api.client.post('/sessions/sessions/', data: {
        'date': DateTime.now().toIso8601String(),
        'duration_seconds': 0,
        'mode': widget.mode,
        'notes': 'Live ML Session'
      });
      _sessionId = res.data['id'].toString();
      
      _sessionTimer = Timer.periodic(const Duration(seconds: 1), (t) {
        setState(() => _elapsedSeconds++);
      });
    } catch (e) {
      _appendLog('Error creating session bound.');
    }
  }

  void _appendLog(String line) {
    setState(() {
      _recentLogs.insert(0, line);
      if (_recentLogs.length > 5) _recentLogs.removeLast();
    });
  }

  Future<void> _flushImuWindow() async {
    if (_sessionId == null) return;
    final windowArr = List.from(_imuBuffer); // copy exactly 50 bounds natively
    _imuBuffer.clear();

    final api = ref.read(apiServiceProvider);
    try {
      final res = await api.client.post('/sessions/process-imu/', data: {
        'session_id': _sessionId,
        'imu_windows': [windowArr] // wrapped as a list of windows for bulk possibility
      });
      
      List strokes = res.data['detected_strokes'] ?? [];
      if (strokes.isNotEmpty) {
        setState(() {
          _strokeCount += strokes.length;
          for (var s in strokes) {
            String log = 'Hit: ${s['stroke_type'].toString().toUpperCase()} (${(s['confidence']*100).toStringAsFixed(0)}%)';
            _appendLog(log);
          }
        });
      }
    } catch (e) {
      // Quiet drop on network fail to preserve live loop natively
    }
  }

  @override
  void dispose() {
    _sessionTimer?.cancel();
    // Update final duration against Django
    if (_sessionId != null) {
      ref.read(apiServiceProvider).client.patch('/sessions/sessions/$_sessionId/', data: {
        'duration_seconds': _elapsedSeconds,
      });
    }
    super.dispose();
  }

  String get _formattedTime {
    final m = (_elapsedSeconds / 60).floor();
    final s = _elapsedSeconds % 60;
    return '${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    // 2. Consume IMU stream actively
    ref.listen(imuStreamProvider, (prev, next) {
      if (next.hasValue) {
        final sample = next.value!;
        _imuBuffer.add({
          'timestampMs': sample.timestampMs,
          'accelX': sample.accelX,
          'accelY': sample.accelY,
          'accelZ': sample.accelZ,
          'gyroX': sample.gyroX,
          'gyroY': sample.gyroY,
          'gyroZ': sample.gyroZ,
          'hrBpm': sample.hrBpm
        });
        
        // 50 samples mapped == approx 1 second bucket (50Hz)
        if (_imuBuffer.length >= 50) {
          _flushImuWindow();
        }
      }
    });

    final watchState = ref.watch(watchConnectionProvider);
    final isConnected = watchState.status == WatchConnectionState.connected;

    return Scaffold(
      appBar: AppBar(
        title: Text('Live Match (${widget.mode})'),
        automaticallyImplyLeading: false,
      ),
      body: SafeArea(
        child: Column(
          children: [
            if (!isConnected)
              Container(
                color: Colors.redAccent,
                width: double.infinity,
                padding: const EdgeInsets.all(8),
                child: const Text('Watch Disconnected! IMU stream paused.', textAlign: TextAlign.center, style: TextStyle(color: Colors.white)),
              ),
              
            // Core Dashboard UI
            Expanded(
              child: Padding(
                padding: const EdgeInsets.all(24.0),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(_formattedTime, style: const TextStyle(fontSize: 48, fontWeight: FontWeight.bold, color: Colors.white)),
                    const SizedBox(height: 8),
                    const Text('DURATION', style: TextStyle(color: Colors.white54, letterSpacing: 2)),
                    
                    const SizedBox(height: 48),
                    
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                      children: [
                        _BigStat(title: 'STROKES', value: _strokeCount.toString(), color: const Color(0xFF00E5A0)),
                        Consumer(
                           builder: (context, ref, child) {
                             final hr = ref.watch(imuStreamProvider).value?.hrBpm ?? 0;
                             return _BigStat(title: 'HEART RATE', value: hr > 0 ? hr.toString() : '--', color: Colors.redAccent);
                           }
                        ),
                      ],
                    ),
                    
                    const SizedBox(height: 48),
                    const Text('LIVE ACTIVITY', style: TextStyle(color: Colors.white54, letterSpacing: 1)),
                    const SizedBox(height: 16),
                    
                    // Logger Visual Output
                    Container(
                      height: 150,
                      decoration: BoxDecoration(
                        color: const Color(0xFF161B22),
                        borderRadius: BorderRadius.circular(16)
                      ),
                      child: ListView.builder(
                        padding: const EdgeInsets.all(16),
                        itemCount: _recentLogs.length,
                        itemBuilder: (c, i) => Padding(
                          padding: const EdgeInsets.only(bottom: 8.0),
                          child: Text('> ${_recentLogs[i]}', style: const TextStyle(fontFamily: 'monospace', color: Color(0xFF00E5A0))),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            
            Padding(
              padding: const EdgeInsets.all(24.0),
              child: ElevatedButton(
                onPressed: () => Navigator.of(context).pop(),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.redAccent,
                  foregroundColor: Colors.white,
                  minimumSize: const Size(double.infinity, 60),
                ),
                child: const Text('END SESSION', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              ),
            )
          ],
        ),
      ),
    );
  }
}

class _BigStat extends StatelessWidget {
  final String title;
  final String value;
  final Color color;

  const _BigStat({required this.title, required this.value, required this.color});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(value, style: TextStyle(fontSize: 42, fontWeight: FontWeight.bold, color: color)),
        const SizedBox(height: 8),
        Text(title, style: const TextStyle(fontSize: 12, color: Colors.white54, letterSpacing: 1)),
      ],
    );
  }
}
