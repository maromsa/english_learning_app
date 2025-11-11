import 'package:flutter/foundation.dart';
import 'package:just_audio/just_audio.dart';

class BackgroundMusicService {
  BackgroundMusicService._internal();

  static final BackgroundMusicService _instance =
      BackgroundMusicService._internal();

  factory BackgroundMusicService() => _instance;

  final AudioPlayer _player = AudioPlayer();

  String? _currentAsset;
  bool _initialized = false;

  Future<void> initialize({double volume = 0.35}) async {
    if (_initialized) {
      return;
    }

    await _player.setVolume(volume.clamp(0.0, 1.0));
    await _player.setLoopMode(LoopMode.off);
    _initialized = true;
  }

  Future<void> playStartupTheme() =>
      _playAsset('assets/audio/startup_theme.wav', loop: true);

  Future<void> playMapTheme() =>
      _playAsset('assets/audio/map_theme.wav', loop: true);

  Future<void> stop() async {
    try {
      await _player.stop();
    } catch (e) {
      debugPrint('BackgroundMusicService stop failed: $e');
    } finally {
      _currentAsset = null;
    }
  }

  Future<void> dispose() async {
    try {
      await _player.dispose();
    } catch (e) {
      debugPrint('BackgroundMusicService dispose failed: $e');
    } finally {
      _initialized = false;
      _currentAsset = null;
    }
  }

  Future<void> setVolume(double volume) async {
    if (!_initialized) {
      await initialize(volume: volume);
      return;
    }
    await _player.setVolume(volume.clamp(0.0, 1.0));
  }

  Future<void> _playAsset(
    String assetPath, {
    bool loop = false,
  }) async {
    try {
      await initialize();

      if (_currentAsset == assetPath && _player.playing) {
        return;
      }

      await _player.stop();
      await _player.setAudioSource(AudioSource.asset(assetPath));
      await _player.setLoopMode(loop ? LoopMode.one : LoopMode.off);
      _currentAsset = assetPath;
      await _player.play();
    } catch (e) {
      debugPrint('BackgroundMusicService failed to play $assetPath: $e');
    }
  }
}
