import 'dart:math' as math;
import 'package:flutter/foundation.dart';
import 'package:tflite_flutter/tflite_flutter.dart';
import 'package:image/image.dart' as img;

enum EditingMode {
  mirNet, // Low-light enhancement
  esrGan, // Upscaling/Sharpening
  denoising, // Noise reduction
  awb, // Auto White Balance
  sunrise, // Sunrise/Warm style
  cinematic, // Cinematic/Teal & Orange
  sCinetone, // Sony's professional profile
}

class ImageEditingService {
  Interpreter? _mirNetInterpreter;
  Interpreter? _esrGanInterpreter;

  Future<void> init() async {
    try {
      final options = InterpreterOptions()
        ..threads = 4
        ..useNnApiForAndroid = true;

      // Load MIRNet for Low-light
      try {
        _mirNetInterpreter = await Interpreter.fromAsset(
          'assets/models/mirnet.tflite',
          options: options,
        );
      } catch (e) {
        debugPrint("MIRNet model not found: $e");
      }

      // Load ESRGAN for Upscaling
      try {
        _esrGanInterpreter = await Interpreter.fromAsset(
          'assets/models/esrgan.tflite',
          options: options,
        );
      } catch (e) {
        debugPrint("ESRGAN model not found: $e");
      }
    } catch (e) {
      debugPrint("Failed to initialize editing models. Please ensure mirnet.tflite and esrgan.tflite are in assets/models/: $e");
    }
  }

  Future<Uint8List> processImage(Uint8List imageBytes, EditingMode mode) async {
    Interpreter? interpreter;
    switch (mode) {
      case EditingMode.mirNet:
        interpreter = _mirNetInterpreter;
        break;
      case EditingMode.esrGan:
        interpreter = _esrGanInterpreter;
        break;
      case EditingMode.denoising:
        interpreter = _mirNetInterpreter; // Placeholder: MIRNet also does denoising
        break;
      case EditingMode.awb:
        interpreter = _mirNetInterpreter; // Placeholder
        break;
      case EditingMode.sunrise:
      case EditingMode.cinematic:
      case EditingMode.sCinetone:
        // These modes are currently handled by the Fallback Engine in processImage's next step
        interpreter = null; 
        break;
    }

    if (interpreter == null) {
      debugPrint("Interpreter for $mode not initialized. Using High-Quality Fallback Engine (Isolate).");
      return compute(_runFallbackEngineIsolate, _FallbackParams(imageBytes, mode));
    }

    // 1. Decode and Resize
    final image = img.decodeImage(imageBytes);
    if (image == null) return imageBytes;

    // MIRNet usually expects 400x400 or similar, ESRGAN might expect smaller blocks
    // This is a generic implementation, actual input size depends on the model
    const int inputSize = 400; 
    final resized = img.copyResize(image, width: inputSize, height: inputSize);

    // 2. Pre-process: [1, inputSize, inputSize, 3] float32
    final input = _imageToByteListFloat32(resized, inputSize);

    // 3. Inference
    // Output shape depends on the model. For Image-to-Image, it's often the same or larger (upscaled)
    // For ESRGAN 4x, it would be [1, inputSize*4, inputSize*4, 3]
    final outputSize = (mode == EditingMode.esrGan) ? inputSize * 4 : inputSize;
    final output = List.generate(
      1,
      (_) => List.generate(
        outputSize,
        (_) => List.generate(
          outputSize,
          (_) => List.filled(3, 0.0),
        ),
      ),
    );

    interpreter.run(input, output);

    // 4. Post-process: Tensor to Image
    final processedImage = _tensorToImage(output[0], outputSize, outputSize);
    
    return Uint8List.fromList(img.encodeJpg(processedImage, quality: 95));
  }

  Uint8List _imageToByteListFloat32(img.Image image, int size) {
    var convertedBytes = Float32List(1 * size * size * 3);
    var buffer = Float32List.view(convertedBytes.buffer);
    int pixelIndex = 0;
    for (int y = 0; y < size; y++) {
      for (int x = 0; x < size; x++) {
        var pixel = image.getPixel(x, y);
        buffer[pixelIndex++] = pixel.r / 255.0;
        buffer[pixelIndex++] = pixel.g / 255.0;
        buffer[pixelIndex++] = pixel.b / 255.0;
      }
    }
    return convertedBytes.buffer.asUint8List();
  }

  img.Image _tensorToImage(List<List<List<double>>> tensor, int width, int height) {
    final image = img.Image(width: width, height: height);
    for (int y = 0; y < height; y++) {
      for (int x = 0; x < width; x++) {
        final r = (tensor[y][x][0] * 255).clamp(0, 255).toInt();
        final g = (tensor[y][x][1] * 255).clamp(0, 255).toInt();
        final b = (tensor[y][x][2] * 255).clamp(0, 255).toInt();
        image.setPixelRgb(x, y, r, g, b);
      }
    }
    return image;
  }

  // Static isolate runner
  static Future<Uint8List> _runFallbackEngineIsolate(_FallbackParams params) async {
    try {
      // 1. Decode with a memory-safe approach if possible
      img.Image? image = img.decodeImage(params.bytes);
      if (image == null) return params.bytes;

      // 2. Immediate Resize for Preview (Crucial for mobile RAM)
      // Most Xperia photos are 12MP+. Processing full-res in pure Dart is too heavy.
      const int maxPreviewSize = 1600;
      if (image.width > maxPreviewSize || image.height > maxPreviewSize) {
        image = img.copyResize(
          image, 
          width: image.width > image.height ? maxPreviewSize : null,
          height: image.height >= image.width ? maxPreviewSize : null,
          interpolation: img.Interpolation.linear,
        );
      }

      // 3. Bake Orientation
      image = img.bakeOrientation(image);
      
      // 4. Process
      switch (params.mode) {
        case EditingMode.mirNet:
          img.adjustColor(image, exposure: 1.3, contrast: 1.1, brightness: 1.1);
          break;
        case EditingMode.esrGan:
          img.adjustColor(image, contrast: 1.1, saturation: 1.1);
          break;
        case EditingMode.denoising:
          img.gaussianBlur(image, radius: 2);
          break;
        case EditingMode.awb:
          img.adjustColor(image, exposure: 1.05);
          break;

        case EditingMode.sunrise:
          // Warm/Sunrise Style: Boost Orange/Red and Exposure
          img.adjustColor(image, exposure: 1.1, saturation: 1.2, contrast: 1.1);
          // We could also use img.colorOffset if needed for specific hues
          break;

        case EditingMode.cinematic:
          // Teal & Orange style: High contrast, cool shadows
          img.adjustColor(image, contrast: 1.25, saturation: 1.15, brightness: 0.95);
          break;

        case EditingMode.sCinetone:
          // Soft skin tones, high dynamic range look
          img.adjustColor(image, contrast: 1.1, exposure: 1.15, saturation: 0.9);
          break;
      }

      // 5. Encode with slightly lower quality for speed/memory
      return Uint8List.fromList(img.encodeJpg(image, quality: 85));
    } catch (e) {
      debugPrint("Isolate Processing Error: $e");
      return params.bytes;
    }
  }

  Future<Uint8List> eraseObjects(Uint8List imageBytes, List<dynamic> objects) async {
    // Run in isolate to prevent UI lag
    return compute(_runEraserIsolate, _EraserParams(imageBytes, objects));
  }

  static Future<Uint8List> _runEraserIsolate(_EraserParams params) async {
    final image = img.decodeImage(params.bytes);
    if (image == null) return params.bytes;

    img.Image baked = img.bakeOrientation(image);
    
    // Process each object area
    for (var obj in params.objects) {
      // In a real app, obj is a DetectedObject from ML Kit
      // It has a boundingBox
      final rect = obj.boundingBox;
      
      // Calculate coordinates (normalized or pixel-based)
      // ML Kit provides pixel coordinates if the image was input as such
      int startX = rect.left.toInt().clamp(0, baked.width);
      int startY = rect.top.toInt().clamp(0, baked.height);
      int objWidth = rect.width.toInt().clamp(0, baked.width - startX);
      int objHeight = rect.height.toInt().clamp(0, baked.height - startY);
      int endX = startX + objWidth;
      int endY = startY + objHeight;

      // 2. Content-Aware Fill Logic (Smart Patch 2.0)
      // We sample from a wider boundary to avoid smearing the same pixels
      final int boundaryWidth = (objWidth * 0.4).toInt().clamp(20, 100);
      final int boundaryHeight = (objHeight * 0.4).toInt().clamp(20, 100);
      
      // Sample pixels from the surrounding boundary
      final List<img.Color> sourcePixels = [];
      
      for (int x = startX - boundaryWidth; x < endX + boundaryWidth; x++) {
        if (x < 0 || x >= baked.width) continue;
        sourcePixels.add(baked.getPixel(x, (startY - 5).clamp(0, baked.height - 1)).clone());
        sourcePixels.add(baked.getPixel(x, (endY + 5).clamp(0, baked.height - 1)).clone());
      }
      
      for (int y = startY - boundaryHeight; y < endY + boundaryHeight; y++) {
        if (y < 0 || y >= baked.height) continue;
        sourcePixels.add(baked.getPixel((startX - 5).clamp(0, baked.width - 1), y).clone());
        sourcePixels.add(baked.getPixel((endX + 5).clamp(0, baked.width - 1), y).clone());
      }
      
      if (sourcePixels.isEmpty) continue;

      // Fill the object area with a random texture sample from boundary
      final random = math.Random();
      for (int y = startY; y < endY; y++) {
        for (int x = startX; x < endX; x++) {
          if (x < 0 || x >= baked.width || y < 0 || y >= baked.height) continue;
          // Random sampling creates natural texture
          baked.setPixel(x, y, sourcePixels[random.nextInt(sourcePixels.length)]);
        }
      }
      
      // Edge blending blur
      for (int y = startY - 2; y < endY + 2; y++) {
        for (int x = startX - 2; x < endX + 2; x++) {
          if (x <= 1 || x >= baked.width - 2 || y <= 1 || y >= baked.height - 2) continue;
          if (x < startX + 3 || x > endX - 3 || y < startY + 3 || y > endY - 3) {
             baked.setPixel(x, y, _getAveragePixel(baked, x, y));
          }
        }
      }
      img.gaussianBlur(baked, radius: 2);
    }

    return Uint8List.fromList(img.encodeJpg(baked, quality: 90));
  }

  static img.Color _getAveragePixel(img.Image image, int x, int y) {
    double r = 0, g = 0, b = 0;
    int count = 0;
    for (int i = -1; i <= 1; i++) {
      for (int j = -1; j <= 1; j++) {
        final p = image.getPixel(x + i, y + j);
        r += p.r;
        g += p.g;
        b += p.b;
        count++;
      }
    }
    return img.ColorRgb8((r / count).toInt(), (g / count).toInt(), (b / count).toInt());
  }

  void dispose() {
    _mirNetInterpreter?.close();
    _esrGanInterpreter?.close();
  }
}

class _FallbackParams {
  final Uint8List bytes;
  final EditingMode mode;
  _FallbackParams(this.bytes, this.mode);
}

class _EraserParams {
  final Uint8List bytes;
  final List<dynamic> objects;
  _EraserParams(this.bytes, this.objects);
}
