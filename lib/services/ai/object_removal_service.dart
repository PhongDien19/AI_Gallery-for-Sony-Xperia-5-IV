import 'package:image/image.dart' as img;
import 'package:flutter/foundation.dart';
import 'package:tflite_flutter/tflite_flutter.dart';
import 'object_detection_service.dart';
import 'dart:ui' show Rect;

class ObjectRemovalService {
  Interpreter? _inpaintingInterpreter;

  Future<void> init() async {
    try {
      // Hardware Optimization for Xperia 5 IV (Snapdragon 8 Gen 1)
      final options = InterpreterOptions()
        ..threads = 4
        ..useNnApiForAndroid = true; // Leveraging soc-sm8450 NPU
      
      // Note: In production, load the quantized LaMa/ZITS TFLite model here
      // _inpaintingInterpreter = await Interpreter.fromAsset('assets/models/inpainting.tflite', options: options);
    } catch (e) {
      debugPrint("Inpainting Init Failed: $e");
    }
  }

  /// Flagship Local Inpainting Workflow (Dilation + Crop-Process-Paste)
  Future<Uint8List> eraseDistractions({
    required Uint8List imageBytes,
    required List<ObjectDetectionResult> distractions,
    double dilationPercent = 0.15, // 15% padding for edge coverage
  }) async {
    img.Image? originalImage = img.decodeImage(imageBytes);
    if (originalImage == null) return imageBytes;

    for (var object in distractions) {
      // 1. Dilation Process: Expand the bounding box to capture edge pixels
      final dilatedRect = _calculateExpandedRect(
        object.boundingBox, 
        originalImage.width.toDouble(), 
        originalImage.height.toDouble(), 
        dilationPercent
      );

      // 2. Local Inpainting: Extract region
      int x = dilatedRect.left.toInt();
      int y = dilatedRect.top.toInt();
      int w = dilatedRect.width.toInt();
      int h = dilatedRect.height.toInt();

      // 3. Process Local Region (Crop -> Inpaint -> Paste)
      img.Image region = img.copyCrop(originalImage, x: x, y: y, width: w, height: h);
      
      // Simulate high-quality inpainting with selective blurring/patching
      img.gaussianBlur(region, radius: 10);
      
      // Composite back to original to preserve detail everywhere else
      img.compositeImage(originalImage, region, dstX: x, dstY: y);
    }

    return Uint8List.fromList(img.encodeJpg(originalImage, quality: 95));
  }

  Rect _calculateExpandedRect(Rect box, double imgW, double imgH, double padding) {
    double pW = box.width * padding;
    double pH = box.height * padding;
    
    return Rect.fromLTRB(
      (box.left - pW).clamp(0, imgW),
      (box.top - pH).clamp(0, imgH),
      (box.right + pW).clamp(0, imgW),
      (box.bottom + pH).clamp(0, imgH)
    );
  }
}
