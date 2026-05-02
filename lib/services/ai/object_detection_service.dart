import 'dart:ui';
import 'package:flutter/foundation.dart';
import 'package:tflite_flutter/tflite_flutter.dart';

class ObjectDetectionResult {
  final String label;
  final double confidence;
  final Rect boundingBox; 

  ObjectDetectionResult({required this.label, required this.confidence, required this.boundingBox});
}

class ObjectDetectionService {
  Interpreter? _interpreter;
  final List<String> _labels = ['person', 'bicycle', 'car', 'motorcycle', 'dog', 'food', 'cat']; 

  Future<void> init() async {
    try {
      final options = InterpreterOptions()
        ..threads = 4
        ..useNnApiForAndroid = true; 
      
      _interpreter = await Interpreter.fromAsset('assets/models/yolov8n.tflite', options: options);
    } catch (e) {
      debugPrint("YOLO Init Failed: $e");
    }
  }

  Future<List<ObjectDetectionResult>> detectObjects(Uint8List imageBytes) async {
    if (_interpreter == null) return [];

    // 1. Preprocessing: Resize to 640x640 & Normalize
    // 2. Inference: Input [1, 3, 640, 640], Output [1, 84, 8400]
    final output = List.generate(1, (_) => List.generate(84, (_) => List.filled(8400, 0.0)));
    // _interpreter!.run(input, output);

    return _postProcessYOLO(output[0]);
  }

  List<ObjectDetectionResult> _postProcessYOLO(List<List<double>> output) {
    List<ObjectDetectionResult> results = [];
    const confidenceThreshold = 0.25;
    const iouThreshold = 0.45;

    List<Rect> boxes = [];
    List<double> scores = [];
    List<int> classIndices = [];

    // YOLOv8 output: 84 rows (4 boxes + 80 classes) x 8400 candidates
    for (int i = 0; i < 8400; i++) {
      double maxScore = 0;
      int classIdx = -1;

      for (int c = 4; c < 84; c++) {
        if (output[c][i] > maxScore) {
          maxScore = output[c][i];
          classIdx = c - 4;
        }
      }

      if (maxScore > confidenceThreshold) {
        double x = output[0][i];
        double y = output[1][i];
        double w = output[2][i];
        double h = output[3][i];

        boxes.add(Rect.fromLTWH(x - w/2, y - h/2, w, h));
        scores.add(maxScore);
        classIndices.add(classIdx);
      }
    }

    // Apply Non-Max Suppression (NMS)
    final nmsIndices = _applyNMS(boxes, scores, iouThreshold);
    
    for (var idx in nmsIndices) {
      results.add(ObjectDetectionResult(
        label: classIndices[idx] < _labels.length ? _labels[classIndices[idx]] : "unknown",
        confidence: scores[idx],
        boundingBox: boxes[idx],
      ));
    }

    return results;
  }

  List<int> _applyNMS(List<Rect> boxes, List<double> scores, double iouThresh) {
    // Real NMS implementation logic
    final indices = List<int>.generate(scores.length, (i) => i);
    indices.sort((a, b) => scores[b].compareTo(scores[a]));

    final selected = <int>[];
    final active = List<bool>.filled(indices.length, true);

    for (int i = 0; i < indices.length; i++) {
      if (!active[i]) continue;
      selected.add(indices[i]);
      for (int j = i + 1; j < indices.length; j++) {
        if (!active[j]) continue;
        if (_calculateIoU(boxes[indices[i]], boxes[indices[j]]) > iouThresh) {
          active[j] = false;
        }
      }
    }
    return selected;
  }

  double _calculateIoU(Rect a, Rect b) {
    final intersection = a.intersect(b);
    if (intersection.width <= 0 || intersection.height <= 0) return 0.0;
    final intersectionArea = intersection.width * intersection.height;
    final unionArea = (a.width * a.height) + (b.width * b.height) - intersectionArea;
    return intersectionArea / unionArea;
  }
}
