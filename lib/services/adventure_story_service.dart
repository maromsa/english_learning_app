import 'dart:async';
import 'dart:convert';

import 'package:google_generative_ai/google_generative_ai.dart';

import '../app_config.dart';

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

  Future<AdventureStory> generateAdventure(AdventureStoryContext context) async {
    final generator = _generator;
    if (generator == null) {
      if (_allowStub) {
        return _generateStubStory(context);
      }
      throw const AdventureStoryUnavailableException(
        'Gemini API key is missing. Provide GEMINI_API_KEY via --dart-define or enable the offline stub.',
      );
    }

    final prompt = _buildPrompt(context);

    try {
      final raw = await generator(prompt).timeout(_timeout);
      if (raw == null || raw.trim().isEmpty) {
        throw const AdventureStoryGenerationException('Received empty response from Gemini.');
      }
      return _parseResponse(raw, prompt: prompt);
    } on TimeoutException {
      throw const AdventureStoryGenerationException('Gemini took too long to craft a story. Please try again.');
    } on AdventureStoryGenerationException {
      rethrow;
    } catch (error) {
      throw AdventureStoryGenerationException('Unable to generate adventure story: $error');
    }
  }

  static GeminiTextGenerator? _inferGenerator(GenerativeModel? providedModel) {
    if (!AppConfig.hasGemini && providedModel == null) {
      return null;
    }

    final model = providedModel ?? GenerativeModel(
      model: 'gemini-1.5-flash',
      apiKey: AppConfig.geminiApiKey,
      systemInstruction: Content.text(
        'You are Spark, a playful mentor guiding 5-8 year olds through English adventures. '
        'Keep language positive, simple, and imaginative. Always respect the JSON schema instructions.',
      ),
    );

    return (prompt) async {
      final response = await model.generateContent([Content.text(prompt)]);
      return response.text;
    };
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
      title: 'Spark\'s Surprise Quest',
      scene: cleaned,
      challenge: 'Act out the adventure and use the new words you discovered!',
      encouragement: 'You are amazing! Let\'s keep the curiosity glowing!',
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
    final friendlyWords = words.isEmpty ? 'new English words' : words.join(', ');
    final title = "Spark's ${context.levelName} Quest";
    final playerName = context.playerName?.trim();
    final player = (playerName != null && playerName.isNotEmpty) ? playerName : 'friend';

    final scene =
        'Spark zooms into ${context.levelName} with you, $player! Together you explore a ${context.mood} adventure where ${friendlyWords.toLowerCase()} twinkle in the air. Spark points out clues that help you practice each word with smiles and movement.';
    final challenge =
        'Say each vocabulary word with Spark, then act it out. Can you use one word in a sentence about ${context.levelName}?';
    final encouragement =
        'Brilliant energy! Spark loves how you keep trying. Let the stars you earned guide the next quest!';

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
