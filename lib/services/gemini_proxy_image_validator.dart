import 'dart:typed_data';

import 'package:english_learning_app/services/ai_image_validator.dart';
import 'package:english_learning_app/services/gemini_proxy_service.dart';

/// [AiImageValidator] backed by the deployed Gemini proxy `validate` handler.
class GeminiProxyImageValidator implements AiImageValidator {
  GeminiProxyImageValidator(this._proxy, {double minimumConfidence = 0.45})
      : _minimumConfidence = minimumConfidence;

  final GeminiProxyService _proxy;
  final double _minimumConfidence;

  double? _lastConfidence;
  bool? _lastApproval;

  double? get lastConfidence => _lastConfidence;
  bool? get lastApproval => _lastApproval;

  @override
  Future<bool> validate(
    Uint8List imageBytes,
    String word, {
    String? mimeType,
  }) async {
    _lastConfidence = null;
    _lastApproval = null;

    final result = await _proxy.validateImageMatch(
      imageBytes,
      word,
      mimeType: mimeType ?? 'image/jpeg',
    );

    if (result == null) {
      return false;
    }

    _lastApproval = result.approved;
    _lastConfidence = result.confidence;

    if (!result.approved) {
      return false;
    }

    final confidence = result.confidence;
    if (confidence == null) {
      return true;
    }

    return confidence >= _minimumConfidence;
  }
}
