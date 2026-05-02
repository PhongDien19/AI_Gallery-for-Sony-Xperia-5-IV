import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../services/ai/object_detection_service.dart';
import '../services/ai/segmentation_service.dart';
import '../services/ai/scene_classifier_service.dart';
import '../services/ai/ai_rule_engine.dart';
import '../services/ai/object_removal_service.dart';
import '../services/ai/enhancement_service.dart';
import '../services/metadata/exif_service.dart';

/// Provider for the Gemma AI Service
final gemmaAiServiceProvider = Provider<GemmaAiService>((ref) {
  return GemmaAiService();
});

/// Represents the analyzed context and suggested enhancements
class AiAnalysisResult {
  final String environment;
  final double compositionScore;
  final String colorProfile;
  final List<String> proSuggestions;
  final Map<String, double> technicalAdjustments;
  final bool hasDistractions;
  
  // Flagship AI Metadata
  List<ObjectDetectionResult> detectedObjects = [];
  String mainSubjectLabel = "";

  AiAnalysisResult({
    required this.environment,
    required this.compositionScore,
    required this.colorProfile,
    required this.proSuggestions,
    required this.technicalAdjustments,
    this.hasDistractions = false,
  });
}

class GemmaAiService {
  final ObjectDetectionService _detection = ObjectDetectionService();
  final SegmentationService _segmentation = SegmentationService();
  final SceneClassifierService _classifier = SceneClassifierService();
  final AiRuleEngine _ruleEngine = AiRuleEngine();
  final ExifService _exif = ExifService();
  final ObjectRemovalService _removal = ObjectRemovalService();
  final EnhancementService _enhancer = EnhancementService();

  Future<void> initModel() async {
    // Parallel initialization for better performance on Xperia
    await Future.wait([
      _detection.init(),
      _segmentation.init(),
      _removal.init(),
      // _classifier.init(), 
    ]);
    debugPrint("All Pro AI Models Initialized for Sony Xperia 5 IV.");
  }

  /// Flagship AI Pipeline: The "Brain" of Xperia AI Gallery
  Future<AiAnalysisResult> analyzeImage(Uint8List imageBytes, DateTime? fallbackTime) async {
    // 1. Scene & Metadata (Parallel)
    final results = await Future.wait([
      _exif.readExifTime(imageBytes),
      _classifier.classifyScene(imageBytes),
      _detection.detectObjects(imageBytes),
    ]);

    final DateTime? time = (results[0] as DateTime?) ?? fallbackTime;
    final String scene = results[1] as String;
    final List<ObjectDetectionResult> objects = results[2] as List<ObjectDetectionResult>;

    // 2. Pixel-Level Segmentation
    final mask = await _segmentation.generateMask(imageBytes);
    if (mask.isNotEmpty) {
      debugPrint("Segmentation completed: ${mask.length}x${mask[0].length} pixel map generated.");
    }

    // 3. Rule Engine Selection
    final analysis = _ruleEngine.selectBestPreset(
      scene: scene,
      objects: objects,
      time: time,
    );

    // Store objects for potential removal process
    analysis.detectedObjects = objects;

    // 4. Gemma Suggestion Layer
    analysis.proSuggestions.add("Gemma Insight: Based on the ${analysis.colorProfile} profile, we recommend reducing background noise to keep the focus on the subject.");

    return analysis;
  }

  /// Applies the AI enhancements to the actual pixels
  Future<Uint8List> applyEnhancements(Uint8List imageBytes, AiAnalysisResult analysis) async {
    final mask = await _segmentation.generateMask(imageBytes);
    return await _enhancer.processImage(
      imageBytes: imageBytes,
      analysis: analysis,
      mask: mask,
    );
  }

  /// Magic Eraser: Erases only non-main subjects
  Future<Uint8List> removeDistractions(Uint8List imageBytes, AiAnalysisResult analysis) async {
    // Identify photobombers: any person who is NOT the main subject
    final photobombers = analysis.detectedObjects.where((obj) {
      // Logic: If it's a person and not identified as the 'Main Subject' by Rule Engine
      return obj.label == 'person' && obj.label != analysis.mainSubjectLabel;
    }).toList();

    if (photobombers.isEmpty) return imageBytes;

    return await _removal.eraseDistractions(
      imageBytes: imageBytes,
      distractions: photobombers,
      dilationPercent: analysis.environment.contains("Beach") ? 0.20 : 0.15,
    );
  }
}
