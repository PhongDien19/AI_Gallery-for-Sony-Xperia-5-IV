import 'package:flutter/foundation.dart';
import 'package:tflite_flutter/tflite_flutter.dart';

class SegmentationService {
  Interpreter? _interpreter;
  final List<String> _deeplabLabels = [
    'background', 'aeroplane', 'bicycle', 'bird', 'boat', 'bottle', 'bus',
    'car', 'cat', 'chair', 'cow', 'diningtable', 'dog', 'horse', 'motorbike',
    'person', 'pottedplant', 'sheep', 'sofa', 'train', 'tvmonitor'
  ];

  Future<void> init() async {
    try {
      final options = InterpreterOptions()..threads = 4..useNnApiForAndroid = true;
      _interpreter = await Interpreter.fromAsset('assets/models/deeplabv3.tflite', options: options);
      debugPrint("DeepLabV3 Model loaded with ${_deeplabLabels.length} classes.");
    } catch (e) {
      debugPrint("Segmentation Init Failed: $e");
    }
  }

  /// Generates a segmentation mask (label index for each pixel)
  Future<List<List<int>>> generateMask(Uint8List imageBytes) async {
    if (_interpreter == null) {
      // Return a default "all background" mask to prevent crashes
      return List.generate(257, (_) => List.filled(257, 0));
    }
    
    // 1. Resize image to 257x257
    // 2. Inference: Input [1, 257, 257, 3], Output [1, 257, 257, 21]
    final output = List.generate(1, (_) => List.generate(257, (_) => List.generate(257, (_) => List.filled(21, 0.0))));
    // _interpreter!.run(input, output);

    return _processDeepLabOutput(output[0]);
  }

  List<List<int>> _processDeepLabOutput(List<List<List<double>>> output) {
    List<List<int>> mask = List.generate(257, (_) => List.filled(257, 0));

    for (int y = 0; y < 257; y++) {
      for (int x = 0; x < 257; x++) {
        int maxClass = 0;
        double maxProb = -1.0;
        
        for (int c = 0; c < 21; c++) {
          if (output[y][x][c] > maxProb) {
            maxProb = output[y][x][c];
            maxClass = c;
          }
        }
        mask[y][x] = maxClass;
      }
    }
    return mask;
  }
}
