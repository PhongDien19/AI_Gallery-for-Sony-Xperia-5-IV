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
  Future<String> generateEditingStrategy({
    required RecognitionResult recognition,
    required String scene,
    required String colorProfile,
  }) async {
    final List<String> objects = recognition.objects.map((e) => e.labels.isNotEmpty ? e.labels.first.text : "object").toList();
    
    final prompt = """
    Analyze this photo context:
    - Scene: $scene
    - Objects detected: ${objects.join(", ")}
    - Color Profile: $colorProfile
    
    As a professional Sony Xperia colorist, generate a 1-sentence editing strategy starting with 'AI Prompt:'.
    Example: 'AI Prompt: Enhance the sunrise warmth and remove the distractions on the beach for a cinematic look.'
    """;

    if (_model != null) {
      try {
        final content = [Content.text(prompt)];
        final response = await _model!.generateContent(content);
        return response.text ?? _generateFallbackPrompt(scene, objects);
      } catch (e) {
        return _generateFallbackPrompt(scene, objects);
      }
    } else {
      return _generateFallbackPrompt(scene, objects);
    }
  }

  String _generateFallbackPrompt(String scene, List<String> objects) {
    if (scene == "Landscape") {
      return "AI Prompt: Deepen the horizon colors and remove the tiny photobombers for a vast landscape feel.";
    } else if (scene == "Portrait") {
      return "AI Prompt: Soften the skin tones and blur the background clutter to isolate the subject.";
    } else if (scene == "Food") {
      return "AI Prompt: Boost the vibrancy and micro-contrast to make the dish pop against the table.";
    }
    return "AI Prompt: Balance the dynamic range and clear distractions for a cleaner composition.";
  }
}
