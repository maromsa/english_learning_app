import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';

import 'network/app_http_client.dart';

class GeminiProxyService {
  GeminiProxyService(
    Uri endpoint, {
    AppHttpClient? httpClient,
    Duration timeout = const Duration(seconds: 12),
  })  : _endpoint = endpoint,
        _httpClient = httpClient ??
            AppHttpClient(
              connectTimeout: timeout,
              receiveTimeout: timeout,
              sendTimeout: timeout,
            ),
        _timeout = timeout;

  final Uri _endpoint;
  final AppHttpClient _httpClient;
  final Duration _timeout;

  Future<String?> identifyMainObject(
    Uint8List imageBytes, {
    required String prompt,
    String mimeType = 'image/jpeg',
  }) async {
    final response = await _postJson({
      'mode': 'identify',
      'prompt': prompt,
      'mimeType': mimeType,
      'imageBase64': base64Encode(imageBytes),
    });

    if (response == null) return null;
    final text = response['text'];
    if (text is String) {
      return text.trim().isEmpty ? null : text.trim();
    }

    return null;
  }

  Future<String?> generateText(
    String prompt, {
    String? systemInstruction,
  }) async {
    final payload = {
      'mode': 'text',
      'prompt': prompt,
      if (systemInstruction != null) 'system_instruction': systemInstruction,
    };
    debugPrint('[GeminiProxyService] Sending payload: ${jsonEncode(payload)}');
    debugPrint(
        '[GeminiProxyService] systemInstruction present: ${systemInstruction != null}');
    if (systemInstruction != null) {
      debugPrint(
          '[GeminiProxyService] systemInstruction length: ${systemInstruction.length}');
      debugPrint(
          '[GeminiProxyService] systemInstruction preview: ${systemInstruction.substring(0, systemInstruction.length > 100 ? 100 : systemInstruction.length)}...');
    }
    final response = await _postJson(payload);

    if (response == null) return null;

    final text = response['text'];
    if (text is String) {
      return text.trim().isEmpty ? null : text.trim();
    }

    return null;
  }

  Future<Map<String, dynamic>?> _postJson(Map<String, dynamic> payload) async {
    try {
      debugPrint('[GeminiProxyService] POST to $_endpoint');
      debugPrint('[GeminiProxyService] Request body: ${jsonEncode(payload)}');

      final response = await _httpClient.dio.postUri<Map<String, dynamic>>(
        _endpoint,
        data: payload,
        options: Options(
          contentType: Headers.jsonContentType,
          responseType: ResponseType.json,
        ),
      );

      debugPrint(
          '[GeminiProxyService] Response status: ${response.statusCode}');
      debugPrint('[GeminiProxyService] Response body: ${response.data}');

      if (response.statusCode != 200) {
        return null;
      }

      final decoded = response.data;
      if (decoded is Map<String, dynamic>) {
        return decoded;
      }
      return null;
    } on DioException catch (error, stackTrace) {
      if (error.type == DioExceptionType.connectionTimeout ||
          error.type == DioExceptionType.receiveTimeout) {
        debugPrint('[GeminiProxyService] Timeout: $error');
        return null;
      }
      debugPrint('[GeminiProxyService] Dio error: ${error.message}');
      debugPrint('$stackTrace');
      return null;
    }
  }

  void dispose() {
    _httpClient.close();
  }
}
