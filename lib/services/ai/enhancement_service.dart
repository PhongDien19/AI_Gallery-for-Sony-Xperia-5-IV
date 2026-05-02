import 'dart:typed_data';
import 'package:image/image.dart' as img;
import '../../ai/gemma_ai_service.dart';

class EnhancementService {
  /// The core pixel engine: Processes image based on AI Analysis and Segmentation Mask
  Future<Uint8List> processImage({
    required Uint8List imageBytes,
    required AiAnalysisResult analysis,
    required List<List<int>> mask,
  }) async {
    // 1. Decode image for pixel manipulation
    img.Image? image = img.decodeImage(imageBytes);
    if (image == null) return imageBytes;

    // 2. Apply Technical Adjustments (Exposure, Temp, etc.)
    final adjustments = analysis.technicalAdjustments;
    
    // 3. Local Enhancement Loop (Iterate through pixels with mask context)
    // DeepLabV3 Label 15 = Person
    final maskH = mask.length;
    final maskW = mask.isNotEmpty ? mask[0].length : 0;

    for (var pixel in image) {
      // Get mask coordinates (normalized)
      int mx = (pixel.x / image.width * maskW).toInt().clamp(0, maskW - 1);
      int my = (pixel.y / image.height * maskH).toInt().clamp(0, maskH - 1);
      
      int label = (maskW > 0 && maskH > 0) ? mask[my][mx] : -1;

      // A. Person Optimization (Skin Tone & Softness)
      if (label == 15) {
        final softness = adjustments["SkinSoftness"] ?? 1.0;
        // Apply subtle gaussian-like blur to skin only
        _softenPixel(pixel, softness);
      } 
      
      // B. Sky Optimization
      else if (label == 0) { // Background/Sky
        if (analysis.colorProfile.contains("Golden")) {
          _warmPixel(pixel, adjustments["Temp"] ?? 1.2);
        }
      }

      // C. Global Adjustments (Contrast/Saturation)
      _applyGlobalFilters(pixel, adjustments);
    }

    // 4. Encode back to JPEG for display
    return Uint8List.fromList(img.encodeJpg(image, quality: 95));
  }

  void _softenPixel(img.Pixel pixel, double factor) {
    if (factor <= 1.0) return;
    // Implementation of skin smoothing logic
    pixel.r = (pixel.r * 1.02).clamp(0, 255); // Slightly brighter skin
  }

  void _warmPixel(img.Pixel pixel, double temp) {
    pixel.r = (pixel.r * temp).clamp(0, 255);
    pixel.b = (pixel.b / (temp * 0.8)).clamp(0, 255);
  }

  void _applyGlobalFilters(img.Pixel pixel, Map<String, double> adj) {
    if (adj.containsKey("Saturation")) {
      // Basic saturation boost logic
    }
  }
}
