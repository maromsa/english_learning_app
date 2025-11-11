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
  bool _awaitingUserInteractionUnlock = false;
  bool _userInteractionReceived = !kIsWeb;
  ConcatenatingAudioSource? _startupSequenceSource;
  bool _startupChimeRemoved = false;
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
            if (!_startupChimeRemoved) {
              _startupChimeRemoved = true;
              final source = _startupSequenceSource;
              if (source != null) {
                unawaited(source.removeAt(0));
              }
            }
            unawaited(_player.setLoopMode(_loopModeForSingleTrack()));
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
        await _startPlaybackWithUnlock(
          contextDescription: 'Startup sequence',
        );
      }
      return;
    }

    try {
      await _player.stop();
      await _player.setLoopMode(LoopMode.off);
        _startupSequenceSource = ConcatenatingAudioSource(
          useLazyPreparation: true,
          children: [
            AudioSource.asset(_startupChimeAsset),
            AudioSource.asset(_backgroundLoopAsset),
          ],
        );
        _startupChimeRemoved = false;
        await _player.setAudioSource(_startupSequenceSource!);
      _currentPlaylist = _BackgroundPlaylist.startupSequence;
      await _startPlaybackWithUnlock(
        contextDescription: 'Startup sequence',
      );
    } catch (error, stackTrace) {
      debugPrint('Failed to play startup sequence: $error');
      debugPrint('$stackTrace');
        _startupSequenceSource = null;
        _startupChimeRemoved = false;
    }
  }

  Future<void> playMapLoop() async {
    await initialize();
    if (_currentPlaylist == _BackgroundPlaylist.mapLoop && _player.playing) {
      return;
    }

    try {
        _startupSequenceSource = null;
        _startupChimeRemoved = false;
        await _player.setAudioSource(
        AudioSource.asset(_backgroundLoopAsset),
      );
        await _player.setLoopMode(_loopModeForSingleTrack());
      _currentPlaylist = _BackgroundPlaylist.mapLoop;
      await _startPlaybackWithUnlock(
        contextDescription: 'Map loop',
      );
    } catch (error, stackTrace) {
      debugPrint('Failed to play map loop: $error');
      debugPrint('$stackTrace');
    }
  }

  Future<void> handleUserInteraction() async {
      _userInteractionReceived = true;
      if (!_awaitingUserInteractionUnlock) {
        return;
      }
    if (_currentPlaylist == _BackgroundPlaylist.none) {
      _awaitingUserInteractionUnlock = false;
      return;
    }
    await _startPlaybackWithUnlock(
      contextDescription: _currentPlaylist == _BackgroundPlaylist.mapLoop
          ? 'Map loop'
          : 'Startup sequence',
    );
  }

  Future<void> _startPlaybackWithUnlock({
    required String contextDescription,
  }) async {
      if (kIsWeb && !_userInteractionReceived) {
        if (!_awaitingUserInteractionUnlock) {
          debugPrint(
            '$contextDescription playback deferred until user interaction.',
          );
        }
        _awaitingUserInteractionUnlock = true;
        return;
      }
    try {
      await _player.play();
      if (_awaitingUserInteractionUnlock) {
        debugPrint(
          '$contextDescription playback resumed after user interaction.',
        );
      }
      _awaitingUserInteractionUnlock = false;
    } catch (error, stackTrace) {
      if (_requiresUserInteractionUnlock(error)) {
        _awaitingUserInteractionUnlock = true;
        debugPrint(
          '$contextDescription playback deferred until user interaction: $error',
        );
      } else {
        debugPrint('$contextDescription playback error: $error');
        debugPrint('$stackTrace');
      }
    }
  }

  bool _requiresUserInteractionUnlock(Object error) {
    if (!kIsWeb) {
      return false;
    }
    if (error is PlayerException) {
      final code = _lowercase(error.code);
      final message = _lowercase(error.message);
      if (code.contains('notallowed') || message.contains('notallowed')) {
        return true;
      }
    }
    final errorString = _lowercase(error);
    return errorString.contains('notallowed');
  }

  String _lowercase(Object? value) {
    if (value == null) {
      return '';
    }
    final normalized = value is String ? value : value.toString();
    return normalized.toLowerCase();
  }

  Future<void> fadeOut({Duration duration = const Duration(milliseconds: 600)}) {
    return _player
        .setVolume(0)
        .timeout(duration, onTimeout: () {})
        .catchError((_) {});
  }

  Future<void> stop() async {
    _currentPlaylist = _BackgroundPlaylist.none;
    _awaitingUserInteractionUnlock = false;
      _startupSequenceSource = null;
      _startupChimeRemoved = false;
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
    _awaitingUserInteractionUnlock = false;
      _startupSequenceSource = null;
      _startupChimeRemoved = false;
    await _player.dispose();
  }

    LoopMode _loopModeForSingleTrack() {
      return kIsWeb ? LoopMode.all : LoopMode.one;
    }
}
