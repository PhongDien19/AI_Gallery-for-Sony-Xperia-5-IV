import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/foundation.dart';
import 'package:google_generative_ai/google_generative_ai.dart';
import 'recognition_service.dart';

class GenAiService {
  // In a real app, this would be your Google AI API Key
  static const String _apiKey = "REPLACE_WITH_YOUR_GEMINI_KEY";
  
  GenerativeModel? _model;

  GenAiService() {
    if (_apiKey != "REPLACE_WITH_YOUR_GEMINI_KEY") {
      _model = GenerativeModel(model: 'gemini-1.5-flash', apiKey: _apiKey);
    }
  }

  /// Generates a professional editing strategy prompt based on visual recognition
  /// New: Sends image bytes to Gemini 1.5 Flash for professional visual analysis
  Future<Map<String, dynamic>> analyzeImageMultimodal({
    required Uint8List imageBytes,
    String? userInstruction,
  }) async {
    if (_model == null) return _fallbackEditingPlan(userInstruction);

    try {
      final prompt = """
You are a Sony Xperia Pro Colorist and AI Editor.
User Command: "${userInstruction ?? "Analyze and optimize"}"
Look at this image and the user command. 
Return ONLY a valid JSON object matching exactly this format:
{
  "exposure": 1.0,
  "saturation": 1.0,
  "contrast": 1.0,
  "remove_distractions": false,
  "style": "Natural"
}
Rules:
- "remove_distractions" should be true ONLY if the user asks to remove, erase, or clear people/objects/distractions.
- "style" can be "Natural", "Cinematic", "Sunrise", or "S-Cinetone" depending on the user's color intent.
- Do not wrap the JSON in markdown blocks like ```json.
""";
      
      final content = [
        Content.multi([
          TextPart(prompt),
          DataPart('image/jpeg', imageBytes),
        ])
      ];

      final response = await _model!.generateContent(content);
      final responseText = response.text ?? "";
      debugPrint("Gemini Multimodal Response: \$responseText");
      
      // Clean up markdown if Gemini still included it
      final cleanJson = responseText.replaceAll('```json', '').replaceAll('```', '').trim();
      
      try {
        final Map<String, dynamic> plan = jsonDecode(cleanJson);
        return plan;
      } catch (e) {
        debugPrint("Failed to parse Gemini JSON: \$e");
        return _fallbackEditingPlan(userInstruction);
      }
    } catch (e) {
      return _fallbackEditingPlan(userInstruction);
    }
  }

  Map<String, dynamic> _fallbackEditingPlan(String? instruction) {
    final lower = instruction?.toLowerCase() ?? "";
    return {
      "exposure": 1.0,
      "saturation": 1.0,
      "contrast": 1.0,
      "remove_distractions": lower.contains("xóa") || lower.contains("remove") || lower.contains("erase"),
      "style": lower.contains("phim") || lower.contains("cinematic") ? "Cinematic" : "Natural"
    };
  }

  /// Generates a professional editing strategy prompt based on visual recognition
  Future<String> generateEditingStrategy({
    required RecognitionResult recognition,
    required String scene,
    required String colorProfile,
  }) async {
    final List<String> objects = recognition.objects.map((e) => e.labels.isNotEmpty ? e.labels.first.text : "object").toList();
    final bool hasPeople = objects.any((o) => o.toLowerCase().contains("person") || o.toLowerCase().contains("man") || o.toLowerCase().contains("woman"));

    final prompt = """
    Analyze this photo context for a Sony Xperia flagship:
    - Scene: $scene
    - Objects detected: ${objects.join(", ")}
    - Contains People: $hasPeople
    
    Task: Generate a high-end AI Command starting with 'AI Command:'.
    If people/photobombers are detected in the background, prioritize 'removing' them to create a clean, minimalist composition.
    Also suggest a color grading style (e.g., 'Warm Sunrise', 'S-Cinetone', 'Cinematic Teal').
    
    Example: 'AI Command: Erase background photobombers and apply S-Cinetone for a professional portrait look.'
    """;

    if (_model != null) {
      try {
        final content = [Content.text(prompt)];
        final response = await _model!.generateContent(content);
        return response.text ?? _generateFallbackPrompt(scene, objects, hasPeople);
      } catch (e) {
        return _generateFallbackPrompt(scene, objects, hasPeople);
      }
    } else {
      return _generateFallbackPrompt(scene, objects, hasPeople);
    }
  }

  String _generateFallbackPrompt(String scene, List<String> objects, bool hasPeople) {
    String command = "AI Command: ";
    if (hasPeople) {
      command += "Erase background distractions and people to isolate the subject. ";
    } else {
      command += "Clear minor photobombers and optimize framing. ";
    }

    if (scene == "Landscape") {
      command += "Enhance horizon depth with Sunrise style.";
    } else if (scene == "Portrait") {
      command += "Apply S-Cinetone for natural skin tones.";
    } else {
      command += "Adjust dynamic range for a cinematic look.";
    }
    return command;
  }
}
