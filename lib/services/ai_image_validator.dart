import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';

import 'network/app_http_client.dart';

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
  }) async =>
      true;
}

/// Calls an HTTP endpoint (e.g., Cloud Function) to validate image-word matches.
class HttpFunctionAiImageValidator implements AiImageValidator {
  HttpFunctionAiImageValidator(
    this._validationEndpoint, {
    AppHttpClient? client,
    Duration timeout = const Duration(seconds: 8),
    double minimumConfidence = 0.5,
  })  : assert(
          minimumConfidence >= 0 && minimumConfidence <= 1,
          'minimumConfidence must be between 0 and 1.',
        ),
        _httpClient = client ??
            AppHttpClient(
              connectTimeout: timeout,
              receiveTimeout: timeout,
              sendTimeout: timeout,
            ),
        _requestTimeout = timeout,
        _minimumConfidence = minimumConfidence;

  final Uri _validationEndpoint;
  final AppHttpClient _httpClient;
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
      final response = await _httpClient.dio.postUri<Map<String, dynamic>>(
        _validationEndpoint,
        data: {
          'word': word,
          'mimeType': mimeType,
          'imageBase64': base64Encode(imageBytes),
        },
        options: Options(
          contentType: Headers.jsonContentType,
          responseType: ResponseType.json,
        ),
      );

      if (response.statusCode != 200) {
        return false;
      }

      final decoded = response.data;
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
    } on DioException catch (error) {
      debugPrint('AI validator network error: ${error.message}');
      _lastConfidence = null;
      _lastApproval = null;
      return false;
    } catch (_) {
      _lastConfidence = null;
      _lastApproval = null;
      return false;
    }
  }

  void dispose() {
    _httpClient.close();
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
