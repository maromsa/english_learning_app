import 'package:flutter/foundation.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:speech_to_text/speech_to_text.dart';

/// On-device English speech-to-text for pronunciation practice.
///
/// Wraps [SpeechToText] so children can speak a sentence and have it compared
/// with the target **offline** (no API keys, no Gemini). This is the local
/// counterpart to [SpeechFeedbackService] (which can ask Spark for star
/// ratings via the authenticated proxy).
///
/// Playback / recognition is best-effort: plugin, permission, or
/// platform-channel failures are swallowed so a missing engine never
/// surfaces to a child.
class SpeechService {
  SpeechService({SpeechToText? speech}) : _speech = speech ?? SpeechToText();

  final SpeechToText _speech;
  bool _initialized = false;
  bool _deliveredFinal = false;
  void Function(String status)? _statusListener;

  /// US English — the classroom pronunciation target for this app.
  static const String primaryLocaleId = 'en_US';

  /// Fallback if the device has British English but not US English.
  static const String fallbackLocaleId = 'en_GB';

  /// Minimum normalized similarity (0–1) to count as a successful attempt.
  static const double matchThreshold = 0.8;

  static final RegExp _nonWord = RegExp(r'[^\w\s]+');
  static final RegExp _whitespace = RegExp(r'\s+');

  /// Whether the recognizer is currently capturing audio.
  bool get isListening {
    try {
      return _speech.isListening;
    } catch (_) {
      return false;
    }
  }

  /// Requests microphone permission and prepares the recognizer.
  ///
  /// Returns `false` when the child (or OS) denied access, or when the
  /// engine is missing. Never throws.
  Future<bool> initialize() async {
    if (_initialized) return true;
    try {
      if (!kIsWeb) {
        try {
          final status = await Permission.microphone.request();
          if (!status.isGranted && !status.isLimited) {
            debugPrint('SpeechService: microphone permission $status');
            return false;
          }
        } catch (e) {
          debugPrint('SpeechService: permission request skipped: $e');
        }
      }
      _initialized = await _speech.initialize(
        onError: (error) => debugPrint('SpeechService error: $error'),
        onStatus: (status) => _statusListener?.call(status),
      );
    } catch (e) {
      debugPrint('SpeechService.initialize failed: $e');
      _initialized = false;
    }
    return _initialized;
  }

  /// Starts listening for English speech and reports recognized words.
  ///
  /// [onResult] is invoked with the final transcript. [onDone] fires when
  /// the session ends without a final result (timeout / cancel). [onSoundLevel]
  /// is an optional 0–1-ish meter for a waveform / pulse.
  Future<void> startListening(
    void Function(String recognized) onResult, {
    void Function(double level)? onSoundLevel,
    void Function()? onDone,
  }) async {
    try {
      if (!_initialized) {
        final ready = await initialize();
        if (!ready) return;
      }
      _deliveredFinal = false;
      _statusListener = (status) {
        if (isTerminalStatus(status) && !_deliveredFinal) {
          onDone?.call();
        }
      };
      final localeId = await _resolveLocaleId();
      await _speech.listen(
        onResult: (result) {
          final words = result.recognizedWords;
          if (words.isEmpty) return;
          if (result.finalResult) {
            _deliveredFinal = true;
            onResult(words);
          }
        },
        onSoundLevelChange: onSoundLevel,
        listenOptions: SpeechListenOptions(
          localeId: localeId,
          listenFor: const Duration(seconds: 10),
          pauseFor: const Duration(seconds: 3),
          partialResults: true,
          cancelOnError: false,
          listenMode: ListenMode.dictation,
        ),
      );
    } catch (e) {
      debugPrint('SpeechService.startListening failed: $e');
    }
  }

  /// Stops the current listen session. Safe to call when idle.
  Future<void> stopListening() async {
    try {
      await _speech.stop();
    } catch (e) {
      debugPrint('SpeechService.stopListening failed: $e');
    } finally {
      _statusListener = null;
    }
  }

  /// Lowercases [input], strips punctuation, and collapses whitespace.
  static String normalize(String input) {
    return input
        .toLowerCase()
        .replaceAll(_nonWord, ' ')
        .replaceAll(_whitespace, ' ')
        .trim();
  }

  /// True when [recognized] is the same as [target], or close enough for a
  /// child speaker (typos, dropped endings, extra "um").
  static bool matches(String target, String recognized) {
    final a = normalize(target);
    final b = normalize(recognized);
    if (a.isEmpty || b.isEmpty) return false;
    if (a == b) return true;
    if (_wordCoverage(a, b) >= matchThreshold) return true;
    return similarity(a, b) >= matchThreshold;
  }

  /// Levenshtein ratio in `0..1` on already-normalized strings.
  static double similarity(String a, String b) {
    if (a == b) return 1;
    if (a.isEmpty || b.isEmpty) return 0;
    final distance = _levenshtein(a, b);
    final maxLen = a.length > b.length ? a.length : b.length;
    return 1 - (distance / maxLen);
  }

  static bool isTerminalStatus(String status) {
    return status == SpeechToText.doneStatus ||
        status == SpeechToText.notListeningStatus ||
        status == 'doneNoResult';
  }

  Future<String> _resolveLocaleId() async {
    try {
      final locales = await _speech.locales();
      bool has(String id) {
        final needle = id.replaceAll('-', '_').toLowerCase();
        return locales.any(
          (locale) =>
              locale.localeId.replaceAll('-', '_').toLowerCase() == needle,
        );
      }

      if (has(primaryLocaleId)) return primaryLocaleId;
      if (has(fallbackLocaleId)) return fallbackLocaleId;
      for (final locale in locales) {
        if (locale.localeId.toLowerCase().startsWith('en')) {
          return locale.localeId;
        }
      }
    } catch (e) {
      debugPrint('SpeechService.locales failed: $e');
    }
    return primaryLocaleId;
  }

  static double _wordCoverage(String target, String heard) {
    final targetWords =
        target.split(' ').where((word) => word.isNotEmpty).toList();
    final heardWords =
        heard.split(' ').where((word) => word.isNotEmpty).toList();
    if (targetWords.isEmpty) return 0;
    var hits = 0;
    for (final word in targetWords) {
      final matched = heardWords.any(
        (heard) => heard == word || _closeWords(word, heard),
      );
      if (matched) hits++;
    }
    return hits / targetWords.length;
  }

  static bool _closeWords(String a, String b) {
    if (a == b) return true;
    if ((a.length - b.length).abs() > 2) return false;
    return similarity(a, b) >= 0.75;
  }

  static int _levenshtein(String a, String b) {
    final m = a.length;
    final n = b.length;
    final dp = List<List<int>>.generate(
      m + 1,
      (i) => List<int>.filled(n + 1, 0),
    );
    for (var i = 0; i <= m; i++) {
      dp[i][0] = i;
    }
    for (var j = 0; j <= n; j++) {
      dp[0][j] = j;
    }
    for (var i = 1; i <= m; i++) {
      for (var j = 1; j <= n; j++) {
        final cost = a[i - 1] == b[j - 1] ? 0 : 1;
        final deletion = dp[i - 1][j] + 1;
        final insertion = dp[i][j - 1] + 1;
        final substitution = dp[i - 1][j - 1] + cost;
        var best = deletion;
        if (insertion < best) best = insertion;
        if (substitution < best) best = substitution;
        dp[i][j] = best;
      }
    }
    return dp[m][n];
  }
}
