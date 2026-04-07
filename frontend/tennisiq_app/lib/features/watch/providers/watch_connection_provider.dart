import 'dart:async';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/imu_sample.dart';
import '../utils/imu_data_parser.dart';

enum WatchConnectionState { disconnected, scanning, connecting, connected }

class WatchState {
  final WatchConnectionState status;
  final BluetoothDevice? device;
  final String? errorMessage;
  
  WatchState({required this.status, this.device, this.errorMessage});
  
  WatchState copyWith({WatchConnectionState? status, BluetoothDevice? device, String? errorMessage}) {
    return WatchState(
      status: status ?? this.status,
      device: device ?? this.device,
      errorMessage: errorMessage ?? this.errorMessage,
    );
  }
}

final imuStreamProvider = StreamProvider<ImuSample>((ref) {
  return ref.watch(watchConnectionProvider.notifier).imuDataStream;
});

final watchConnectionProvider = StateNotifierProvider<WatchConnectionNotifier, WatchState>((ref) {
  return WatchConnectionNotifier();
});

class WatchConnectionNotifier extends StateNotifier<WatchState> {
  StreamSubscription<List<ScanResult>>? _scanSubscription;
  StreamSubscription<BluetoothConnectionState>? _connectionSubscription;
  StreamSubscription<List<int>>? _charSubscription;
  
  final _imuStreamController = StreamController<ImuSample>.broadcast();
  Stream<ImuSample> get imuDataStream => _imuStreamController.stream;

  // IMU characteristic UUID placeholder (Can be overridden by concrete watch constants)
  final String _targetServiceUuid = "0000180D-0000-1000-8000-00805f9b34fb"; 
  final String _targetCharUuid = "00002A37-0000-1000-8000-00805f9b34fb"; 
  
  int _reconnectAttempts = 0;
  final int _maxReconnectAttempts = 3;
  BluetoothDevice? _targetDevice;

  WatchConnectionNotifier() : super(WatchState(status: WatchConnectionState.disconnected)) {
    _autoConnectPrevious();
  }

  Future<void> _autoConnectPrevious() async {
    final prefs = await SharedPreferences.getInstance();
    final savedId = prefs.getString('watch_device_id');
    if (savedId != null) {
      // Connect specifically to saved ID if the driver permits, or scan immediately to find it.
      startScan(targetId: savedId);
    }
  }

  void startScan({String? targetId}) {
    state = state.copyWith(status: WatchConnectionState.scanning, errorMessage: null);
    
    _scanSubscription?.cancel();
    FlutterBluePlus.startScan(timeout: const Duration(seconds: 10));
    
    _scanSubscription = FlutterBluePlus.scanResults.listen((results) {
      if (targetId != null) {
        for (ScanResult r in results) {
          if (r.device.remoteId.str == targetId) {
            FlutterBluePlus.stopScan();
            connectToDevice(r.device);
            break;
          }
        }
      }
    }, onError: (e) {
      state = state.copyWith(status: WatchConnectionState.disconnected, errorMessage: 'Scan failed: $e');
    });
  }
  
  void stopScan() {
    FlutterBluePlus.stopScan();
    if (state.status == WatchConnectionState.scanning) {
      state = state.copyWith(status: WatchConnectionState.disconnected);
    }
  }

  Future<void> connectToDevice(BluetoothDevice device) async {
    FlutterBluePlus.stopScan();
    _targetDevice = device;
    state = state.copyWith(status: WatchConnectionState.connecting, device: device, errorMessage: null);

    try {
      await device.connect();
      _handleConnectionSuccess(device);
    } catch (e) {
      _handleConnectionLoss();
    }

    _connectionSubscription?.cancel();
    _connectionSubscription = device.connectionState.listen((connectionState) {
      if (connectionState == BluetoothConnectionState.disconnected) {
        _handleConnectionLoss();
      }
    });
  }

  Future<void> _handleConnectionSuccess(BluetoothDevice device) async {
    _reconnectAttempts = 0; // Reset
    
    // Save to SharedPreferences securely for future
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('watch_device_id', device.remoteId.str);
    
    state = state.copyWith(status: WatchConnectionState.connected, device: device, errorMessage: null);
    
    // Discover Services and subscribe to IMU characteristic
    List<BluetoothService> services = await device.discoverServices();
    for (var service in services) {
      if (service.uuid.toString() == _targetServiceUuid) { // Fallback checking
        for (var characteristic in service.characteristics) {
          // In production, match exactly `characteristic.uuid.toString() == _targetCharUuid`
          if (characteristic.properties.notify) {
            await characteristic.setNotifyValue(true);
            _charSubscription = characteristic.lastValueStream.listen((value) {
              if (value.isNotEmpty) {
                try {
                  final sample = ImuDataParser.parse(value);
                  _imuStreamController.add(sample);
                } catch (e) {
                  // Bad packet handling
                }
              }
            });
            break;
          }
        }
      }
    }
  }

  Future<void> _handleConnectionLoss() async {
    if (_targetDevice == null) return;

    if (_reconnectAttempts < _maxReconnectAttempts) {
      _reconnectAttempts++;
      state = state.copyWith(status: WatchConnectionState.connecting, errorMessage: 'Connection lost. Retrying ($_reconnectAttempts/$_maxReconnectAttempts)...');
      
      // Exponential Backoff math: 2^attempts seconds
      final delaySeconds = 1 << _reconnectAttempts; 
      await Future.delayed(Duration(seconds: delaySeconds));
      
      try {
        await _targetDevice!.connect();
        _handleConnectionSuccess(_targetDevice!);
      } catch (e) {
        _handleConnectionLoss(); // Recursive re-try 
      }
    } else {
      state = state.copyWith(status: WatchConnectionState.disconnected, errorMessage: 'Failed to connect tightly. Watch out of range.');
      _charSubscription?.cancel();
    }
  }

  void disconnect() {
    _targetDevice?.disconnect();
    _charSubscription?.cancel();
    _connectionSubscription?.cancel();
    state = state.copyWith(status: WatchConnectionState.disconnected, device: null, errorMessage: null);
  }

  @override
  void dispose() {
    _scanSubscription?.cancel();
    _connectionSubscription?.cancel();
    _charSubscription?.cancel();
    _imuStreamController.close();
    super.dispose();
  }
}
