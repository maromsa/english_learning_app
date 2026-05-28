import 'package:flutter/foundation.dart';
import 'package:just_audio/just_audio.dart';

/// Enhanced audio feedback service optimized for children
/// Uses child-friendly sounds that are pleasant and non-jarring
class SoundService {
  static final SoundService _instance = SoundService._internal();
  factory SoundService() => _instance;
  SoundService._internal();

  bool _initialized = false;

  @visibleForTesting
  VoidCallback? debugOnPlaySoftChime;

  @visibleForTesting
  VoidCallback? debugOnPlayPop;

  @visibleForTesting
  VoidCallback? debugOnPlayFanfare;

  @visibleForTesting
  VoidCallback? debugOnPlayEpic;

  /// Initialize the sound service
  Future<void> initialize() async {
    if (_initialized) return;
    _initialized = true;
  }

  /// Celebration-tier SFX identifiers.
  static const String softChime = 'softChime';
  static const String pop = 'pop';
  static const String fanfare = 'fanfare';
  static const String epic = 'epic';

  String? _getSoundAsset(String type) {
    switch (type) {
      case softChime:
        return 'assets/sfx/soft_chime.mp3';
      case pop:
        return 'assets/sfx/pop.mp3';
      case fanfare:
        return 'assets/sfx/fanfare.mp3';
      case epic:
        return 'assets/sfx/epic.mp3';
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

  String? _fallbackSoundAsset(String type) {
    switch (type) {
      case softChime:
        return 'assets/audio/magic_chime_C_major.mp3';
      case pop:
        return 'assets/audio/bubble_pop.mp3';
      case fanfare:
        return 'assets/audio/fanfare_short.mp3';
      case epic:
        return 'assets/audio/tada.mp3';
      default:
        return null;
    }
  }

  double _getVolume(String type) {
    switch (type) {
      case pop:
        return 0.3; // Quiet UI sound
      case softChime:
        return 0.5;
      case 'try_again':
      case 'error':
        return 0.6; // Gentle error sound
      case 'success':
      case 'confetti':
      case 'unlock':
      case fanfare:
      case epic:
        return 1.0; // Full volume for celebrations
      default:
        return 0.8;
    }
  }

  /// Play a sound effect with appropriate volume.
  ///
  /// Types include [softChime], [pop], [fanfare], [epic], plus legacy keys:
  /// `success`, `error`, `try_again`, `confetti`, `unlock`, `whoosh`, `ding`.
  Future<void> playSound(String type) async {
    if (!_initialized) {
      await initialize();
    }

    final primary = _getSoundAsset(type);
    if (primary == null) {
      debugPrint('Unknown sound type: $type');
      return;
    }

    final played = await _tryPlayAsset(type, primary);
    if (played) return;

    final fallback = _fallbackSoundAsset(type);
    if (fallback == null) return;

    debugPrint(
      'SoundService: missing asset $primary for $type, trying fallback $fallback',
    );
    await _tryPlayAsset(type, fallback);
  }

  Future<bool> _tryPlayAsset(String type, String asset) async {
    try {
      final player = AudioPlayer();
      await player.setAsset(asset);
      await player.setVolume(_getVolume(type));
      await player.play();
      Future<void>.delayed(const Duration(seconds: 2), () {
        player.dispose();
      });
      return true;
    } catch (e) {
      debugPrint('SoundService: could not play $asset for $type: $e');
      return false;
    }
  }

  /// Play a short "pop" sound — suitable for button taps and UI interactions.
  /// Fire-and-forget: never blocks the calling widget's build / event cycle.
  void playPopSound() {
    debugOnPlayPop?.call();
    playSound(pop).catchError((Object e) {
      debugPrint('SoundService.playPopSound error: $e');
    });
  }

  /// Soft chime for micro celebrations (first-try correct).
  void playSoftChime() {
    debugOnPlaySoftChime?.call();
    playSound(softChime).catchError((Object e) {
      debugPrint('SoundService.playSoftChime error: $e');
    });
  }

  /// Fanfare for level-complete celebrations.
  void playFanfare() {
    debugOnPlayFanfare?.call();
    playSound(fanfare).catchError((Object e) {
      debugPrint('SoundService.playFanfare error: $e');
    });
  }

  /// Epic sting for chapter-complete celebrations.
  void playEpic() {
    debugOnPlayEpic?.call();
    playSound(epic).catchError((Object e) {
      debugPrint('SoundService.playEpic error: $e');
    });
  }

  /// Play a "success" chime — suitable for correct answers and successful
  /// purchases.  Fire-and-forget: never blocks the UI thread.
  void playSuccessSound() {
    playSound('success').catchError((Object e) {
      debugPrint('SoundService.playSuccessSound error: $e');
    });
  }

  /// Dispose resources (called on app shutdown)
  Future<void> dispose() async {
    // Note: Individual players are disposed after playing
    // This method is for any shared resources if needed
  }
}
