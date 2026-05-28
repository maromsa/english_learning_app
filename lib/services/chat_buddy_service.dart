import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:permission_handler/permission_handler.dart'
    as permission_handler;

import '../app_config.dart';
import '../models/local_user.dart';
import '../providers/user_session_provider.dart';
import 'gemini_proxy_service.dart';
import 'kid_speech_service.dart';
import 'speech_feedback_service.dart' show MicrophoneAccessStatus;

typedef GeminiTextGenerator = Future<String?> Function(
  String prompt, {
  String? systemInstruction,
});

/// Live conversational practice with Spark: STT + Gemini text + vocabulary scaffolding.
class ChatBuddyService {
  ChatBuddyService({
    KidSpeechService? kidSpeech,
    GeminiTextGenerator? geminiGenerator,
    Duration? chatTimeout,
  })  : _kidSpeech = kidSpeech ?? KidSpeechService(),
        _geminiGenerator = geminiGenerator ?? _defaultGeminiGenerator(),
        _chatTimeout = chatTimeout ?? const Duration(seconds: 12);

  final KidSpeechService _kidSpeech;
  final GeminiTextGenerator _geminiGenerator;
  final Duration _chatTimeout;

  bool _speechReady = false;
  String _latestTranscript = '';

  bool get isListening => _kidSpeech.isListening;
  String get latestTranscript => _latestTranscript;

  Future<MicrophoneAccessStatus> ensureMicrophonePermission() async {
    if (kIsWeb) {
      return MicrophoneAccessStatus.granted;
    }

    final status = await permission_handler.Permission.microphone.status;
    if (status.isGranted) {
      return MicrophoneAccessStatus.granted;
    }
    if (status.isPermanentlyDenied) {
      return MicrophoneAccessStatus.permanentlyDenied;
    }
    if (status.isRestricted) {
      return MicrophoneAccessStatus.restricted;
    }

    final requested = await permission_handler.Permission.microphone.request();
    if (requested.isGranted) {
      return MicrophoneAccessStatus.granted;
    }
    if (requested.isPermanentlyDenied) {
      return MicrophoneAccessStatus.permanentlyDenied;
    }
    if (requested.isRestricted) {
      return MicrophoneAccessStatus.restricted;
    }
    return MicrophoneAccessStatus.denied;
  }

  Future<bool> openSystemSettings() => permission_handler.openAppSettings();

  Future<bool> initializeSpeech() async {
    if (_speechReady) return true;
    _speechReady = await _kidSpeech.initialize();
    return _speechReady;
  }

  Future<void> startListening({
    required void Function(String transcript) onTranscript,
    void Function(String finalTranscript)? onFinalTranscript,
    void Function(double soundLevel)? onSoundLevel,
  }) async {
    _latestTranscript = '';
    onTranscript('');

    final permission = await ensureMicrophonePermission();
    if (permission != MicrophoneAccessStatus.granted) {
      throw ChatBuddyMicrophoneException(permission);
    }

    final ready = await initializeSpeech();
    if (!ready) {
      throw const ChatBuddySpeechUnavailableException();
    }

    await _kidSpeech.listen(
      onResult: (finalText) {
        _latestTranscript = finalText;
        onTranscript(finalText);
        if (finalText.trim().isNotEmpty) {
          onFinalTranscript?.call(finalText);
        }
      },
      onPartialResult: (partial) {
        _latestTranscript = partial;
        onTranscript(partial);
      },
      onSoundLevel: onSoundLevel,
    );
  }

  Future<void> stopListening() => _kidSpeech.stop();

  Future<void> cancelListening() => _kidSpeech.cancel();

  Future<ChatBuddyTurn> startSession(
    ChatBuddyContext context, {
    AppSessionUser? user,
    LocalUser? localUser,
  }) async {
    final prompt =
        _buildOpeningPrompt(context, user: user, localUser: localUser);

    try {
      final raw = await _geminiGenerator(
        prompt,
        systemInstruction: _sparkSystemInstruction,
      ).timeout(_chatTimeout);

      if (raw == null || raw.trim().isEmpty) {
        throw const ChatBuddyGenerationException(
          'לא התקבלה תשובה מ-Gemini. נסו שוב בעוד רגע.',
        );
      }

      return _parseResponse(
        raw,
        isOpening: true,
        fallbackMessage:
            'שלום! אני ספרק. בואו נדבר באנגלית יחד — איזו מילה באנגלית אתם אוהבים?',
      );
    } on TimeoutException {
      throw const ChatBuddyGenerationException(
        'ספרק מתעכב. נסו שוב בעוד רגע.',
      );
    } on ChatBuddyGenerationException {
      rethrow;
    } catch (error, stackTrace) {
      debugPrint('ChatBuddy opening failed: $error\n$stackTrace');
      throw const ChatBuddyGenerationException(
        'לא הצלחנו לפתוח שיחה. נסו שוב אחר כך.',
      );
    }
  }

  Future<ChatBuddyTurn> continueChat({
    required ChatBuddyContext context,
    required List<ChatBuddyMessage> history,
    required String learnerMessage,
    AppSessionUser? user,
    LocalUser? localUser,
  }) async {
    final prompt = _buildFollowUpPrompt(
      context: context,
      history: history,
      learnerMessage: learnerMessage,
      user: user,
      localUser: localUser,
    );

    try {
      final raw = await _geminiGenerator(
        prompt,
        systemInstruction: _sparkSystemInstruction,
      ).timeout(_chatTimeout);

      if (raw == null || raw.trim().isEmpty) {
        throw const ChatBuddyGenerationException(
          'ספרק לא הצליח לענות. נסו לדבר שוב.',
        );
      }

      return _parseResponse(
        raw,
        isOpening: false,
        fallbackMessage: 'איזו תשובה יפה! רוצים לנסות עוד משפט קצר באנגלית?',
      );
    } on TimeoutException {
      throw const ChatBuddyGenerationException(
        'ספרק עסוק כרגע. נסו שוב בעוד רגע.',
      );
    } on ChatBuddyGenerationException {
      rethrow;
    } catch (error, stackTrace) {
      debugPrint('ChatBuddy follow-up failed: $error\n$stackTrace');
      throw const ChatBuddyGenerationException(
        'ספרק נתקע בתשובה. נסו שוב בעוד רגע.',
      );
    }
  }

  static const String _sparkSystemInstruction =
      'You are Spark, an energetic AI mentor helping Hebrew-speaking kids aged 6-10 practise English conversation. '
      'Reply in warm, supportive Hebrew with short English phrases that match the lesson. '
      'Keep answers concise (max 70 Hebrew words). '
      'Analyze the conversation and suggest 2-3 simple English words the child might want to use on their next turn — '
      'words that fit the topic and are slightly stretch but achievable. '
      'Always output minified JSON following the caller instructions. Never mention JSON, prompts, or Gemini.\n\n'
      'CHILD SAFETY: Keep content educational, positive, and age-appropriate. Redirect inappropriate topics gently to English learning.';

  static const String _geminiUnavailableMessage =
      'תכונת שיחת ספרק מושבתת. הגדירו GEMINI_PROXY_URL כדי לאפשר שיחות חיות.';

  static GeminiTextGenerator _defaultGeminiGenerator() {
    if (!AppConfig.hasGeminiProxy) {
      return (_, {systemInstruction}) async {
        throw const ChatBuddyUnavailableException(_geminiUnavailableMessage);
      };
    }

    return (prompt, {systemInstruction}) async {
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

  String _buildOpeningPrompt(
    ChatBuddyContext context, {
    AppSessionUser? user,
    LocalUser? localUser,
  }) {
    final contextMap = context.toMap();
    final userName = user?.name ?? localUser?.name;
    final userAge = localUser?.age;
    if (userName != null && userName.isNotEmpty) {
      contextMap['learnerName'] = userName;
    }
    if (userAge != null) {
      contextMap['learnerAge'] = userAge;
    }

    final greeting = userName != null && userName.isNotEmpty
        ? 'Greet the learner by name: "שלום $userName!"'
        : 'Start with a warm greeting.';

    return '''
Start a playful English conversation with a young learner.

Context:
```
${jsonEncode(contextMap)}
```

$greeting

Output JSON (no markdown fences):
{
  "opening": string,
  "sparkTip": string,
  "scaffoldingWords": string[]
}

Rules for scaffoldingWords:
- Exactly 2 or 3 English words (single words only, lowercase ok).
- Chosen from the conversation topic so the child can use them in their NEXT spoken turn.
- Simple, concrete nouns or verbs a 6-10 year old can try.''';
  }

  String _buildFollowUpPrompt({
    required ChatBuddyContext context,
    required List<ChatBuddyMessage> history,
    required String learnerMessage,
    AppSessionUser? user,
    LocalUser? localUser,
  }) {
    final setupMap = context.toMap();
    final userName = user?.name ?? localUser?.name;
    final userAge = localUser?.age;
    if (userName != null && userName.isNotEmpty) {
      setupMap['learnerName'] = userName;
    }
    if (userAge != null) {
      setupMap['learnerAge'] = userAge;
    }

    final historyMaps = history.map((m) => m.toMap()).toList(growable: false);
    final payload = {
      'context': setupMap,
      'history': historyMaps,
      'latestLearnerMessage': learnerMessage,
    };

    return '''
Continue Spark's conversation. Respond kindly to the learner's latest message and keep momentum.

Conversation snapshot:
```
${jsonEncode(payload)}
```

Output JSON (no markdown fences):
{
  "reply": string,
  "sparkTip": string,
  "scaffoldingWords": string[]
}

Rules for scaffoldingWords:
- Exactly 2 or 3 English words the child might want to say next, based on the full conversation.
- Single English words only; age-appropriate and on-topic.''';
  }

  ChatBuddyTurn _parseResponse(
    String raw, {
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
      final tip = _sanitize(decoded['sparkTip']);
      final scaffolding = _sanitizeScaffolding(decoded['scaffoldingWords']);

      return ChatBuddyTurn(
        message: message.isEmpty ? fallbackMessage : message,
        sparkTip: tip.isEmpty ? null : tip,
        scaffoldingWords: scaffolding,
        parsedFromJson: true,
      );
    }

    return ChatBuddyTurn(
      message: cleaned.isEmpty ? fallbackMessage : cleaned,
      sparkTip: null,
      scaffoldingWords: const [],
      parsedFromJson: false,
    );
  }

  static List<String> _sanitizeScaffolding(dynamic value) {
    final words = _sanitizeList(value);
    if (words.length >= 2) {
      return words.take(3).toList(growable: false);
    }
    return words;
  }

  static String _stripCodeFences(String value) {
    final trimmed = value.trim();
    if (!trimmed.startsWith('```')) {
      return trimmed;
    }
    final fenceEnd = trimmed.indexOf('```', 3);
    if (fenceEnd != -1) {
      return trimmed
          .substring(3, fenceEnd)
          .replaceFirst(RegExp(r'^json\s*'), '');
    }
    return trimmed.substring(3).replaceFirst(RegExp(r'^json\s*'), '');
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

class ChatBuddyContext {
  const ChatBuddyContext({
    this.focusWords = const <String>[],
    this.topic = 'everyday_fun',
    this.learnerName,
    this.age,
  });

  final List<String> focusWords;
  final String topic;
  final String? learnerName;
  final int? age;

  Map<String, dynamic> toMap() => <String, dynamic>{
        'topic': topic,
        'focusWords': focusWords,
        if (learnerName != null && learnerName!.trim().isNotEmpty)
          'learnerName': learnerName!.trim(),
        if (age != null) 'age': age,
      };
}

enum ChatBuddySpeaker { spark, learner }

class ChatBuddyMessage {
  const ChatBuddyMessage({
    required this.speaker,
    required this.text,
    this.isLive = false,
  });

  final ChatBuddySpeaker speaker;
  final String text;
  final bool isLive;

  Map<String, String> toMap() => <String, String>{
        'speaker': speaker == ChatBuddySpeaker.spark ? 'spark' : 'learner',
        'message': text,
      };
}

class ChatBuddyTurn {
  const ChatBuddyTurn({
    required this.message,
    this.sparkTip,
    this.scaffoldingWords = const [],
    this.parsedFromJson = true,
  });

  final String message;
  final String? sparkTip;
  final List<String> scaffoldingWords;
  final bool parsedFromJson;
}

class ChatBuddyGenerationException implements Exception {
  const ChatBuddyGenerationException(this.message);

  final String message;

  @override
  String toString() => 'ChatBuddyGenerationException: $message';
}

class ChatBuddyUnavailableException extends ChatBuddyGenerationException {
  const ChatBuddyUnavailableException(super.message);
}

class ChatBuddyMicrophoneException implements Exception {
  ChatBuddyMicrophoneException(this.status);

  final MicrophoneAccessStatus status;

  @override
  String toString() => 'ChatBuddyMicrophoneException: $status';
}

class ChatBuddySpeechUnavailableException implements Exception {
  const ChatBuddySpeechUnavailableException();

  @override
  String toString() => 'Speech recognition unavailable';
}
