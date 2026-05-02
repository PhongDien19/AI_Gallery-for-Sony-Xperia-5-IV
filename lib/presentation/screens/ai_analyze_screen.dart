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
    if (file != null) {
      setState(() {
        _imageFile = file;
      });
      // Automatic background scan when image is opened
      _runBackgroundScan();
    }
  }

  Future<void> _runBackgroundScan() async {
    if (_imageFile == null) return;
    
    final aiService = ref.read(gemmaAiServiceProvider);
    final bytes = await _imageFile!.readAsBytes();
    
    // Quick scan with ML Kit (The "Eyes")
    final result = await aiService.analyzeImage(bytes, _imageFile!.path, widget.asset.createDateTime);

    if (mounted) {
      setState(() {
        _analysisResult = result;
      });
    }
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
    final result = await aiService.analyzeImage(bytes, _imageFile!.path, widget.asset.createDateTime);

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
                                ? Image.memory(
                                    _enhancedImageBytes!, 
                                    key: const ValueKey('enhanced'),
                                    fit: BoxFit.contain,
                                    errorBuilder: (context, error, stackTrace) => const Center(child: Icon(Icons.error_outline, color: Colors.red)),
                                  )
                                : Image.file(
                                    _imageFile!, 
                                    key: const ValueKey('original'),
                                    fit: BoxFit.contain,
                                  ),
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
            _buildContextualSuggestion(),
            const SizedBox(height: 24),
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
    return Column(
      children: [
        Container(
          margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Colors.blue.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.blue.withValues(alpha: 0.3)),
          ),
          child: Row(
            children: [
              const Icon(Icons.psychology, color: Colors.blue),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  _analysisResult!.aiPrompt,
                  style: const TextStyle(
                    color: Colors.white70,
                    fontStyle: FontStyle.italic,
                    fontSize: 13,
                  ),
                ),
              ),
            ],
          ),
        ),
        
        Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        _analysisResult!.environment.toUpperCase(),
                        style: TextStyle(
                          color: Colors.blue[200],
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 1.2,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Profile: ${_analysisResult!.colorProfile}',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                  const Spacer(),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Row(
                      children: [
                        Icon(Icons.auto_awesome, size: 14, color: Colors.blue[200]),
                        const SizedBox(width: 4),
                        const Text(
                          'Gemma 4',
                          style: TextStyle(color: Colors.white70, fontSize: 12),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
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

  Widget _buildContextualSuggestion() {
    String suggestionText = "AI detected ${_analysisResult!.environment} scene.";
    IconData icon = Icons.auto_awesome;
    
    if (_analysisResult!.environment.contains("Landscape")) {
      suggestionText = "Landscape detected. Optimize for clarity and color?";
      icon = Icons.landscape;
    } else if (_analysisResult!.environment.contains("Portrait")) {
      suggestionText = "Portrait detected. Optimize skin tones?";
      icon = Icons.face;
    } else if (_analysisResult!.environment.contains("Food")) {
      suggestionText = "Food detected. Enhance detail and pop?";
      icon = Icons.restaurant;
    }

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [AppTheme.sonyAccent.withValues(alpha: 0.2), Colors.transparent],
          begin: Alignment.centerLeft,
          end: Alignment.centerRight,
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppTheme.sonyAccent.withValues(alpha: 0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: AppTheme.sonyAccent, size: 24),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  suggestionText,
                  style: const TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.w500),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          ElevatedButton(
            onPressed: _isAnalyzing ? null : _runAiEnhance,
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.sonyAccent,
              foregroundColor: Colors.black,
              minimumSize: const Size(double.infinity, 48),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                if (_isAnalyzing)
                  const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2, color: Colors.black),
                  )
                else
                  const Icon(Icons.auto_fix_high, size: 18),
                const SizedBox(width: 8),
                const Text("AI OPTIMIZE", style: TextStyle(fontWeight: FontWeight.bold, letterSpacing: 1)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAnalyzeButton() {
    return Column(
      children: [
        const CircularProgressIndicator(color: AppTheme.sonyAccent, strokeWidth: 2),
        const SizedBox(height: 16),
        const Text("AI is scanning image...", style: TextStyle(color: Colors.white54, fontSize: 12)),
      ],
    );
  }
}
