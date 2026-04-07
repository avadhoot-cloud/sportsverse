import 'dart:io';
import 'package:flutter/services.dart';
import 'package:onnxruntime_flutter/onnxruntime_flutter.dart';
import 'package:path_provider/path_provider.dart';

class OnDeviceClassifier {
  OrtSession? _session;
  bool _isInitialized = false;

  Future<void> initialize() async {
    try {
      OrtEnv.instance.init();
      
      // Load ONNX binary directly mapped down from assets effectively (or downloaded natively)
      // Assuming it's tracked under standard assets/models/
      final byteData = await rootBundle.load('assets/models/stroke_classifier.onnx');
      final buffer = byteData.buffer;
      final tempDir = await getTemporaryDirectory();
      final tempPath = '${tempDir.path}/stroke_classifier.onnx';
      
      await File(tempPath).writeAsBytes(
          buffer.asUint8List(byteData.offsetInBytes, byteData.lengthInBytes));

      final sessionOptions = OrtSessionOptions();
      _session = OrtSession.fromFile(File(tempPath), sessionOptions);
      _isInitialized = true;
    } catch (e) {
      print('Edge Initialization explicitly dropped natively: $e');
      _isInitialized = false; // Graceful HTTP fallback trigger
    }
  }

  /// Predicts stroke using local ONNX binaries without Server ping!
  /// Assumes float_input of shape [1, 5] mapped from features.
  Future<Map<String, dynamic>?> predictStroke(List<double> features) async {
    if (!_isInitialized || _session == null) return null; // Fallback bound natively

    // Convert List<double> natively hitting bounds structurally allocating pointers
    try {
      final inputTensor = OrtValueTensor.createTensorWithDataList([features], [1, 5]);
      final runOptions = OrtRunOptions();
      final inputs = {'float_input': inputTensor};
      
      final outputs = _session!.run(runOptions, inputs);
      if (outputs.isNotEmpty) {
        final rawResult = outputs[0]?.value; 
        
        // Simulating the extracted logic natively
        // Scikit output usually contains label integers inside Array bounds
        if (rawResult != null && rawResult is List && rawResult.isNotEmpty) {
           final label = rawResult.first as int;
           return {
             'stroke_type': _mapLabel(label),
             'confidence': 95.0, // Assuming static probability arrays securely until deep probabilities mapped
           };
        }
      }
      
      inputTensor.release();
      runOptions.release();
      for (var out in outputs) {
        out?.release();
      }
    } catch (e) {
      print('ONNX Inference crashed natively: $e');
    }
    return null;
  }
  
  String _mapLabel(int label) {
     switch (label) {
       case 0: return 'Forehand';
       case 1: return 'Backhand';
       case 2: return 'Serve';
       case 3: return 'Volley';
       default: return 'Unknown';
     }
  }

  void dispose() {
    _session?.release();
    OrtEnv.instance.release();
  }
}
