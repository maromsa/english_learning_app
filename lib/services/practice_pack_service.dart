import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';

import '../app_config.dart';
import 'gemini_proxy_service.dart';

typedef _PracticePackGenerator = Future<String?> Function(String prompt);

class PracticePackService {
  PracticePackService({
    Duration? timeout,
    _PracticePackGenerator? generator,
  })  : _timeout = timeout ?? const Duration(seconds: 12),
        _generator = generator ?? _inferGenerator();

  final _PracticePackGenerator _generator;
  final Duration _timeout;

  Future<PracticePack> generatePack(PracticePackRequest request) async {
    final prompt = _buildPrompt(request);

    try {
      final raw = await _generator(prompt).timeout(_timeout);
      if (raw == null || raw.trim().isEmpty) {
        throw const PracticePackGenerationException('לא התקבלה תשובה מ-Gemini. נסו שוב עוד רגע.');
      }
      return _parseResponse(raw, prompt: prompt, fallback: _stubFallback(request));
    } on TimeoutException {
      throw const PracticePackGenerationException('נראה ש-Gemini מתעכב. נסו שוב עוד רגע.');
    } on PracticePackGenerationException {
      rethrow;
    } catch (error, stackTrace) {
      debugPrint('Practice pack generation failed: $error\n$stackTrace');
      throw const PracticePackGenerationException('ספרק לא הצליח לבנות פעילות חדשה. נסו שוב עוד מעט.');
    }
  }

  static const String _sparkSystemInstruction =
      'You are Spark, an upbeat AI mentor helping Hebrew-speaking kids practise English. '
      'You design playful activities that mix Hebrew guidance with English words and phrases the child should try. '
      'Keep instructions short, energetic, and friendly. Always return compact JSON as instructed by the prompt.';

  static const String _geminiUnavailableMessage =
      'חבילת האימון של ספרק דורשת חיבור ל-Gemini. הגדירו GEMINI_PROXY_URL שמפנה לפונקציית הענן כדי להפעיל את התכונה.';

  static _PracticePackGenerator _inferGenerator() {
    Uri? proxyEndpoint;
    try {
      proxyEndpoint = AppConfig.geminiProxyEndpoint;
    } catch (Object error, StackTrace stackTrace) {
      final isDotEnvNotInitialized = error.runtimeType.toString() == 'NotInitializedError';
      if (!isDotEnvNotInitialized) {
        Error.throwWithStackTrace(error, stackTrace);
      }
      debugPrint(
        'PracticePackService: Gemini proxy secrets not initialised – falling back to stub generator. ($error)',
      );
      proxyEndpoint = null;
    }

    if (proxyEndpoint == null) {
      return (_) async {
        throw const PracticePackUnavailableException(_geminiUnavailableMessage);
      };
    }

    return (prompt) async {
      final service = GeminiProxyService(proxyEndpoint);
      try {
        final response = await service.generateText(
          prompt,
          systemInstruction: _sparkSystemInstruction,
        );
        if (response == null || response.trim().isEmpty) {
          throw const PracticePackUnavailableException(_geminiUnavailableMessage);
        }
        return response;
      } finally {
        service.dispose();
      }
    };
  }

  String _buildPrompt(PracticePackRequest request) {
    final jsonContext = jsonEncode(request.toMap());
    return '''
Craft a three-part micro practice plan for a young learner using the JSON context.

Context:
```
$jsonContext
```

Rules:
- Audience: Hebrew-speaking child aged 6-10 learning English.
- Blend Hebrew instructions with inline English words.
- Keep each activity under 80 Hebrew words.
- Include active movement or gestures when the energy level is high.
- Mention only the supplied focus words or closely related beginner vocabulary.

Respond with minified JSON (no markdown fences):
{
  "pepTalk": string,          // Spark's motivational intro in Hebrew with 1-2 English phrases
  "celebration": string,      // Short celebration emoji or chant (<= 12 characters)
  "activities": [
    {
      "title": string,        // Name of the activity in Hebrew
      "goal": string,         // Learning goal in Hebrew (<= 18 words)
      "steps": string[],      // 3-4 numbered steps, Hebrew text with target English words inside
      "englishFocus": string[], // 2-4 English words to practise
      "boost": string         // Extra challenge or cooperation idea (<= 20 words)
    },
    ...
  ]
}

Ensure exactly three activities are returned.''';
  }

  PracticePack _parseResponse(
    String raw, {
    required String prompt,
    required PracticePack fallback,
  }) {
    final cleaned = _stripCodeFences(raw).trim();
    Map<String, dynamic>? decoded;
    if (cleaned.isNotEmpty) {
      try {
        decoded = jsonDecode(cleaned) as Map<String, dynamic>;
      } catch (_) {
        decoded = null;
      }
    }

    if (decoded != null) {
      try {
        final activities = (decoded['activities'] as List?)
                ?.map((item) => PracticeActivity.fromJson(item as Map<String, dynamic>))
                .where((activity) => activity.steps.isNotEmpty)
                .take(3)
                .toList(growable: false) ??
            const <PracticeActivity>[];

        if (activities.isEmpty) {
          throw const FormatException('Empty activities');
        }

        final pepTalk = _sanitize(decoded['pepTalk']);
        final celebration = _sanitize(decoded['celebration']);

        return PracticePack(
          pepTalk: pepTalk.isEmpty ? fallback.pepTalk : pepTalk,
          celebration: celebration.isEmpty ? fallback.celebration : celebration,
          activities: activities,
          rawText: cleaned,
          prompt: prompt,
          parsedFromJson: true,
        );
      } catch (error) {
        debugPrint('Failed to parse practice pack JSON: $error');
      }
    }

    return fallback.copyWith(
      rawText: cleaned.isEmpty ? fallback.rawText : cleaned,
      prompt: prompt,
      parsedFromJson: decoded != null,
    );
  }

  PracticePack _stubFallback(PracticePackRequest request) {
    return _stubPack(request, raw: 'stub');
  }

  PracticePack _stubPack(PracticePackRequest request, {String raw = 'stub'}) {
    final focusWords = request.focusWords.isEmpty ? ['hello', 'friends', 'magic'] : request.focusWords.take(3).toList();
    final energy = request.energyLevelDescription();
    final pepTalk =
        'היי! ספרק כאן. היום נעשה אימון ${request.skillFocusDescription()} עם מצב רוח $energy. ביחד נאמר ${focusWords.join(', ')} באנגלית עם חיוך!';

    return PracticePack(
      pepTalk: pepTalk,
      celebration: '🎉',
      activities: [
        PracticeActivity(
          title: 'פתיחת תנועות באנגלית',
          goal: 'לחמם את הפה והגוף עם מילים באנגלית',
          steps: [
            'קופצים במקום ואומרים Hello לכל הכיוון.',
            'עושים High-five דמיוני ואומרים My friend!',
            'מסיימים בסיבוב עם המשפט I am ready!',
          ],
          englishFocus: focusWords,
          boost: 'הוסיפו תנועה משלכם לכל משפט.',
        ),
        PracticeActivity(
          title: 'מסלול אוצר מילים',
          goal: 'להשתמש במילים באנגלית במשפטים קצרים',
          steps: [
            'מצביעים על חפץ בחדר ואומרים This is my ${focusWords.first}.',
            'מדמיינים חבר מצטרף ואומרים Come with me, friend!',
            'מספרים איפה האוצר מסתתר: It is under the chair.',
          ],
          englishFocus: focusWords,
          boost: 'צלמו את המשפט האחרון שלכם ושלחו לספרק.',
        ),
        PracticeActivity(
          title: 'שיר עידוד באנגלית',
          goal: 'לאלתר שיר קצר עם המילים החדשות',
          steps: [
            'מוחאים כפיים לקצב ואומרים Magic! Magic! Magic!',
            'שרים משפט: We can fly to the moon!',
            'מסיימים בקריאת עידוד: Go team English!',
          ],
          englishFocus: focusWords,
          boost: 'המציאו תנועה לכל מילה בשיר.',
        ),
      ],
      rawText: raw,
      prompt: 'stub',
      parsedFromJson: true,
    );
  }

  String _stripCodeFences(String value) {
    final trimmed = value.trim();
    if (trimmed.startsWith('```')) {
      final fenceEnd = trimmed.indexOf('```', 3);
      if (fenceEnd != -1) {
        return trimmed.substring(3, fenceEnd).replaceFirst(RegExp(r'^json\s*'), '');
      }
      return trimmed.substring(3).replaceFirst(RegExp(r'^json\s*'), '');
    }
    return trimmed;
  }

  static String _sanitize(dynamic value) {
    if (value is String) {
      return value.trim();
    }
    return '';
  }
}

class PracticePackRequest {
  const PracticePackRequest({
    required this.skillFocus,
    required this.timeAvailable,
    required this.energyLevel,
    required this.playMode,
    this.focusWords = const <String>[],
    this.learnerName,
  });

  final String skillFocus;
  final String timeAvailable;
  final String energyLevel;
  final String playMode;
  final List<String> focusWords;
  final String? learnerName;

  Map<String, dynamic> toMap() => <String, dynamic>{
        'skillFocus': skillFocus,
        'timeAvailable': timeAvailable,
        'energyLevel': energyLevel,
        'playMode': playMode,
        'focusWords': focusWords,
        if (learnerName != null && learnerName!.trim().isNotEmpty) 'learnerName': learnerName!.trim(),
      };

  String skillFocusDescription() {
    switch (skillFocus) {
      case 'listening':
        return 'להאזנה והבנה';
      case 'speaking':
        return 'לדיבור בטוח';
      case 'storytelling':
        return 'לסיפורים יצירתיים';
      case 'movement':
        return 'למידה בתנועה';
      default:
        return 'מגוונת';
    }
  }

  String energyLevelDescription() {
    switch (energyLevel) {
      case 'calm':
        return 'רגוע';
      case 'balanced':
        return 'שמֵח ומאוזן';
      case 'hyper':
        return 'אנרגטי במיוחד';
      default:
        return 'מיוחד';
    }
  }
}

class PracticePack {
  const PracticePack({
    required this.pepTalk,
    required this.celebration,
    required this.activities,
    required this.rawText,
    required this.prompt,
    this.parsedFromJson = true,
  });

  final String pepTalk;
  final String celebration;
  final List<PracticeActivity> activities;
  final String rawText;
  final String prompt;
  final bool parsedFromJson;

  PracticePack copyWith({
    String? rawText,
    String? prompt,
    bool? parsedFromJson,
  }) {
    return PracticePack(
      pepTalk: pepTalk,
      celebration: celebration,
      activities: activities,
      rawText: rawText ?? this.rawText,
      prompt: prompt ?? this.prompt,
      parsedFromJson: parsedFromJson ?? this.parsedFromJson,
    );
  }
}

String _sanitize(dynamic value) {
  if (value is String) {
    return value.trim();
  }
  return '';
}


class PracticeActivity {
  PracticeActivity({
    required this.title,
    required this.goal,
    required this.steps,
    required this.englishFocus,
    required this.boost,
  });

  factory PracticeActivity.fromJson(Map<String, dynamic> json) {
    return PracticeActivity(
      title: _sanitize(json['title']),
      goal: _sanitize(json['goal']),
      steps: (json['steps'] as List?)
              ?.whereType<String>()
              .map((step) => step.trim())
              .where((step) => step.isNotEmpty)
              .toList(growable: false) ??
          const <String>[],
      englishFocus: (json['englishFocus'] as List?)
              ?.whereType<String>()
              .map((word) => word.trim())
              .where((word) => word.isNotEmpty)
              .toList(growable: false) ??
          const <String>[],
      boost: _sanitize(json['boost']),
    );
  }

  final String title;
  final String goal;
  final List<String> steps;
  final List<String> englishFocus;
  final String boost;
}

class PracticePackGenerationException implements Exception {
  const PracticePackGenerationException(this.message);

  final String message;

  @override
  String toString() => 'PracticePackGenerationException: $message';
}

class PracticePackUnavailableException extends PracticePackGenerationException {
  const PracticePackUnavailableException(String message) : super(message);
}
