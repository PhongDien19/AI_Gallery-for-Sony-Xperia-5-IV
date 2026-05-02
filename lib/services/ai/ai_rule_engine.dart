import 'dart:math';
import 'package:google_ml_kit/google_ml_kit.dart';
import '../../ai/gemma_ai_service.dart';
import 'recognition_service.dart';

class AiRuleEngine {
  AiAnalysisResult selectBestPreset({
    required RecognitionResult recognition,
    required DateTime? time,
  }) {
    final String scene = recognition.scene;
    final List<DetectedObject> objects = recognition.objects;

    // 1. Determine Main Subject based on Confidence, Size, and Position
    DetectedObject? mainSubject;
    double maxPriority = -1.0;

    for (var obj in objects) {
      // Priority = Confidence * Area * Centrality
      double area = obj.boundingBox.width * obj.boundingBox.height;
      double centerX = obj.boundingBox.center.dx;
      double centerY = obj.boundingBox.center.dy;
      
      // Assuming a normalized coordinate system or common resolution
      double centrality = 1.0 - (sqrt(pow(centerX - 320, 2) + pow(centerY - 320, 2)) / 452.0); 

      double confidence = (obj.labels.isNotEmpty) ? obj.labels.first.confidence : 0.5;
      double priority = confidence * area * centrality;
      
      if (priority > maxPriority) {
        maxPriority = priority;
        mainSubject = obj;
      }
    }

    // 2. Core Flags
    String label = mainSubject?.labels.isNotEmpty == true ? mainSubject!.labels.first.text : "";
    final bool isPortrait = label == "person" || recognition.faces.isNotEmpty;
    final bool isFood = label == "food" || scene == "Food";
    final bool isPet = label == "dog" || label == "cat";
    final bool isGoldenHour = time != null && (time.hour >= 17 && time.hour <= 19);

    // 3. Selection Logic
    if (isPortrait) {
      if (isGoldenHour || scene == "sunset") {
        return _buildResult("Golden Portrait Pro", "Soft Skin + Warm Glow", 0.96, 
          {"Exposure": 1.1, "Temp": 1.3, "SkinSoftness": 1.4},
          label: label
        );
      }
      return _buildResult("Pro Portrait", "Soft Skin Tone", 0.94, 
        {"SkinSoftness": 1.25, "Contrast": 0.9},
        label: label
      );
    }

    if (scene == "beach" && isGoldenHour) {
      return _buildResult("Warm Beach Sunset", "Golden Hour Tones", 0.97, 
        {"Vibrance": 1.35, "Temp": 1.45, "Highlights": 0.8},
        label: label
      );
    }

    if (isFood || scene == "food") {
      return _buildResult("Food Master", "High Detail & Pop", 0.92, 
        {"Saturation": 1.3, "Sharpness": 1.4, "Exposure": 1.1},
        label: label
      );
    }

    if (isPet || scene == "pet") {
      return _buildResult("Natural Pet Fur", "Texture Enhancement", 0.91, 
        {"Texture": 1.35, "Sharpness": 1.25, "Temp": 1.15},
        label: label
      );
    }

    // Default: Professional AI Optimized
    return _buildResult("AI Scene Optimizer", "Balanced Clarity", 0.88, 
      {"Clarity": 1.25, "Contrast": 1.2, "Saturation": 1.1},
      label: label
    );
  }

  AiAnalysisResult _buildResult(String profile, String env, double score, Map<String, double> adj, {String label = ""}) {
    final result = AiAnalysisResult(
      environment: env,
      compositionScore: score,
      colorProfile: profile,
      proSuggestions: ["Optimized based on $profile model outputs."],
      technicalAdjustments: adj,
      hasDistractions: true,
    );
    result.mainSubjectLabel = label;
    return result;
  }
}
