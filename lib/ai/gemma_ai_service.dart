import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../services/ai/recognition_service.dart';
import '../services/ai/image_editing_service.dart';
import '../services/metadata/exif_service.dart';
import '../services/ai/ai_rule_engine.dart';

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
  List<dynamic> detectedObjects = []; // Using dynamic to avoid direct ML Kit dependency in Result class if needed, or just import it
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
  final RecognitionService _recognition = RecognitionService();
  final ImageEditingService _editing = ImageEditingService();
  final AiRuleEngine _ruleEngine = AiRuleEngine();
  final ExifService _exif = ExifService();

  Future<void> initModel() async {
    // Parallel initialization for better performance on Xperia
    await Future.wait([
      _editing.init(),
    ]);
    debugPrint("All Pro AI Models Initialized for Sony Xperia 5 IV.");
  }

  /// Flagship AI Pipeline: The "Brain" of Xperia AI Gallery
  Future<AiAnalysisResult> analyzeImage(Uint8List imageBytes, String imagePath, DateTime? fallbackTime) async {
    // 1. ML Kit Recognition (Parallel with Metadata)
    final results = await Future.wait([
      _exif.readExifTime(imageBytes),
      _recognition.recognize(imagePath),
    ]);

    final DateTime? time = (results[0] as DateTime?) ?? fallbackTime;
    final RecognitionResult recognition = results[1] as RecognitionResult;

    // 2. Rule Engine Selection
    final analysis = _ruleEngine.selectBestPreset(
      recognition: recognition,
      time: time,
    );

    // Store objects for potential removal process
    analysis.detectedObjects = recognition.objects;

    // 4. Gemma Suggestion Layer
    analysis.proSuggestions.add("Gemma Insight: Based on the ${analysis.colorProfile} profile, we recommend reducing background noise to keep the focus on the subject.");

    return analysis;
  }

  /// Applies the AI enhancements to the actual pixels using LiteRT
  Future<Uint8List> applyEnhancements(Uint8List imageBytes, AiAnalysisResult analysis) async {
    // Determine editing mode based on analysis
    EditingMode mode = EditingMode.mirNet;
    if (analysis.environment.contains("Low Light") || analysis.colorProfile.contains("Night")) {
      mode = EditingMode.mirNet;
    } else if (analysis.environment.contains("Landscape")) {
      mode = EditingMode.denoising; // Apply denoising for landscapes
    } else {
      mode = EditingMode.esrGan;
    }

    return await _editing.processImage(imageBytes, mode);
  }

  /// Magic Eraser placeholder (Can be implemented with a specific LiteRT model)
  Future<Uint8List> removeDistractions(Uint8List imageBytes, AiAnalysisResult analysis) async {
    // Currently relying on MIRNet/ESRGAN for quality, 
    // Generative Eraser would need another model
    return imageBytes; 
  }
}
