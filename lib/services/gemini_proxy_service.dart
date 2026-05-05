import 'dart:async';
import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart' show Uint8List, debugPrint;

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
            );

  final Uri _endpoint;
  final AppHttpClient _httpClient;

  /// Asks Gemini to identify the main object in an image, returning a short
  /// natural-language description (usually a noun phrase).
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

  /// General text generation helper, used by higher-level services that
  /// provide their own system instructions.
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

  /// Scene-description mode for multimodal learning.
  ///
  /// Sends the image to Gemini with kid-safe instructions so that Spark:
  /// - Describes the scene in simple Hebrew.
  /// - Highlights 2–5 important English nouns.
  /// - Asks the learner to find or name objects in English.
  ///
  /// The Firebase Function is expected to return a JSON object with a `text`
  /// string that itself contains JSON. This method parses that inner JSON and
  /// returns a structured map, falling back to a simple `{ "description": ... }`
  /// wrapper when structured JSON is unavailable.
  Future<Map<String, dynamic>?> describeSceneAndQuizChild(
    Uint8List imageBytes, {
    String? learnerName,
    int? learnerAge,
    String mimeType = 'image/jpeg',
  }) async {
    final promptBuffer = StringBuffer()
      ..writeln(
          'You are Spark, an energetic AI guide helping Hebrew-speaking kids aged 5–10 learn English vocabulary.')
      ..writeln(
          'You see a single image that represents the child\\\'s surroundings. Describe the scene in friendly Hebrew, while gently teaching English words.')
      ..writeln()
      ..writeln('GOALS:')
      ..writeln('- Give a short, vivid description of what you see.')
      ..writeln(
          '- Highlight 2–5 important objects using their English names (single words), and explain them in simple Hebrew.')
      ..writeln(
          '- Ask the learner to find or point to specific objects and say their names in English.')
      ..writeln()
      ..writeln('OUTPUT JSON (no markdown, no extra text):')
      ..writeln('{')
      ..writeln('  "description": string,')
      ..writeln(
          '  "targetObjects": string[],        // 2–5 English nouns that appear clearly in the image')
      ..writeln(
          '  "hebrewTeachingPoints": string[], // 2–4 short Hebrew tips about how to say or remember the English words')
      ..writeln(
          '  "quizQuestions": string[],        // 2–4 short Hebrew questions asking the learner to find or name things in English')
      ..writeln(
          '  "safetyNote": string             // optional: very short note confirming the scene looks safe for a child')
      ..writeln('}');

    if (learnerName != null && learnerName.trim().isNotEmpty) {
      promptBuffer.writeln();
      promptBuffer.writeln(
          'Use the learner\\\'s name "$learnerName" once in the description or a quiz question.');
    }
    if (learnerAge != null) {
      promptBuffer.writeln(
          'Adapt explanations to a child about $learnerAge years old (keep language simple and positive).');
    }

    final response = await _postJson({
      'mode': 'scene_description',
      'prompt': promptBuffer.toString(),
      'mimeType': mimeType,
      'imageBase64': base64Encode(imageBytes),
      'system_instruction': _sceneDescriptionSystemInstruction,
    });

    if (response == null) return null;

    final text = response['text'];
    if (text is! String || text.trim().isEmpty) {
      return null;
    }

    final cleaned = _stripCodeFences(text.trim());
    try {
      final decoded = jsonDecode(cleaned);
      if (decoded is Map<String, dynamic>) {
        return decoded;
      }
    } catch (_) {
      // Fall through to simple wrapper below.
    }

    return <String, dynamic>{'description': cleaned};
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

  /// Strict child-safety and educational guardrails for scene description mode.
  static const String _sceneDescriptionSystemInstruction =
      'You are Spark, a safe and encouraging AI guide for Hebrew-speaking children aged 5–10 who are learning English vocabulary.\n'
      '\n'
      'LANGUAGE & STYLE:\n'
      '- Respond in warm, simple Hebrew.\n'
      '- When you mention English words, keep them short (usually single nouns) and easy to pronounce.\n'
      '- Be positive, playful, and encouraging at all times.\n'
      '\n'
      'EDUCATIONAL GOALS:\n'
      '- Help the learner notice objects around them and learn the English names.\n'
      '- Give clear, age-appropriate explanations in Hebrew.\n'
      '- Ask questions that invite the learner to point, look around, or say English words out loud.\n'
      '\n'
      'CHILD SAFETY (STRICT):\n'
      '- Never describe or mention violence, weapons, blood, fear, horror, adult themes, or anything not suitable for a 5–10 year old.\n'
      '- If the image appears unsafe or inappropriate, do NOT describe details. Instead, gently say the scene is not good for children and suggest looking at something friendly (like toys, books, or a room at home).\n'
      '- Keep all content light, kind, and focused on learning and curiosity.\n'
      '\n'
      'FORMATTING:\n'
      '- Always follow the caller instructions for JSON output exactly.\n'
      '- Never include markdown, code fences, or extra commentary—only the JSON object.';

  static String _stripCodeFences(String value) {
    final trimmed = value.trim();
    if (trimmed.startsWith('```')) {
      final fenceEnd = trimmed.indexOf('```', 3);
      if (fenceEnd != -1) {
        final inner = trimmed.substring(3, fenceEnd);
        return inner.replaceFirst(RegExp(r'^json\\s*', multiLine: true), '');
      }
      return trimmed
          .substring(3)
          .replaceFirst(RegExp(r'^json\\s*', multiLine: true), '');
    }
    return trimmed;
  }
}
