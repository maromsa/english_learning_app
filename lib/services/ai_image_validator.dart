import 'dart:convert';
import 'dart:typed_data';

import 'package:http/http.dart' as http;

/// Contract for validating whether an image matches a requested word.
abstract class AiImageValidator {
  Future<bool> validate(Uint8List imageBytes, String word, {String? mimeType});
}

/// Validator that always approves the provided image.
class PassthroughAiImageValidator implements AiImageValidator {
  const PassthroughAiImageValidator();

  @override
  Future<bool> validate(
    Uint8List imageBytes,
    String word, {
    String? mimeType,
  }) async => true;
}

/// Calls an HTTP endpoint (e.g., Cloud Function) to validate image-word matches.
class HttpFunctionAiImageValidator implements AiImageValidator {
  HttpFunctionAiImageValidator(
    this._validationEndpoint, {
    http.Client? client,
    Duration timeout = const Duration(seconds: 8),
    double minimumConfidence = 0.5,
  }) : assert(
         minimumConfidence >= 0 && minimumConfidence <= 1,
         'minimumConfidence must be between 0 and 1.',
       ),
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
  Future<bool> validate(
    Uint8List imageBytes,
    String word, {
    String? mimeType,
  }) async {
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
