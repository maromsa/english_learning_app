import 'dart:convert';
import 'dart:typed_data';

import 'package:google_generative_ai/google_generative_ai.dart';
import 'package:http/http.dart' as http;

/// Contract for validating whether an image matches a requested word.
abstract class AiImageValidator {
  Future<bool> validate(Uint8List imageBytes, String word, {String? mimeType});
}

/// Validator that always approves the provided image.
class PassthroughAiImageValidator implements AiImageValidator {
  const PassthroughAiImageValidator();

  @override
  Future<bool> validate(Uint8List imageBytes, String word, {String? mimeType}) async => true;
}

/// Uses Gemini to confirm that the supplied image depicts the requested word.
class GeminiAiImageValidator implements AiImageValidator {
  GeminiAiImageValidator(this._model);

  final GenerativeModel _model;

  static const String _promptTemplate =
      'You are helping a child learn English words. '
      'Does this picture clearly show the object "{word}" as the main focus? '
      'Answer strictly with "yes" or "no".';

  @override
  Future<bool> validate(Uint8List imageBytes, String word, {String? mimeType}) async {
    final prompt = _promptTemplate.replaceFirst('{word}', word);

    try {
      final response = await _model.generateContent([
        Content.multi([
          TextPart(prompt),
          DataPart(mimeType ?? 'image/jpeg', imageBytes),
        ]),
      ]);

      final answer = response.text?.trim().toLowerCase();
      if (answer == null || answer.isEmpty) {
        return false;
      }

      if (answer.startsWith('yes')) {
        return true;
      }

      if (answer.startsWith('no')) {
        return false;
      }

      return answer.contains('yes');
    } catch (_) {
      return false;
    }
  }
}

/// Calls an HTTP endpoint (e.g., Cloud Function) to validate image-word matches.
class HttpFunctionAiImageValidator implements AiImageValidator {
  HttpFunctionAiImageValidator(
    this._validationEndpoint, {
    http.Client? client,
    Duration timeout = const Duration(seconds: 8),
    double minimumConfidence = 0.5,
  })  : assert(minimumConfidence >= 0 && minimumConfidence <= 1,
          'minimumConfidence must be between 0 and 1.'),
          _httpClient = client ?? http.Client(),
          _disposeClientOnClose = client == null,
          _requestTimeout = timeout,
          _minimumConfidence = minimumConfidence;

  final Uri _validationEndpoint;
  final http.Client _httpClient;
  final bool _disposeClientOnClose;
  final Duration _requestTimeout;
  final double _minimumConfidence;
  double? _lastConfidence;
  bool? _lastApproval;

  double? get lastConfidence => _lastConfidence;
  bool? get lastApproval => _lastApproval;

  @override
  Future<bool> validate(Uint8List imageBytes, String word, {String? mimeType}) async {
    try {
      _lastConfidence = null;
      _lastApproval = null;
      final response = await _httpClient
          .post(
              _validationEndpoint,
            headers: const {'Content-Type': 'application/json'},
            body: jsonEncode({
              'word': word,
              'mimeType': mimeType,
              'imageBase64': base64Encode(imageBytes),
            }),
          )
            .timeout(_requestTimeout);

      if (response.statusCode != 200) {
        return false;
      }

      final decoded = jsonDecode(response.body);
      if (decoded is! Map<String, dynamic>) {
        return false;
      }

      final parsedConfidence = _parseConfidence(decoded['confidence']);
      if (parsedConfidence != null) {
        _lastConfidence = parsedConfidence;
      }

      final approved = decoded['approved'];
      if (approved is bool) {
        _lastConfidence ??= approved ? 1.0 : 0.0;
        _lastApproval = approved;
        return approved;
      }

      final confidence = _lastConfidence;
      if (confidence != null) {
        final isApproved = confidence >= _minimumConfidence;
        _lastApproval = isApproved;
        return isApproved;
      }

      return false;
    } catch (_) {
      _lastConfidence = null;
      _lastApproval = null;
      return false;
    }
  }

  void dispose() {
    if (_disposeClientOnClose) {
      _httpClient.close();
    }
  }

  double? _parseConfidence(Object? value) {
    if (value is num) {
      return value.toDouble();
    }
    if (value is String) {
      return double.tryParse(value);
    }
    return null;
  }
}
