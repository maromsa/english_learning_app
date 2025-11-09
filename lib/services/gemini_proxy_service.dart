import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:http/http.dart' as http;

class GeminiProxyService {
  GeminiProxyService(
    Uri endpoint, {
    http.Client? client,
    Duration timeout = const Duration(seconds: 12),
  })  : _endpoint = endpoint,
        _httpClient = client ?? http.Client(),
        _disposeClientOnClose = client == null,
        _timeout = timeout;

  final Uri _endpoint;
  final http.Client _httpClient;
  final bool _disposeClientOnClose;
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
    final response = await _postJson({
      'mode': 'text',
      'prompt': prompt,
      if (systemInstruction != null) 'systemInstruction': systemInstruction,
    });

    if (response == null) return null;

    final text = response['text'];
    if (text is String) {
      return text.trim().isEmpty ? null : text.trim();
    }

    return null;
  }

  Future<Map<String, dynamic>?> _postJson(Map<String, dynamic> payload) async {
    try {
      final response = await _httpClient
          .post(
            _endpoint,
            headers: const {'Content-Type': 'application/json'},
            body: jsonEncode(payload),
          )
          .timeout(_timeout);

      if (response.statusCode != 200) {
        return null;
      }

      final decoded = jsonDecode(response.body);
      if (decoded is Map<String, dynamic>) {
        return decoded;
      }

      return null;
    } on TimeoutException {
      return null;
    } catch (_) {
      return null;
    }
  }

  void dispose() {
    if (_disposeClientOnClose) {
      _httpClient.close();
    }
  }
}
