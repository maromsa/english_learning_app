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
    this._endpoint, {
    http.Client? client,
    Duration timeout = const Duration(seconds: 8),
  })  : _client = client ?? http.Client(),
        _ownsClient = client == null,
        _timeout = timeout;

  final Uri _endpoint;
  final http.Client _client;
  final bool _ownsClient;
  final Duration _timeout;
  double? _lastConfidence;

  double? get lastConfidence => _lastConfidence;

  @override
  Future<bool> validate(Uint8List imageBytes, String word, {String? mimeType}) async {
    try {
      _lastConfidence = null;
      final response = await _client
          .post(
            _endpoint,
            headers: const {'Content-Type': 'application/json'},
            body: jsonEncode({
              'word': word,
              'mimeType': mimeType,
              'imageBase64': base64Encode(imageBytes),
            }),
          )
          .timeout(_timeout);

      if (response.statusCode != 200) {
        return false;
      }

      final decoded = jsonDecode(response.body);
      if (decoded is! Map<String, dynamic>) {
        return false;
      }

      final confidenceValue = decoded['confidence'];
      if (confidenceValue is num) {
        _lastConfidence = confidenceValue.toDouble();
      }

      final approved = decoded['approved'] as bool?;
      if (approved != null) {
        _lastConfidence ??= approved ? 1.0 : 0.0;
        return approved;
      }

      final confidence = _lastConfidence;
      return confidence != null && confidence >= 0.5;
    } catch (_) {
      return false;
    }
  }

  void dispose() {
    if (_ownsClient) {
      _client.close();
    }
  }
}
