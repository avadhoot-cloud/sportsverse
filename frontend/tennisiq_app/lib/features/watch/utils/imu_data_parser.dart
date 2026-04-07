import 'dart:typed_data';
import '../models/imu_sample.dart';

class ImuDataParser {
  /// Parses BLE byte data into an ImuSample mapping the explicit 34-byte contract.
  /// Note: The prompt cited a '20-byte BLE characteristic' but explicitly requested:
  /// timestamp (8), accel (3x4=12), gyro (3x4=12), hr (2) = 34 Bytes total.
  /// If the hardware is actually squeezing this into 20 bytes, it implies compression 
  /// (e.g. Int16s). Assuming standard explicit Little Endian floats per prompt.
  static ImuSample parse(List<int> bytes) {
    if (bytes.length < 34) {
      throw Exception('Invalid IMU packet length. Expected 34, got ${bytes.length}');
    }

    final byteData = ByteData.sublistView(Uint8List.fromList(bytes));
    
    // Little Endian offsets
    final timestampMs = byteData.getInt64(0, Endian.little);
    
    final accelX = byteData.getFloat32(8, Endian.little);
    final accelY = byteData.getFloat32(12, Endian.little);
    final accelZ = byteData.getFloat32(16, Endian.little);
    
    final gyroX = byteData.getFloat32(20, Endian.little);
    final gyroY = byteData.getFloat32(24, Endian.little);
    final gyroZ = byteData.getFloat32(28, Endian.little);
    
    final hrBpm = byteData.getInt16(32, Endian.little);

    return ImuSample(
      timestampMs: timestampMs,
      accelX: accelX,
      accelY: accelY,
      accelZ: accelZ,
      gyroX: gyroX,
      gyroY: gyroY,
      gyroZ: gyroZ,
      hrBpm: hrBpm,
    );
  }
}
