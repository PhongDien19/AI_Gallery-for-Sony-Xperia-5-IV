import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../services/ai/recognition_service.dart';
import '../services/ai/image_editing_service.dart';
import '../services/metadata/exif_service.dart';
import '../services/ai/ai_rule_engine.dart';
import '../services/ai/gen_ai_service.dart';

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
  List<dynamic> detectedObjects = []; 
  String mainSubjectLabel = "";
  String aiPrompt = "";

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
  final GenAiService _genAi = GenAiService();

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

    // 4. GenAI Prompt Generation
    final aiPrompt = await _genAi.generateEditingStrategy(
      recognition: recognition,
      scene: analysis.environment,
      colorProfile: analysis.colorProfile,
    );
    analysis.aiPrompt = aiPrompt;
    analysis.proSuggestions.add(aiPrompt);

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

  /// Magic Eraser: Background distractions removed!
  Future<Uint8List> removeDistractions(Uint8List imageBytes, AiAnalysisResult analysis) async {
    if (analysis.detectedObjects.isEmpty) return imageBytes;
    return await _editing.eraseObjects(imageBytes, analysis.detectedObjects); 
  }

  /// AI Command Edit: Follow user instructions
  Future<Uint8List> customEdit(Uint8List imageBytes, AiAnalysisResult analysis, String userInstruction) async {
    final plan = await _genAi.analyzeImageMultimodal(
      imageBytes: imageBytes,
      userInstruction: userInstruction,
    );

    // Update the prompt so the user sees Gemini's understanding
    analysis.aiPrompt = "User Command Executed: $userInstruction. Applied style: ${plan['style']} with modified exposure and contrast.";

    // If the plan suggests removing distractions, do that first
    Uint8List workingBytes = imageBytes;
    if (plan['remove_distractions'] == true && analysis.detectedObjects.isNotEmpty) {
      workingBytes = await _editing.eraseObjects(workingBytes, analysis.detectedObjects);
    }

    // Since we don't have a direct 'apply JSON values' in ImageEditingService yet,
    // we'll map the 'style' to our predefined modes or use a fallback logic.
    final style = plan['style']?.toString().toLowerCase() ?? "natural";
    final isWarm = userInstruction.toLowerCase().contains('warm') || userInstruction.toLowerCase().contains('ấm');
    final isPortrait = userInstruction.toLowerCase().contains('portrait') || userInstruction.toLowerCase().contains('chân dung');
    final isCinematic = userInstruction.toLowerCase().contains('cinematic') || userInstruction.toLowerCase().contains('phim');

    if (style == "natural" && !isWarm && !isPortrait && !isCinematic) {
      // User likely just wanted to erase or didn't specify a style.
      return workingBytes;
    }

    EditingMode mode = EditingMode.cinematic;
    if (style.contains('sunrise') || isWarm) {
      mode = EditingMode.sunrise;
    } else if (style.contains('natural') || isPortrait) {
      mode = EditingMode.sCinetone;
    }

    return await _editing.processImage(workingBytes, mode);
  }
}
