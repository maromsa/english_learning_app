import 'package:english_learning_app/l10n/spark_strings.dart';
import 'package:english_learning_app/services/ai_service.dart';
import 'package:flutter/material.dart';

/// Kid-friendly generate action with loading + localized gateway errors.
///
/// Used by word-art flows and regression tests for 502/503/504 handling.
class AiGeneratePanel extends StatefulWidget {
  const AiGeneratePanel({
    super.key,
    required this.service,
    required this.request,
    this.triggerLabel = 'צרו תמונה',
  });

  final AiService service;
  final AiGenerateRequest request;
  final String triggerLabel;

  @override
  State<AiGeneratePanel> createState() => AiGeneratePanelState();
}

class AiGeneratePanelState extends State<AiGeneratePanel> {
  bool _isGenerating = false;
  String? _errorMessage;
  AiGenerateResult? _result;

  bool get isGenerating => _isGenerating;
  String? get errorMessage => _errorMessage;
  AiGenerateResult? get result => _result;

  Future<void> submit() => _runGenerate();

  Future<void> _runGenerate() async {
    if (_isGenerating) return;

    setState(() {
      _isGenerating = true;
      _errorMessage = null;
      _result = null;
    });

    try {
      final generated = await widget.service.generate(widget.request);
      if (!mounted) return;
      setState(() => _result = generated);
    } on AiServiceException catch (error) {
      if (!mounted) return;
      setState(() => _errorMessage = error.failureCode.userMessage);
    } catch (error) {
      debugPrint('AiGeneratePanel unexpected error: $error');
      if (!mounted) return;
      setState(() => _errorMessage = SparkStrings.aiUnavailable);
    } finally {
      if (mounted) {
        setState(() => _isGenerating = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (_isGenerating)
          const Padding(
            padding: EdgeInsets.all(16),
            child: CircularProgressIndicator(),
          ),
        if (_errorMessage != null)
          Padding(
            padding: const EdgeInsets.all(12),
            child: Text(
              _errorMessage!,
              textAlign: TextAlign.center,
              key: const Key('ai_generate_error'),
            ),
          ),
        if (_result != null)
          const Padding(
            padding: EdgeInsets.all(8),
            child: Icon(Icons.check_circle, color: Colors.green, size: 40),
          ),
        FilledButton(
          onPressed: _isGenerating ? null : _runGenerate,
          child: Text(widget.triggerLabel),
        ),
      ],
    );
  }
}
