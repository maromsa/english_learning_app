import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:speech_to_text/speech_to_text.dart' as stt;

/// Speech recognition service optimized for children's voices
/// Handles longer pauses, higher pitch tolerance, and forgiving matching
class KidSpeechService {
  final stt.SpeechToText _speech = stt.SpeechToText();
  bool _isInitialized = false;

  /// Initialize the speech recognition service
  Future<bool> initialize() async {
    if (!_isInitialized) {
      _isInitialized = await _speech.initialize(
        onError: (val) => debugPrint('Speech recognition error: $val'),
        onStatus: (val) => debugPrint('Speech recognition status: $val'),
      );
    }
    return _isInitialized;
  }

  /// Listen for speech with child-friendly settings
  /// 
  /// [onResult] - Called when speech is recognized
  /// [onSoundLevel] - Called with sound level (0.0-1.0) for visual feedback
  /// [onStatus] - Called when status changes (listening, done, etc.)
  Future<void> listen({
    required Function(String) onResult,
    Function(double)? onSoundLevel,
    Function(String)? onStatus,
  }) async {
    if (!_isInitialized) {
      final initialized = await initialize();
      if (!initialized) {
        debugPrint('Speech recognition initialization failed');
        return;
      }
    }

    // Child-specific configuration
    await _speech.listen(
      onResult: (val) {
        if (val.finalResult) {
          onResult(val.recognizedWords);
        }
      },
      onSoundLevelChange: onSoundLevel ?? (level) {},
      localeId: 'en_US', // Learning target (English)
      listenFor: const Duration(seconds: 10), // Longer timeout for kids
      pauseFor: const Duration(seconds: 3), // Kids pause to think!
      partialResults: true,
      cancelOnError: false,
      listenMode: stt.ListenMode.dictation, // Better for phrases
    );
  }

  /// Fuzzy matching helper: Kids make small pronunciation errors
  /// Don't fail them for small mistakes
  /// 
  /// Returns true if the recognized word is "close enough" to the target
  bool isCloseEnough(String target, String actual) {
    // Normalize strings
    target = target.toLowerCase().trim().replaceAll(RegExp(r'[^\w\s]'), '');
    actual = actual.toLowerCase().trim().replaceAll(RegExp(r'[^\w\s]'), '');

    // Exact match
    if (actual == target) return true;

    // Contains match (for phrases)
    if (actual.contains(target) || target.contains(actual)) return true;

    // Simple character difference check
    // Allow 1-2 character difference for small mistakes
    final targetLength = target.length;
    final actualLength = actual.length;
    
    // If lengths are very different, probably not a match
    if ((targetLength - actualLength).abs() > 2) return false;

    // Count character differences
    int differences = 0;
    final minLength = targetLength < actualLength ? targetLength : actualLength;
    
    for (int i = 0; i < minLength; i++) {
      if (target[i] != actual[i]) {
        differences++;
        if (differences > 2) return false;
      }
    }

    // Allow up to 2 character differences
    return differences <= 2;
  }

  /// Stop listening
  Future<void> stop() async {
    await _speech.stop();
  }

  /// Cancel listening
  Future<void> cancel() async {
    await _speech.cancel();
  }

  /// Check if currently listening
  bool get isListening => _speech.isListening;
}


