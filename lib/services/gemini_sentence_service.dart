import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';

import '../app_config.dart';
import '../models/sentence_question.dart';
import 'gemini_proxy_service.dart';

/// Generates extra fill-in-the-blank sentences via the authenticated Gemini
/// proxy. The Gemini API key never ships in the client.
///
/// Failures (timeout, empty/malformed JSON, proxy down) return an empty list
/// so the offline catalog keeps the learning loop working.
class GeminiSentenceService {
  GeminiSentenceService({
    GeminiTextGenerator? generator,
    Duration timeout = const Duration(seconds: 12),
  })  : _generator = generator ?? _defaultGenerator(),
        _timeout = timeout;

  final GeminiTextGenerator _generator;
  final Duration _timeout;

  static const int defaultCount = 3;
  static const int minCount = 1;
  static const int maxCount = 8;

  /// Asks Spark for [count] new playable sentences, skipping [avoid].
  Future<List<SentenceQuestion>> generateSentences({
    int count = defaultCount,
    List<String> avoid = const [],
  }) async {
    final clamped = count.clamp(minCount, maxCount);
    try {
      final raw = await _generator(
        buildPrompt(count: clamped, avoid: avoid),
        systemInstruction: systemInstruction,
      ).timeout(_timeout);
      if (raw == null || raw.trim().isEmpty) return const [];
      return parseResponse(raw, count: clamped);
    } on TimeoutException {
      debugPrint('GeminiSentenceService: timed out');
      return const [];
    } catch (error, stackTrace) {
      debugPrint('GeminiSentenceService failed: $error\n$stackTrace');
      return const [];
    }
  }

  /// Spark coach prompt: short, present-tense English for ages 5–10.
  static const String systemInstruction =
      'You are Spark, a warm English teacher for Hebrew-speaking children '
      'aged 5–10. Invent simple fill-in-the-blank sentences. '
      'Reply ONLY with minified JSON as instructed, no markdown. '
      'CHILD SAFETY: never include violence, fear, romance, brands, or adult topics. '
      'Keep every sentence positive and everyday.';

  static String buildPrompt({
    required int count,
    List<String> avoid = const [],
  }) {
    final avoidBlock = avoid.isEmpty
        ? ''
        : 'Do NOT repeat any of these sentences:\n'
            '${avoid.map((s) => '- $s').join('\n')}\n';
    return '''
Create $count beginner English fill-in-the-blank sentences for children.

Rules:
- One short present-tense clause (4–8 words).
- Common vocabulary (animals, food, home, school, weather, family).
- missingWord is a single word that appears in the sentence.
- options: the missing word plus 2 kid-friendly distractors of the same part of speech.
- hebrewTranslation is a short natural Hebrew translation.

$avoidBlock
Return ONLY a JSON array (no markdown fences):
[
  {
    "fullEnglishSentence": "The cat is sleeping",
    "hebrewTranslation": "החתול ישן",
    "missingWord": "cat",
    "options": ["cat", "dog", "fish"]
  }
]
''';
  }

  /// Parses a model reply into playable [SentenceQuestion]s. Never throws.
  static List<SentenceQuestion> parseResponse(
    String raw, {
    int count = defaultCount,
  }) {
    final cleaned = _stripCodeFences(raw).trim();
    if (cleaned.isEmpty) return const [];

    Object? decoded;
    try {
      decoded = jsonDecode(cleaned);
    } catch (_) {
      return const [];
    }

    final items = _asObjectList(decoded);
    if (items.isEmpty) return const [];

    final out = <SentenceQuestion>[];
    final seen = <String>{};
    for (final item in items) {
      final question = _fromMap(item);
      if (question == null || !question.isPlayable) continue;
      final key = question.fullEnglishSentence.toLowerCase();
      if (!seen.add(key)) continue;
      out.add(question);
      if (out.length >= count) break;
    }
    return out;
  }

  static List<Map<String, dynamic>> _asObjectList(Object? decoded) {
    if (decoded is List) {
      final out = <Map<String, dynamic>>[];
      for (final item in decoded) {
        final map = _asStringKeyedMap(item);
        if (map != null) out.add(map);
      }
      return out;
    }
    final map = _asStringKeyedMap(decoded);
    if (map == null) return const [];
    for (final key in const ['sentences', 'questions', 'items', 'data']) {
      final nested = map[key];
      if (nested is List) {
        return _asObjectList(nested);
      }
    }
    return [map];
  }

  static Map<String, dynamic>? _asStringKeyedMap(Object? value) {
    if (value is Map<String, dynamic>) return value;
    if (value is Map<dynamic, dynamic>) {
      return value.map(
        (key, val) => MapEntry(key.toString(), val),
      );
    }
    return null;
  }

  static SentenceQuestion? _fromMap(Map<String, dynamic> json) {
    try {
      final sentence = _readString(json, const [
        'fullEnglishSentence',
        'sentence',
        'english',
      ]);
      final hebrew = _readString(json, const [
        'hebrewTranslation',
        'hebrew',
        'translation',
      ]);
      final missing = _readString(json, const [
        'missingWord',
        'word',
        'blank',
      ]);
      final options = _readStringList(json, const [
        'options',
        'choices',
        'distractors',
      ]);
      if (sentence.isEmpty || missing.isEmpty) return null;
      return SentenceQuestion(
        fullEnglishSentence: sentence,
        hebrewTranslation: hebrew,
        missingWord: missing,
        options: options,
      );
    } catch (_) {
      return null;
    }
  }

  static String _readString(Map<String, dynamic> json, List<String> keys) {
    for (final key in keys) {
      final value = json[key];
      if (value is String && value.trim().isNotEmpty) {
        return value.trim();
      }
    }
    return '';
  }

  static List<String> _readStringList(
    Map<String, dynamic> json,
    List<String> keys,
  ) {
    for (final key in keys) {
      final raw = json[key];
      if (raw is! List) continue;
      return raw
          .whereType<Object>()
          .map((e) => e.toString().trim())
          .where((e) => e.isNotEmpty)
          .toList(growable: false);
    }
    return const [];
  }

  static String _stripCodeFences(String value) {
    final trimmed = value.trim();
    if (!trimmed.startsWith('```')) return trimmed;
    final fenceEnd = trimmed.indexOf('```', 3);
    if (fenceEnd != -1) {
      return trimmed
          .substring(3, fenceEnd)
          .replaceFirst(RegExp(r'^json\s*'), '');
    }
    return trimmed.substring(3).replaceFirst(RegExp(r'^json\s*'), '');
  }

  static GeminiTextGenerator _defaultGenerator() {
    return (prompt, {systemInstruction}) async {
      if (!AppConfig.isFirebaseConfigured) return null;
      final service = GeminiProxyService(AppConfig.geminiProxyEndpoint);
      try {
        return service.generateText(
          prompt,
          systemInstruction: systemInstruction,
        );
      } finally {
        service.dispose();
      }
    };
  }
}

typedef GeminiTextGenerator = Future<String?> Function(
  String prompt, {
  String? systemInstruction,
});
