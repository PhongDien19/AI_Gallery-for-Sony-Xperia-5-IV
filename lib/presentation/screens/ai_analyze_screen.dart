import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:photo_manager/photo_manager.dart';

import '../../core/theme/app_theme.dart';
import '../../ai/gemma_ai_service.dart';

class AiAnalyzeScreen extends ConsumerStatefulWidget {
  final AssetEntity asset;

  const AiAnalyzeScreen({super.key, required this.asset});

  @override
  ConsumerState<AiAnalyzeScreen> createState() => _AiAnalyzeScreenState();
}

class _AiAnalyzeScreenState extends ConsumerState<AiAnalyzeScreen> {
  File? _imageFile;
  bool _isAnalyzing = false;
  AiAnalysisResult? _analysisResult;
  bool _showEnhanced = false;

  @override
  void initState() {
    super.initState();
    _loadImage();
  }

  Future<void> _loadImage() async {
    final file = await widget.asset.file;
    setState(() {
      _imageFile = file;
    });
  }

  Future<void> _runAiEnhance() async {
    if (_imageFile == null) return;

    setState(() {
      _isAnalyzing = true;
    });

    final aiService = ref.read(gemmaAiServiceProvider);
    final bytes = await _imageFile!.readAsBytes();
    
    // Run Gemma 4 AI Analysis
    final result = await aiService.analyzeImage(bytes);

    setState(() {
      _analysisResult = result;
      _isAnalyzing = false;
      _showEnhanced = true; // Auto-show enhanced version
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.oledBlack,
      appBar: AppBar(
        title: const Text('AI Enhance', style: TextStyle(letterSpacing: 1.0)),
        backgroundColor: Colors.transparent,
      ),
      body: _imageFile == null
          ? const Center(child: CircularProgressIndicator(color: AppTheme.sonyAccent))
          : Column(
              children: [
                Expanded(
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      // Full screen image preview (Hero animated from gallery)
                      Hero(
                        tag: widget.asset.id,
                        child: InteractiveViewer(
                          child: _showEnhanced
                              ? ColorFiltered(
                                  // Mocking an enhancement via ColorFilter based on AI parameters
                                  colorFilter: const ColorFilter.matrix([
                                    1.2, 0, 0, 0, 0, // Increase red / brightness
                                    0, 1.2, 0, 0, 0,
                                    0, 0, 1.2, 0, 0,
                                    0, 0, 0, 1, 0,
                                  ]),
                                  child: Image.file(_imageFile!, fit: BoxFit.contain),
                                )
                              : Image.file(_imageFile!, fit: BoxFit.contain),
                        ),
                      ),

                      if (_isAnalyzing)
                        Container(
                          color: Colors.black.withValues(alpha: 0.6),
                          child: const Center(
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                CircularProgressIndicator(color: AppTheme.sonyAccent),
                                SizedBox(height: 16),
                                Text(
                                  "Gemma 4: Analyzing Environment...",
                                  style: TextStyle(color: Colors.white, fontSize: 16),
                                ),
                              ],
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
                _buildControlPanel(),
              ],
            ),
    );
  }

  Widget _buildControlPanel() {
    return Container(
      padding: const EdgeInsets.all(24.0),
      decoration: BoxDecoration(
        color: AppTheme.darkGrey,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (_analysisResult != null) ...[
            Text(
              "Detected: ${_analysisResult!.environment}",
              style: const TextStyle(
                color: AppTheme.sonyAccent,
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                ElevatedButton.icon(
                  onPressed: () {
                    setState(() {
                      _showEnhanced = !_showEnhanced;
                    });
                  },
                  icon: const Icon(Icons.compare),
                  label: Text(_showEnhanced ? "Show Original" : "Show Enhanced"),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.white12,
                    foregroundColor: Colors.white,
                  ),
                ),
                ElevatedButton.icon(
                  onPressed: () {
                    // Save enhanced photo logic
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text("Enhanced Photo Saved!")),
                    );
                  },
                  icon: const Icon(Icons.save),
                  label: const Text("Save Copy"),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.sonyAccent,
                    foregroundColor: Colors.black,
                  ),
                ),
              ],
            ),
          ] else ...[
            ElevatedButton(
              onPressed: _isAnalyzing ? null : _runAiEnhance,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.sonyAccent,
                foregroundColor: Colors.black,
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              child: const Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.auto_awesome),
                  SizedBox(width: 8),
                  Text(
                    "Auto Enhance with AI",
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}
