import 'package:image/image.dart' as img;
import 'package:tflite_flutter/tflite_flutter.dart';
import 'package:flutter/foundation.dart';

class VisionAiService {
  Interpreter? _interpreter;

  Future<void> initModel() async {
    try {
      final options = InterpreterOptions()
        ..threads = 4
        ..useNnApiForAndroid = true; // Optimized for Xperia's Snapdragon DSP

      // Using MobileNetV3 as it's highly efficient for Xperia 5 IV
      _interpreter = await Interpreter.fromAsset(
        'assets/models/mobile_net_v3.tflite',
        options: options,
      );
      debugPrint("Vision AI Model initialized successfully.");
    } catch (e) {
      debugPrint("Failed to load Vision AI model: $e");
    }
  }

  /// Pre-processes the image to [1, 224, 224, 3] float tensor
  List<List<List<List<double>>>> preprocessImage(Uint8List imageBytes) {
    final image = img.decodeImage(imageBytes);
    if (image == null) return [];

    final resized = img.copyResize(image, width: 224, height: 224);

    // Normalize to 0.0 - 1.0 range
    return [
      List.generate(
        224,
        (y) => List.generate(
          224,
          (x) {
            final pixel = resized.getPixel(x, y);
            return [
              pixel.r / 255.0,
              pixel.g / 255.0,
              pixel.b / 255.0,
            ];
          },
        ),
      )
    ];
  }

  Future<String> runInference(Uint8List imageBytes) async {
    if (_interpreter == null) await initModel();
    if (_interpreter == null) return "Unknown";

    final input = preprocessImage(imageBytes);
    if (input.isEmpty) return "Unknown";

    // Assuming a classification model with 5 output classes
    final output = List.generate(1, (_) => List.filled(5, 0.0));

    _interpreter!.run(input, output);

    final scores = output[0];
    
    // Simple classification logic
    if (scores[0] > 0.6) return "Beach";
    if (scores[1] > 0.6) return "Mountain";
    if (scores[2] > 0.6) return "Portrait";
    if (scores[3] > 0.6) return "Urban / City";
    if (scores[4] > 0.6) return "Food";

    return "Nature";
  }
}
