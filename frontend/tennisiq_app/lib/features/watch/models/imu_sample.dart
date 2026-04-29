import 'dart:math';

class ImuSample {
  final int timestampMs;
  final double accelX;
  final double accelY;
  final double accelZ;
  final double gyroX;
  final double gyroY;
  final double gyroZ;
  final int hrBpm;

  ImuSample({
    required this.timestampMs,
    required this.accelX,
    required this.accelY,
    required this.accelZ,
    required this.gyroX,
    required this.gyroY,
    required this.gyroZ,
    required this.hrBpm,
  });

  double get accelerationMagnitude {
    return sqrt((accelX * accelX) + (accelY * accelY) + (accelZ * accelZ));
  }

  @override
  String toString() {
    return 'IMU[t=$timestampMs, HR=$hrBpm, ax=${accelX.toStringAsFixed(2)}]';
  }
}
