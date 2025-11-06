import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:google_generative_ai/google_generative_ai.dart';

import '../app_config.dart';
import 'gemini_api_key_resolver.dart';

typedef GeminiTextGenerator = Future<String?> Function(String prompt);

class AdventureStoryService {
  AdventureStoryService({
    GeminiTextGenerator? generator,
    Duration? timeout,
    GenerativeModel? model,
    bool? enableStub,
  })  : _timeout = timeout ?? const Duration(seconds: 12),
        _generator = generator ?? _inferGenerator(model),
        _allowStub = enableStub ?? AppConfig.hasGeminiStub;

  final GeminiTextGenerator? _generator;
  final Duration _timeout;
  final bool _allowStub;
  static Future<GenerativeModel?>? _defaultModelFuture;
  static const String _storySystemInstruction =
      'You are Spark, a playful mentor guiding 5-8 year olds through English adventures. '
      'Speak in simple, upbeat Hebrew so young native Hebrew speakers feel at home, '
      'but keep every English vocabulary word exactly as provided. '
      'Always respect the JSON schema instructions.';

  Future<AdventureStory> generateAdventure(AdventureStoryContext context) async {
    final generator = _generator;
    if (generator == null) {
      if (_allowStub) {
        return _generateStubStory(context);
      }
        throw const AdventureStoryUnavailableException(
          'חסר מפתח Gemini. הוסיפו GEMINI_API_KEY באמצעות --dart-define או הפעילו את מצב הדמה (stub).',
        );
    }

    final prompt = _buildPrompt(context);

    try {
      final raw = await generator(prompt).timeout(_timeout);
      if (raw == null || raw.trim().isEmpty) {
        throw const AdventureStoryGenerationException('לא התקבלה תשובה מ-Gemini. נסו שוב בעוד רגע.');
      }
      return _parseResponse(raw, prompt: prompt);
    } on TimeoutException {
      throw const AdventureStoryGenerationException('נראה ש-Gemini מתעכב. נסו שוב בעוד רגע.');
    } on AdventureStoryGenerationException {
      rethrow;
    } catch (error, stackTrace) {
      debugPrint('Adventure story generation failed: $error\n$stackTrace');
      throw const AdventureStoryGenerationException('לא הצלחנו ליצור סיפור חדש. נסו שוב בעוד רגע.');
    }
  }

  static GeminiTextGenerator? _inferGenerator(GenerativeModel? providedModel) {
    if (!AppConfig.hasGemini && providedModel == null) {
      return null;
    }

    return (prompt) async {
      final GenerativeModel? model = providedModel ?? await _loadDefaultModel();
      if (model == null) {
        throw const AdventureStoryUnavailableException(
          'לא הצלחנו לטעון את מפתח Gemini מהגדרות GitHub. ודאו שהסוד קיים ונגיש.',
        );
      }

      final response = await model.generateContent([Content.text(prompt)]);
      return response.text;
    };
  }

  static Future<GenerativeModel?> _loadDefaultModel() {
    final pending = _defaultModelFuture;
    if (pending != null) {
      return pending;
    }

    final completer = Completer<GenerativeModel?>();
    _defaultModelFuture = completer.future;

    () async {
      try {
        final key = await GeminiApiKeyResolver.resolve();
        if (key.isEmpty) {
          _defaultModelFuture = null;
          completer.complete(null);
          return;
        }

        final model = GenerativeModel(
          model: 'gemini-1.5-flash',
          apiKey: key,
          systemInstruction: Content.text(_storySystemInstruction),
        );

        completer.complete(model);
      } catch (error, stackTrace) {
        _defaultModelFuture = null;
        completer.completeError(error, stackTrace);
      }
    }();

    return completer.future;
  }

  String _buildPrompt(AdventureStoryContext context) {
    final contextJson = jsonEncode(context.toMap());
    return '''Craft a playful mini-quest for a child learning English. The audience is 5-8 years old.

Use the supplied JSON context to personalize the story:
```
$contextJson
```

Requirements:
- The mentor persona is "Spark" who speaks in encouraging, friendly sentences.
- Keep the entire response between 90 and 160 words.
- Use some of the vocabulary words naturally in the narrative.
- Include a simple interactive challenge that can be acted out or spoken.
- Never mention JSON, prompts, or being an AI.
- Write all narrative, challenge, and encouragement text in Hebrew so it feels local, while showing each vocabulary word in English inside the sentences.

Return the result as minified JSON with keys:
{
  "title": string,
  "scene": string,
  "challenge": string,
  "encouragement": string,
  "vocabulary": string[]
}

Do not include markdown code fences around the JSON.''';
  }

  AdventureStory _parseResponse(String raw, {required String prompt}) {
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
      return AdventureStory.fromJson(decoded, rawText: cleaned, prompt: prompt);
    }

    return AdventureStory(
      title: 'הפתעת ספרק',
      scene: cleaned,
      challenge: 'הציגו את ההרפתקה ושבצו את המילים החדשות שלמדתם.',
      encouragement: 'אתם נהדרים! ספרק מתרגש לראות אתכם ממשיכים לחקור וללמוד.',
      vocabulary: const [],
      rawText: cleaned,
      prompt: prompt,
      parsedFromJson: false,
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

  Future<AdventureStory> _generateStubStory(AdventureStoryContext context) async {
    final words = List<String>.from(context.vocabularyWords);
    final friendlyWords = words.isEmpty ? 'מילים חדשות באנגלית' : words.join(', ');
    final title = 'המשימה של ספרק ב${context.levelName}';
    final playerName = context.playerName?.trim();
    final player = (playerName != null && playerName.isNotEmpty) ? playerName : 'חבר/ה';
    final moodDescription = _describeMood(context.mood);

    final scene =
        'ספרק טס אל ${context.levelName} יחד עם $player! אתם יוצאים להרפתקה בסגנון $moodDescription, והמילים $friendlyWords מאירות את הדרך באנגלית. ספרק מצביע על רמזים שיעזרו לכם לתרגל כל מילה עם חיוך ותנועה.';
    final challenge =
        'אמרו כל מילה באנגלית יחד עם ספרק ואז הציגו אותה בתנועה קטנה. האם תוכלו לחבר משפט אחד שמתאר את ${context.levelName}?';
    final encouragement =
        'איזו אנרגיה מבריקה! ספרק אוהב לראות איך אתם ממשיכים לנסות. הכוכבים שצברתם יובילו אתכם להרפתקה הבאה.';

    return AdventureStory(
      title: title,
      scene: scene,
      challenge: challenge,
      encouragement: encouragement,
      vocabulary: words,
      rawText: scene,
      prompt: 'stub',
      parsedFromJson: true,
    );
  }

  String _describeMood(String mood) {
    switch (mood) {
      case 'brave explorer':
        return 'של חוקר אמיץ';
      case 'curious scientist':
        return 'של מדען סקרן';
      case 'kind helper':
        return 'של עוזר טוב לב';
      case 'silly comedian':
        return 'מצחיקה ומלאת צחוק';
      default:
        return mood;
    }
  }
}

class AdventureStoryContext {
  const AdventureStoryContext({
    required this.levelName,
    required this.levelDescription,
    required this.vocabularyWords,
    required this.levelStars,
    required this.totalStars,
    required this.coins,
    required this.mood,
    this.playerName,
  });

  final String levelName;
  final String levelDescription;
  final List<String> vocabularyWords;
  final int levelStars;
  final int totalStars;
  final int coins;
  final String mood;
  final String? playerName;

  Map<String, dynamic> toMap() => <String, dynamic>{
        'levelName': levelName,
        'levelDescription': levelDescription,
        'vocabularyWords': vocabularyWords,
        'levelStars': levelStars,
        'totalStars': totalStars,
        'coins': coins,
        'mood': mood,
        if (playerName != null && playerName!.trim().isNotEmpty)
          'playerName': playerName!.trim(),
      };
}

class AdventureStory {
  AdventureStory({
    required this.title,
    required this.scene,
    required this.challenge,
    required this.encouragement,
    required this.vocabulary,
    required this.rawText,
    required this.prompt,
    this.parsedFromJson = true,
  });

  factory AdventureStory.fromJson(Map<String, dynamic> json, {required String rawText, required String prompt}) {
    final vocabulary = (json['vocabulary'] as List?)
            ?.whereType<String>()
            .map((word) => word.trim())
            .where((word) => word.isNotEmpty)
            .toList(growable: false) ??
        const <String>[];

    return AdventureStory(
      title: _sanitize(json['title']),
      scene: _sanitize(json['scene']),
      challenge: _sanitize(json['challenge']),
      encouragement: _sanitize(json['encouragement']),
      vocabulary: vocabulary,
      rawText: rawText,
      prompt: prompt,
    );
  }

  final String title;
  final String scene;
  final String challenge;
  final String encouragement;
  final List<String> vocabulary;
  final String rawText;
  final String prompt;
  final bool parsedFromJson;

  static String _sanitize(dynamic value) {
    if (value is String) {
      return value.trim();
    }
    return '';
  }
}

class AdventureStoryGenerationException implements Exception {
  const AdventureStoryGenerationException(this.message);

  final String message;

  @override
  String toString() => 'AdventureStoryGenerationException: $message';
}

class AdventureStoryUnavailableException extends AdventureStoryGenerationException {
  const AdventureStoryUnavailableException(String message) : super(message);
}
