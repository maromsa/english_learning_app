import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:just_audio/just_audio.dart';

enum _BackgroundPlaylist { none, startupSequence, mapLoop }

class BackgroundMusicService with WidgetsBindingObserver {
  BackgroundMusicService._internal() {
    WidgetsBinding.instance.addObserver(this);
  }

  static final BackgroundMusicService _instance =
      BackgroundMusicService._internal();

  factory BackgroundMusicService() => _instance;

  final AudioPlayer _player = AudioPlayer();

  bool _initialized = false;
  bool _resumeOnForeground = false;
  _BackgroundPlaylist _currentPlaylist = _BackgroundPlaylist.none;
  StreamSubscription<int?>? _currentIndexSubscription;

  static const _startupChimeAsset = 'assets/audio/startup_chime.wav';
  static const _backgroundLoopAsset = 'assets/audio/background_loop.wav';

  Future<void> initialize() async {
    if (_initialized) {
      return;
    }
    try {
      await _player.setVolume(0.4);
      await _player.setLoopMode(LoopMode.off);
      _currentIndexSubscription ??=
          _player.currentIndexStream.listen((int? index) {
        if (index == null) {
          return;
        }
        if (_currentPlaylist == _BackgroundPlaylist.startupSequence &&
            index == 1) {
          unawaited(_player.setLoopMode(LoopMode.one));
        }
      });
      _initialized = true;
    } catch (error, stackTrace) {
      debugPrint('BackgroundMusicService init failed: $error');
      debugPrint('$stackTrace');
    }
  }

  Future<void> playStartupSequence() async {
    await initialize();
    if (_currentPlaylist == _BackgroundPlaylist.startupSequence) {
      if (!_player.playing) {
        await _player.play();
      }
      return;
    }

    try {
      await _player.stop();
      await _player.setLoopMode(LoopMode.off);
      final source = ConcatenatingAudioSource(
        children: [
          AudioSource.asset(_startupChimeAsset),
          AudioSource.asset(_backgroundLoopAsset),
        ],
      );
      await _player.setAudioSource(source);
      _player.play().catchError((error, stackTrace) {
        debugPrint('Startup playback error: $error');
        debugPrint('$stackTrace');
      });
      _currentPlaylist = _BackgroundPlaylist.startupSequence;
    } catch (error, stackTrace) {
      debugPrint('Failed to play startup sequence: $error');
      debugPrint('$stackTrace');
    }
  }

  Future<void> playMapLoop() async {
    await initialize();
    if (_currentPlaylist == _BackgroundPlaylist.mapLoop && _player.playing) {
      return;
    }

    try {
      await _player.setAudioSource(
        AudioSource.asset(_backgroundLoopAsset),
      );
      await _player.setLoopMode(LoopMode.one);
      _player.play().catchError((error, stackTrace) {
        debugPrint('Map loop playback error: $error');
        debugPrint('$stackTrace');
      });
      _currentPlaylist = _BackgroundPlaylist.mapLoop;
    } catch (error, stackTrace) {
      debugPrint('Failed to play map loop: $error');
      debugPrint('$stackTrace');
    }
  }

  Future<void> fadeOut({Duration duration = const Duration(milliseconds: 600)}) {
    return _player
        .setVolume(0)
        .timeout(duration, onTimeout: () {})
        .catchError((_) {});
  }

  Future<void> stop() async {
    _currentPlaylist = _BackgroundPlaylist.none;
    await _player.setLoopMode(LoopMode.off);
    try {
      await _player.stop();
    } catch (error, stackTrace) {
      debugPrint('Failed to stop background music: $error');
      debugPrint('$stackTrace');
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    switch (state) {
      case AppLifecycleState.inactive:
      case AppLifecycleState.paused:
        _resumeOnForeground = _player.playing;
        _player.pause();
        break;
      case AppLifecycleState.resumed:
        if (_resumeOnForeground && !_player.playing) {
          _player.play();
        }
        _resumeOnForeground = false;
        break;
      case AppLifecycleState.detached:
        _resumeOnForeground = false;
        _player.stop();
        break;
      case AppLifecycleState.hidden:
        // Hidden only applies to web/desktop; pause similarly.
        _resumeOnForeground = _player.playing;
        _player.pause();
        break;
    }
  }

  Future<void> dispose() async {
    WidgetsBinding.instance.removeObserver(this);
    await _currentIndexSubscription?.cancel();
    _currentIndexSubscription = null;
    await _player.dispose();
  }
}
