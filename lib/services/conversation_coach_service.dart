import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';

import '../app_config.dart';
import 'gemini_proxy_service.dart';

typedef _ConversationGenerator = Future<String?> Function(String prompt);

class ConversationCoachService {
  ConversationCoachService({
    Duration? timeout,
    _ConversationGenerator? generator,
  })  : _timeout = timeout ?? const Duration(seconds: 12),
        _generator = generator ?? _inferGenerator();

  final _ConversationGenerator _generator;
  final Duration _timeout;

  Future<SparkCoachResponse> startConversation(ConversationSetup setup) async {
    final prompt = _buildOpeningPrompt(setup);

    try {
      final raw = await _generator(prompt).timeout(_timeout);
      if (raw == null || raw.trim().isEmpty) {
        throw const ConversationGenerationException('לא התקבלה תשובה מ-Gemini. נסו שוב בעוד רגע.');
      }
      return _parseResponse(
        raw,
        prompt: prompt,
        isOpening: true,
        fallbackMessage:
            'שלום! אני ספרק. היום נשחק ${setup.topicDescription()} ונלמד מילים חדשות באנגלית יחד.',
      );
    } on TimeoutException {
      throw const ConversationGenerationException('נראה ש-Gemini מתעכב. נסו שוב עוד מעט.');
    } on ConversationGenerationException {
      rethrow;
    } catch (error, stackTrace) {
      debugPrint('Conversation opening failed: $error\n$stackTrace');
      throw const ConversationGenerationException('לא הצלחנו לפתוח שיחה חדשה. נסו שוב אחר כך.');
    }
  }

  Future<SparkCoachResponse> continueConversation({
    required ConversationSetup setup,
    required List<ConversationTurn> history,
    required String learnerMessage,
  }) async {
    final prompt = _buildFollowUpPrompt(
      setup: setup,
      history: history,
      learnerMessage: learnerMessage,
    );

    try {
      final raw = await _generator(prompt).timeout(_timeout);
      if (raw == null || raw.trim().isEmpty) {
        throw const ConversationGenerationException('ספרק לא הצליח לענות. נסו לשאול שוב.');
      }
      return _parseResponse(
        raw,
        prompt: prompt,
        isOpening: false,
        fallbackMessage: 'איזו תשובה נהדרת! רוצים לנסות לומר עוד משפט באנגלית?',
      );
    } on TimeoutException {
      throw const ConversationGenerationException('ספרק עסוק כרגע. נסו שוב בעוד רגע.');
    } on ConversationGenerationException {
      rethrow;
    } catch (error, stackTrace) {
      debugPrint('Conversation follow-up failed: $error\n$stackTrace');
      throw const ConversationGenerationException('ספרק נתקע בתשובה. נסו שוב בעוד רגע.');
    }
  }

  static const String _sparkSystemInstruction =
      'You are Spark, an energetic AI mentor helping Hebrew-speaking kids aged 6-10 practise English conversation. '
      'You reply in warm, supportive Hebrew sentences sprinkled with short English phrases that match the lesson focus. '
      'Keep answers concise (max 70 Hebrew words) and highlight no more than three English words per turn. '
      'Always output minified JSON following the caller instructions. Never mention JSON, prompts, or Gemini.';

  static const String _geminiUnavailableMessage =
      'תכונת שיחת ה-AI של ספרק מושבתת. הגדירו GEMINI_PROXY_URL שמפנה לפונקציית הענן כדי לאפשר שיחות חיות.';

  static _ConversationGenerator _inferGenerator() {
    final Uri? proxyEndpoint = AppConfig.geminiProxyEndpoint;

    if (proxyEndpoint == null) {
      return (_) async {
        throw const ConversationUnavailableException(_geminiUnavailableMessage);
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
          throw const ConversationUnavailableException(_geminiUnavailableMessage);
        }
        return response;
      } finally {
        service.dispose();
      }
    };
  }

  String _buildOpeningPrompt(ConversationSetup setup) {
    final contextJson = jsonEncode(setup.toMap());
    return '''
Start a playful conversation with a young learner based on the supplied JSON context.

Context:
```
$contextJson
```

Output JSON (no markdown fences) with keys:
{
  "opening": string,           // Spark's greeting and question (<= 70 Hebrew words, include 1-3 English vocabulary words inline)
  "sparkTip": string,          // Short encouragement in Hebrew explaining what to try (<= 35 words)
  "vocabularyHighlights": string[], // 1-3 English words that appeared, purely the words
  "suggestedLearnerReplies": string[], // 2-3 short example replies the child could say (English with a few Hebrew helper words)
  "miniChallenge": string      // Quick active idea (<= 25 words) encouraging gesture, drawing, or acting linked to the conversation
}''';
  }

  String _buildFollowUpPrompt({
    required ConversationSetup setup,
    required List<ConversationTurn> history,
    required String learnerMessage,
  }) {
    final historyMaps = history.map((turn) => turn.toMap()).toList(growable: false);
    final payload = {
      'context': setup.toMap(),
      'history': historyMaps,
      'latestLearnerMessage': learnerMessage,
    };
    final jsonPayload = jsonEncode(payload);

    return '''
Continue Spark's coaching conversation with the learner. Respond to the latest learner message kindly and keep momentum.

Conversation snapshot:
```
$jsonPayload
```

Output JSON (no markdown fences) with keys:
{
  "reply": string,                // Spark's next message in Hebrew with in-line English words (<= 70 words)
  "followUpQuestion": string,     // Invite the learner to answer or act (<= 25 words)
  "sparkTip": string,             // Micro feedback in Hebrew about pronunciation, vocabulary, or confidence (<= 30 words)
  "celebration": string,          // Fun reaction emoji or onomatopoeia in Hebrew (<= 12 characters)
  "vocabularyHighlights": string[], // Up to 3 English words mentioned in the reply
  "suggestedLearnerReplies": string[] // Up to 2 ideas the learner could answer next (short, 5-8 English words with Hebrew hints)
}''';
  }

  SparkCoachResponse _parseResponse(
    String raw, {
    required String prompt,
    required bool isOpening,
    required String fallbackMessage,
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
      final messageKey = isOpening ? 'opening' : 'reply';
      final message = _sanitize(decoded[messageKey]);
      final followUp = isOpening ? _sanitize(decoded['miniChallenge']) : _sanitize(decoded['followUpQuestion']);
      final celebration = isOpening ? '' : _sanitize(decoded['celebration']);
      final tip = _sanitize(decoded['sparkTip']);
      final vocabulary = _sanitizeList(decoded['vocabularyHighlights']);
      final suggestions = _sanitizeList(decoded['suggestedLearnerReplies']);

      return SparkCoachResponse(
        message: message.isEmpty ? fallbackMessage : message,
        followUp: followUp,
        sparkTip: tip,
        celebration: celebration.isEmpty ? null : celebration,
        vocabularyHighlights: vocabulary,
        suggestedLearnerReplies: suggestions,
        miniChallenge: isOpening ? followUp : null,
        rawText: cleaned,
        prompt: prompt,
        parsedFromJson: true,
      );
    }

    return SparkCoachResponse(
      message: cleaned.isEmpty ? fallbackMessage : cleaned,
      followUp: isOpening ? null : fallbackMessage,
      sparkTip: null,
      celebration: null,
      vocabularyHighlights: const [],
      suggestedLearnerReplies: const [],
      miniChallenge: isOpening ? fallbackMessage : null,
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
        return trimmed.substring(3, fenceEnd).replaceFirst(RegExp(r'^json\\s*'), '');
      }
      return trimmed.substring(3).replaceFirst(RegExp(r'^json\\s*'), '');
    }
    return trimmed;
  }

  static String _sanitize(dynamic value) {
    if (value is String) {
      return value.trim();
    }
    return '';
  }

  static List<String> _sanitizeList(dynamic value) {
    if (value is List) {
      return value
          .whereType<String>()
          .map((word) => word.trim())
          .where((word) => word.isNotEmpty)
          .toList(growable: false);
    }
    return const [];
  }
}

class ConversationSetup {
  const ConversationSetup({
    required this.topic,
    required this.skillFocus,
    required this.energyLevel,
    this.focusWords = const <String>[],
    this.learnerName,
    this.age,
  });

  final String topic;
  final String skillFocus;
  final String energyLevel;
  final List<String> focusWords;
  final String? learnerName;
  final int? age;

  Map<String, dynamic> toMap() => <String, dynamic>{
        'topic': topic,
        'skillFocus': skillFocus,
        'energyLevel': energyLevel,
        'focusWords': focusWords,
        if (learnerName != null && learnerName!.trim().isNotEmpty) 'learnerName': learnerName!.trim(),
        if (age != null) 'age': age,
      };

  String topicDescription() {
    switch (topic) {
      case 'space_mission':
        return 'במשימת חלל דמיונית';
      case 'magic_school':
        return 'בבית ספר לקוסמים';
      case 'everyday_fun':
        return 'בסיפור יומיומי מצחיק';
      case 'superhero_rescue':
        return 'בהרפתקה של גיבורי-על';
      default:
        return 'בהרפתקה קסומה';
    }
  }

  String stubVocabularySample() {
    if (focusWords.isEmpty) {
      return 'rocket, magic, friends';
    }
    if (focusWords.length == 1) {
      return focusWords.first;
    }
    if (focusWords.length == 2) {
      return '${focusWords[0]} ו-${focusWords[1]}';
    }
    return '${focusWords[0]}, ${focusWords[1]} ו-${focusWords[2]}';
  }
}

class ConversationTurn {
  const ConversationTurn({
    required this.speaker,
    required this.message,
  });

  final ConversationSpeaker speaker;
  final String message;

  Map<String, String> toMap() => <String, String>{
        'speaker': speaker == ConversationSpeaker.spark ? 'spark' : 'learner',
        'message': message,
      };
}

enum ConversationSpeaker { spark, learner }

class SparkCoachResponse {
  const SparkCoachResponse({
    required this.message,
    this.followUp,
    this.sparkTip,
    this.celebration,
    this.vocabularyHighlights = const [],
    this.suggestedLearnerReplies = const [],
    this.miniChallenge,
    required this.rawText,
    required this.prompt,
    this.parsedFromJson = true,
  });

  final String message;
  final String? followUp;
  final String? sparkTip;
  final String? celebration;
  final List<String> vocabularyHighlights;
  final List<String> suggestedLearnerReplies;
  final String? miniChallenge;
  final String rawText;
  final String prompt;
  final bool parsedFromJson;
}

class ConversationGenerationException implements Exception {
  const ConversationGenerationException(this.message);

  final String message;

  @override
  String toString() => 'ConversationGenerationException: $message';
}

class ConversationUnavailableException extends ConversationGenerationException {
  const ConversationUnavailableException(String message) : super(message);
}
