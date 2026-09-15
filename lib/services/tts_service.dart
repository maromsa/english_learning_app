import 'package:flutter/foundation.dart';
import 'package:flutter_tts/flutter_tts.dart';

import 'audio_settings.dart';

/// On-device English TTS for learning screens.
///
/// Wraps [FlutterTts] (Android `TextToSpeech` / iOS `AVSpeechSynthesizer`) so
/// children can hear pronunciation **offline**, with no API keys and no
/// network. This is the local counterpart to [SparkVoiceService] (cloud
/// ElevenLabs / Google TTS via the authenticated proxy).
///
/// Configured slower than the plugin default so sentences stay clear for
/// early readers. Honours [AudioSettings.muted]. Playback is best-effort:
/// plugin / platform-channel failures are swallowed so a missing engine
/// never surfaces to a child.
class TtsService {
  TtsService({
    FlutterTts? tts,
    AudioSettings? audioSettings,
  })  : _tts = tts ?? FlutterTts(),
        _audioSettings = audioSettings ?? AudioSettings();

  final FlutterTts _tts;
  final AudioSettings _audioSettings;
  bool _configured = false;

  /// US English — the classroom pronunciation target for this app.
  static const String language = 'en-US';

  /// Slightly slower than FlutterTts' ~0.5 default so kids can follow along.
  static const double speechRate = 0.4;

  Future<void> _ensureConfigured() async {
    if (_configured) return;
    await _tts.setLanguage(language);
    await _tts.setSpeechRate(speechRate);
    _configured = true;
  }

  /// Speak [text] in English. Empty strings and mute are no-ops.
  Future<void> speak(String text) async {
    final trimmed = text.trim();
    if (trimmed.isEmpty) return;
    if (_audioSettings.muted) return;
    try {
      await _ensureConfigured();
      await _tts.stop();
      await _tts.speak(trimmed);
    } catch (e) {
      debugPrint('TtsService.speak failed: $e');
    }
  }

  /// Interrupt any in-flight utterance.
  Future<void> stop() async {
    try {
      await _tts.stop();
    } catch (e) {
      debugPrint('TtsService.stop failed: $e');
    }
  }
}
