import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:permission_handler/permission_handler.dart'
    as permission_handler;

import '../app_config.dart';
import '../models/pronunciation_feedback.dart';
import 'gemini_proxy_service.dart';
import 'kid_speech_service.dart';

typedef GeminiTextGenerator = Future<String?> Function(
  String prompt, {
  String? systemInstruction,
});

/// Outcome of a microphone permission request.
enum MicrophoneAccessStatus {
  granted,
  denied,
  permanentlyDenied,
  restricted,
  unavailable,
}

/// Listens to the child, transcribes speech, and asks Gemini for star-rated feedback.
class SpeechFeedbackService {
  SpeechFeedbackService({
    KidSpeechService? kidSpeech,
    GeminiTextGenerator? geminiGenerator,
    Duration evaluationTimeout = const Duration(seconds: 12),
  })  : _kidSpeech = kidSpeech ?? KidSpeechService(),
        _geminiGenerator = geminiGenerator ?? _defaultGeminiGenerator(),
        _evaluationTimeout = evaluationTimeout;

  final KidSpeechService _kidSpeech;
  final GeminiTextGenerator _geminiGenerator;
  final Duration _evaluationTimeout;

  final Map<String, PronunciationFeedback> _evaluationCache = {};

  bool _speechReady = false;
  String _latestTranscript = '';

  bool get isListening => _kidSpeech.isListening;
  String get latestTranscript => _latestTranscript;

  /// Requests microphone access before starting STT.
  Future<MicrophoneAccessStatus> ensureMicrophonePermission() async {
    if (kIsWeb) {
      // Web delegates permission to the browser when listen() starts.
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

  /// Opens device settings when the user must enable the mic manually.
  Future<bool> openSystemSettings() => permission_handler.openAppSettings();

  Future<bool> initialize() async {
    if (_speechReady) return true;
    _speechReady = await _kidSpeech.initialize();
    return _speechReady;
  }

  Future<void> startListening({
    required void Function(String transcript) onTranscript,
    void Function(String finalTranscript)? onFinalTranscript,
    void Function(double soundLevel)? onSoundLevel,
    void Function(String status)? onStatus,
  }) async {
    _latestTranscript = '';
    onTranscript('');

    final permission = await ensureMicrophonePermission();
    if (permission != MicrophoneAccessStatus.granted) {
      throw MicrophonePermissionException(permission);
    }

    final ready = await initialize();
    if (!ready) {
      throw const SpeechRecognitionUnavailableException();
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
      onStatus: onStatus,
    );
  }

  Future<void> stopListening() => _kidSpeech.stop();

  Future<void> cancelListening() => _kidSpeech.cancel();

  /// Sends [targetWord] and [transcribedText] to Gemini and parses star feedback.
  Future<PronunciationFeedback> evaluatePronunciation({
    required String targetWord,
    required String transcribedText,
  }) async {
    final target = targetWord.trim();
    final heard = transcribedText.trim();

    if (heard.isEmpty) {
      return const PronunciationFeedback(
        stars: 1,
        feedbackMessage: 'לא שמעתי — בואו ננסה שוב בקול חזק יותר!',
        fromGemini: false,
      );
    }

    final cacheKey = '${target.toLowerCase()}|${heard.toLowerCase()}';
    final cached = _evaluationCache[cacheKey];
    if (cached != null) {
      return cached;
    }

    try {
      final prompt = _buildEvaluationPrompt(target, heard);
      final raw = await _geminiGenerator(
        prompt,
        systemInstruction: _sparkPronunciationSystemInstruction,
      ).timeout(_evaluationTimeout);

      if (raw == null || raw.trim().isEmpty) {
        throw StateError('Empty Gemini response');
      }

      final feedback = _parseFeedback(raw, target: target, heard: heard);
      _evaluationCache[cacheKey] = feedback;
      return feedback;
    } catch (error, stackTrace) {
      debugPrint(
          '[SpeechFeedbackService] evaluation failed: $error\n$stackTrace');
      final fallback = _localFallback(target, heard);
      return fallback;
    }
  }

  static GeminiTextGenerator _defaultGeminiGenerator() {
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

  static const String _sparkPronunciationSystemInstruction =
      'You are Spark, a warm English pronunciation coach for Hebrew-speaking children aged 5–10. '
      'Judge how close the child\\\'s spoken attempt is to the target English word, allowing typical kid mistakes '
      '(th/t, r/l, dropped endings). '
      'Reply ONLY with minified JSON: {"stars":1|2|3,"feedback_message":"..."}. '
      'feedback_message must be one short encouraging Hebrew sentence (max 12 words), no markdown. '
      'stars: 1 = needs more practice, 2 = good try / close, 3 = clear and acceptable.';

  static String _buildEvaluationPrompt(String target, String heard) {
    return '''
The child is learning English. They were asked to say the word "$target" and the speech-to-text heard "$heard".

Rate pronunciation kindness for a young learner.
Return ONLY JSON:
{"stars":1|2|3,"feedback_message":"short encouraging Hebrew sentence"}
''';
  }

  PronunciationFeedback _parseFeedback(
    String raw, {
    required String target,
    required String heard,
  }) {
    final cleaned = _stripCodeFences(raw.trim());
    try {
      final decoded = jsonDecode(cleaned);
      if (decoded is Map<String, dynamic>) {
        return PronunciationFeedback(
          stars: _clampStars(decoded['stars']),
          feedbackMessage: _sanitizeMessage(
            decoded['feedback_message'] ?? decoded['feedbackMessage'],
          ),
          fromGemini: true,
        );
      }
    } catch (_) {
      // Fall through to local fallback.
    }
    return _localFallback(target, heard);
  }

  PronunciationFeedback _localFallback(String target, String heard) {
    final close = _kidSpeech.isCloseEnough(target, heard);
    return PronunciationFeedback(
      stars: close ? 3 : 2,
      feedbackMessage: close
          ? 'כל הכבוד! הגייה מצוינת!'
          : 'כמעט! נסו שוב לאט — אתם בדרך הנכונה.',
      fromGemini: false,
    );
  }

  static int _clampStars(dynamic value) {
    final parsed = value is int
        ? value
        : value is num
            ? value.round()
            : int.tryParse(value?.toString() ?? '') ?? 2;
    return parsed.clamp(1, 3);
  }

  static String _sanitizeMessage(dynamic value) {
    final text = value?.toString().trim() ?? '';
    if (text.isEmpty) {
      return 'יפה! ממשיכים להתאמן יחד.';
    }
    return text.length > 120 ? '${text.substring(0, 117)}...' : text;
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

  void dispose() {
    _evaluationCache.clear();
  }
}

class MicrophonePermissionException implements Exception {
  MicrophonePermissionException(this.status);

  final MicrophoneAccessStatus status;

  @override
  String toString() => 'Microphone permission: $status';
}

class SpeechRecognitionUnavailableException implements Exception {
  const SpeechRecognitionUnavailableException();

  @override
  String toString() => 'Speech recognition is not available on this device.';
}
