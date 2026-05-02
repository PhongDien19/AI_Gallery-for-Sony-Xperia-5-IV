import 'package:google_ml_kit/google_ml_kit.dart';

class RecognitionResult {
  final List<String> labels;
  final List<DetectedObject> objects;
  final List<Face> faces;
  final String scene;

  RecognitionResult({
    required this.labels,
    required this.objects,
    required this.faces,
    required this.scene,
  });
}

class RecognitionService {
  late ImageLabeler _imageLabeler;
  late ObjectDetector _objectDetector;
  late FaceDetector _faceDetector;

  RecognitionService() {
    // Initialize ML Kit components
    _imageLabeler = ImageLabeler(options: ImageLabelerOptions(confidenceThreshold: 0.4));
    
    _objectDetector = ObjectDetector(
      options: ObjectDetectorOptions(
        mode: DetectionMode.single,
        classifyObjects: true,
        multipleObjects: true,
      ),
    );

    _faceDetector = FaceDetector(
      options: FaceDetectorOptions(
        enableContours: true,
        enableClassification: true,
        enableLandmarks: true,
      ),
    );
  }

  Future<RecognitionResult> recognize(String imagePath) async {
    final inputImage = InputImage.fromFilePath(imagePath);

    // 1. Scene & Labeling
    final labels = await _imageLabeler.processImage(inputImage);
    final labelTexts = labels.map((l) => l.label).toList();
    
    // Determine primary scene
    String scene = "Unknown";
    bool isLowLight = labelTexts.any((l) => l.toLowerCase().contains('night') || l.toLowerCase().contains('dark'));
    
    if (labelTexts.any((l) => l.toLowerCase().contains('food'))) {
      scene = "Food";
    } else if (labelTexts.any((l) => l.toLowerCase().contains('portrait') || l.toLowerCase().contains('person') || l.toLowerCase().contains('face'))) {
      scene = "Portrait";
    } else if (labelTexts.any((l) => 
        l.toLowerCase().contains('sky') || 
        l.toLowerCase().contains('mountain') || 
        l.toLowerCase().contains('landscape') || 
        l.toLowerCase().contains('nature') ||
        l.toLowerCase().contains('water') ||
        l.toLowerCase().contains('sea') ||
        l.toLowerCase().contains('ocean') ||
        l.toLowerCase().contains('sunset') ||
        l.toLowerCase().contains('sunrise') ||
        l.toLowerCase().contains('bridge') ||
        l.toLowerCase().contains('horizon')
      )) {
      scene = "Landscape";
    } else if (isLowLight) {
      scene = "Low Light";
    }

    // 2. Object Detection
    final objects = await _objectDetector.processImage(inputImage);

    // 3. Face Detection
    final faces = await _faceDetector.processImage(inputImage);

    return RecognitionResult(
      labels: labelTexts,
      objects: objects,
      faces: faces,
      scene: scene,
    );
  }

  void dispose() {
    _imageLabeler.close();
    _objectDetector.close();
    _faceDetector.close();
  }
}
