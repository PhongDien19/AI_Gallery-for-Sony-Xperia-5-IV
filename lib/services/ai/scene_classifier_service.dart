import 'package:flutter/foundation.dart';
import 'package:tflite_flutter/tflite_flutter.dart';

class SceneClassifierService {
  Interpreter? _interpreter;
  final List<String> _sceneLabels = [
    'portrait', 'beach', 'mountain', 'food', 'pet', 'city_night',
    'architecture', 'indoor', 'outdoor', 'product', 'sky', 'sunset'
  ];

  Future<void> init() async {
    try {
      final options = InterpreterOptions()..threads = 4..useNnApiForAndroid = true;
      _interpreter = await Interpreter.fromAsset('assets/models/mobile_net_v3.tflite', options: options);
    } catch (e) {
      debugPrint("Scene Classifier Init Failed: $e");
    }
  }

  Future<String> classifyScene(Uint8List imageBytes) async {
    if (_interpreter == null) return "unknown";

    // 1. Resize image to 224x224
    // 2. Inference: Input [1, 224, 224, 3], Output [1, 1000] or [1, num_scenes]
    final output = List.generate(1, (_) => List.filled(_sceneLabels.length, 0.0));
    // _interpreter!.run(input, output);

    return _processClassifierOutput(output[0]);
  }

  String _processClassifierOutput(List<double> probabilities) {
    int maxIdx = 0;
    double maxProb = -1.0;

    for (int i = 0; i < probabilities.length; i++) {
      if (probabilities[i] > maxProb) {
        maxProb = probabilities[i];
        maxIdx = i;
      }
    }
    return _sceneLabels[maxIdx];
  }
}
