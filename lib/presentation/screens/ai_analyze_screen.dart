import 'dart:io';
import 'dart:typed_data';
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
  bool _isErasing = false;
  AiAnalysisResult? _analysisResult;
  Uint8List? _enhancedImageBytes;
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

  Future<void> _runMagicEraser() async {
    if (_imageFile == null) return;
    setState(() => _isErasing = true);

    final aiService = ref.read(gemmaAiServiceProvider);
    final bytes = await _imageFile!.readAsBytes();
    
    // Call the Magic Eraser AI service
    final erasedBytes = await aiService.removeDistractions(bytes, _analysisResult!);

    setState(() {
      _isErasing = false;
      _enhancedImageBytes = erasedBytes;
      _showEnhanced = true;
    });

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Magic Eraser: Background distractions removed!"),
          backgroundColor: AppTheme.sonyAccent,
        ),
      );
    }
  }

  Future<void> _runAiEnhance() async {
    if (_imageFile == null) return;

    setState(() {
      _isAnalyzing = true;
    });

    final aiService = ref.read(gemmaAiServiceProvider);
    final bytes = await _imageFile!.readAsBytes();
    
    // Run Gemma 4 AI Analysis
    final result = await aiService.analyzeImage(bytes, widget.asset.createDateTime);

    // Apply real pixel enhancements based on analysis
    final enhancedBytes = await aiService.applyEnhancements(bytes, result);

    setState(() {
      _analysisResult = result;
      _enhancedImageBytes = enhancedBytes;
      _isAnalyzing = false;
      _showEnhanced = true; 
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
                          child: _showEnhanced && _enhancedImageBytes != null
                                ? Image.memory(_enhancedImageBytes!, fit: BoxFit.contain)
                                : Image.file(_imageFile!, fit: BoxFit.contain),
                        ),
                      ),

                      if (_isAnalyzing || _isErasing)
                        Container(
                          color: Colors.black.withValues(alpha: 0.6),
                          child: Center(
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const CircularProgressIndicator(color: AppTheme.sonyAccent),
                                const SizedBox(height: 16),
                                Text(
                                  _isErasing ? "Generative AI: Removing People..." : "Gemma 4: Analyzing Context...",
                                  style: const TextStyle(color: Colors.white, fontSize: 16),
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
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 32),
      decoration: const BoxDecoration(
        color: Color(0xFF121212),
        borderRadius: BorderRadius.vertical(top: Radius.circular(32)),
        boxShadow: [BoxShadow(color: Colors.black54, blurRadius: 20, offset: Offset(0, -5))],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          if (_analysisResult != null) ...[
            _buildResultHeader(),
            const SizedBox(height: 20),
            if (_analysisResult!.hasDistractions) _buildDistractionAlert(),
            const SizedBox(height: 20),
            _buildCompositionMeter(),
            const SizedBox(height: 20),
            _buildProSuggestions(),
            const SizedBox(height: 24),
            _buildActionButtons(),
          ] else ...[
            _buildAnalyzeButton(),
          ],
        ],
      ),
    );
  }

  Widget _buildDistractionAlert() {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.orange.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.orange.withValues(alpha: 0.3)),
      ),
      child: Row(
        children: [
          const Icon(Icons.person_remove, color: Colors.orange, size: 20),
          const SizedBox(width: 12),
          const Expanded(
            child: Text(
              "Detected photobombers in background.",
              style: TextStyle(color: Colors.orange, fontSize: 13),
            ),
          ),
          TextButton(
            onPressed: _runMagicEraser,
            child: const Text("ERASE", style: TextStyle(fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  Widget _buildResultHeader() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              _analysisResult!.environment.toUpperCase(),
              style: const TextStyle(color: AppTheme.sonyAccent, fontSize: 12, fontWeight: FontWeight.bold, letterSpacing: 1.5),
            ),
            const SizedBox(height: 4),
            Text(
              "Profile: ${_analysisResult!.colorProfile}",
              style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
            ),
          ],
        ),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(color: Colors.white10, borderRadius: BorderRadius.circular(20)),
          child: const Row(
            children: [
              Icon(Icons.lens_blur, size: 16, color: AppTheme.sonyAccent),
              SizedBox(width: 6),
              Text("Gemma 4", style: TextStyle(color: Colors.white70, fontSize: 12)),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildCompositionMeter() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text("COMPOSITION SCORE", style: TextStyle(color: Colors.white54, fontSize: 11, letterSpacing: 1)),
            Text("${(_analysisResult!.compositionScore * 100).toInt()}%",
                style: const TextStyle(color: AppTheme.sonyAccent, fontWeight: FontWeight.bold)),
          ],
        ),
        const SizedBox(height: 8),
        ClipRRect(
          borderRadius: BorderRadius.circular(4),
          child: LinearProgressIndicator(
            value: _analysisResult!.compositionScore,
            backgroundColor: Colors.white10,
            color: AppTheme.sonyAccent,
            minHeight: 6,
          ),
        ),
      ],
    );
  }

  Widget _buildProSuggestions() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text("PRO SUGGESTIONS", style: TextStyle(color: Colors.white54, fontSize: 11, letterSpacing: 1)),
        const SizedBox(height: 12),
        ..._analysisResult!.proSuggestions.take(3).map((s) => Padding(
              padding: const EdgeInsets.only(bottom: 8.0),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(Icons.check_circle_outline, size: 16, color: AppTheme.sonyAccent),
                  const SizedBox(width: 10),
                  Expanded(child: Text(s, style: const TextStyle(color: Colors.white, fontSize: 14))),
                ],
              ),
            )),
      ],
    );
  }

  Widget _buildActionButtons() {
    return Row(
      children: [
        Expanded(
          child: OutlinedButton.icon(
            onPressed: () => setState(() => _showEnhanced = !_showEnhanced),
            icon: Icon(_showEnhanced ? Icons.visibility_off : Icons.visibility, size: 18),
            label: Text(_showEnhanced ? "ORIGINAL" : "PREVIEW"),
            style: OutlinedButton.styleFrom(
              side: const BorderSide(color: Colors.white24),
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 16),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: ElevatedButton.icon(
            onPressed: () {},
            icon: const Icon(Icons.download_rounded, size: 18),
            label: const Text("EXPORT"),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.sonyAccent,
              foregroundColor: Colors.black,
              padding: const EdgeInsets.symmetric(vertical: 16),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildAnalyzeButton() {
    return ElevatedButton(
      onPressed: _isAnalyzing ? null : _runAiEnhance,
      style: ElevatedButton.styleFrom(
        backgroundColor: AppTheme.sonyAccent,
        foregroundColor: Colors.black,
        padding: const EdgeInsets.symmetric(vertical: 18),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        elevation: 8,
      ),
      child: const Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.auto_awesome),
          SizedBox(width: 12),
          Text(
            "ANALYZE WITH GEMMA AI",
            style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, letterSpacing: 1.2),
          ),
        ],
      ),
    );
  }
}
