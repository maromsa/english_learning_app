import 'package:just_audio/just_audio.dart';
import 'package:flutter/foundation.dart';

/// Enhanced audio feedback service optimized for children
/// Uses child-friendly sounds that are pleasant and non-jarring
class SoundService {
  static final SoundService _instance = SoundService._internal();
  factory SoundService() => _instance;
  SoundService._internal();

  bool _initialized = false;

  /// Initialize the sound service
  Future<void> initialize() async {
    if (_initialized) return;
    _initialized = true;
  }

  String? _getSoundAsset(String type) {
    switch (type) {
      case 'pop':
        return 'assets/audio/bubble_pop.mp3'; // Soft UI sound
      case 'success':
        return 'assets/audio/magic_chime_C_major.mp3'; // Major key, upward scale
      case 'error':
      case 'try_again':
        return 'assets/audio/soft_wooden_thud.mp3'; // Gentle error, not harsh
      case 'confetti':
        return 'assets/audio/tada.mp3';
      case 'unlock':
        return 'assets/audio/fanfare_short.mp3';
      case 'whoosh':
        return 'assets/audio/whoosh.mp3';
      case 'ding':
        return 'assets/audio/ding.mp3';
      default:
        return null;
    }
  }

  double _getVolume(String type) {
    switch (type) {
      case 'pop':
        return 0.3; // Quiet UI sound
      case 'try_again':
      case 'error':
        return 0.6; // Gentle error sound
      case 'success':
      case 'confetti':
      case 'unlock':
        return 1.0; // Full volume for celebrations
      default:
        return 0.8;
    }
  }

  /// Play a sound effect with appropriate volume
  /// Types: 'pop', 'success', 'error', 'try_again', 'confetti', 'unlock', 'whoosh', 'ding'
  Future<void> playSound(String type) async {
    if (!_initialized) {
      await initialize();
    }

    final asset = _getSoundAsset(type);
    if (asset == null) {
      debugPrint('Unknown sound type: $type');
      return;
    }

    try {
      // Create a momentary player for overlapping sounds
      // This allows multiple sounds to play simultaneously
      final player = AudioPlayer();
      await player.setAsset(asset);
      await player.setVolume(_getVolume(type));
      
      player.play().then((_) {
        // Dispose player after sound finishes
        Future.delayed(const Duration(seconds: 2), () {
          player.dispose();
        });
      }).catchError((e) {
        debugPrint('SoundService play error for $type: $e');
        player.dispose();
      });
    } catch (e) {
      debugPrint('SoundService error for $type: $e');
      // Fail silently - don't break the app if sounds don't work
    }
  }

  /// Dispose resources (called on app shutdown)
  Future<void> dispose() async {
    // Note: Individual players are disposed after playing
    // This method is for any shared resources if needed
  }
}

