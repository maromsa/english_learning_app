import 'package:flutter/foundation.dart';
import 'package:just_audio/just_audio.dart';

/// Enhanced audio feedback service optimized for children
/// Uses child-friendly sounds that are pleasant and non-jarring
class SoundService {
  static final SoundService _instance = SoundService._internal();
  factory SoundService() => _instance;
  SoundService._internal();

  bool _initialized = false;

  /// Short neutral tap — used for micro UI feedback and as a safe fallback.
  @visibleForTesting
  static const String uiClickAsset = 'assets/audio/ui_click.wav';

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
      case pop:
        return uiClickAsset;
      case fanfare:
      case epic:
        return 'assets/audio/the_twinkling_map.mp3';
      case 'success':
        return uiClickAsset;
      case 'error':
      case 'try_again':
        return uiClickAsset;
      case 'confetti':
      case 'unlock':
        return 'assets/audio/the_twinkling_map.mp3';
      case 'whoosh':
      case 'ding':
        return uiClickAsset;
      default:
        return null;
    }
  }

  /// Fallback when the primary asset fails to load. Never routes micro/pop
  /// feedback through [startup_chime] — on Web we stay silent if the click
  /// cannot load.
  @visibleForTesting
  String? fallbackSoundAsset(String type) {
    switch (type) {
      case softChime:
      case pop:
      case 'success':
      case 'error':
      case 'try_again':
      case 'whoosh':
      case 'ding':
        return null;
      case fanfare:
      case epic:
      case 'confetti':
      case 'unlock':
        return uiClickAsset;
      default:
        return null;
    }
  }

  /// Collapses accidental `assets/assets/…` keys before [AudioPlayer.setAsset].
  ///
  /// Pubspec keys always start with a single `assets/` segment. On Flutter Web the
  /// runtime may resolve that to a URL containing `assets/assets/…`; passing a
  /// key that already includes the doubled segment breaks loading.
  @visibleForTesting
  static String normalizeAssetPath(String path) {
    var normalized = path.trim();
    while (normalized.startsWith('assets/assets/')) {
      normalized = normalized.substring('assets/'.length);
    }
    return normalized;
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

    final fallback = fallbackSoundAsset(type);
    if (fallback == null) {
      if (kDebugMode) {
        debugPrint(
          'SoundService: missing asset $primary for $type; no fallback (silent)',
        );
      }
      return;
    }

    debugPrint(
      'SoundService: missing asset $primary for $type, trying fallback $fallback',
    );
    await _tryPlayAsset(type, fallback);
  }

  Future<bool> _tryPlayAsset(String type, String asset) async {
    try {
      final player = AudioPlayer();
      await player.setAsset(normalizeAssetPath(asset));
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
