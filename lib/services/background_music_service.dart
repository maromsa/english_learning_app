import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:just_audio/just_audio.dart';

enum BackgroundTrack {
  appIntro('assets/audio/background_loop.wav'),
  mapLoop('assets/audio/background_loop.wav');

  const BackgroundTrack(this.assetPath);

  final String assetPath;
}

class BackgroundMusicService extends ChangeNotifier with WidgetsBindingObserver {
  BackgroundMusicService({AudioPlayer? audioPlayer})
      : _player = audioPlayer ?? AudioPlayer() {
    final binding = WidgetsBinding.instance;
    binding.addObserver(this);
    _player.setLoopMode(LoopMode.one);
    _player.setVolume(_baseVolume);
  }

  static const double _baseVolume = 0.32;

  final AudioPlayer _player;
  BackgroundTrack? _currentTrack;
  bool _muted = false;
  bool _resumeOnFocus = false;
  bool _disposed = false;

  BackgroundTrack? get currentTrack => _currentTrack;
  bool get isMuted => _muted;
  bool get isPlaying => _player.playing;

  Future<void> playIntro({bool forceRestart = false}) =>
      _playTrack(BackgroundTrack.appIntro, forceRestart: forceRestart);

  Future<void> playMapLoop({bool forceRestart = false}) =>
      _playTrack(BackgroundTrack.mapLoop, forceRestart: forceRestart);

  Future<void> _playTrack(BackgroundTrack track,
      {bool forceRestart = false}) async {
    if (_disposed) return;
    if (_muted) {
      _currentTrack = track;
      return;
    }

    final bool needsReload = forceRestart || _currentTrack != track;

    try {
      if (needsReload) {
        await _player.setAsset(track.assetPath);
        _currentTrack = track;
      }
      await _player.setLoopMode(LoopMode.one);
      await _player.setVolume(_baseVolume);
      if (!_player.playing) {
        await _player.play();
      }
      _resumeOnFocus = true;
    } catch (error, stackTrace) {
      debugPrint(
        'BackgroundMusicService: failed to play ${track.assetPath}: $error',
      );
      debugPrint(stackTrace.toString());
    }
  }

  Future<void> fadeToTrack(BackgroundTrack track,
      {Duration duration = const Duration(milliseconds: 600)}) async {
    if (_disposed) return;
    if (_muted) {
      _currentTrack = track;
      return;
    }

    if (_currentTrack == track && _player.playing) {
      return;
    }

    await _fadeVolume(to: 0.0, duration: duration ~/ 2);
    await _playTrack(track, forceRestart: true);
    await _fadeVolume(to: _baseVolume, duration: duration ~/ 2);
  }

  Future<void> pause() async {
    if (_disposed) return;
    _resumeOnFocus = false;
    await _player.pause();
  }

  Future<void> stop() async {
    if (_disposed) return;
    _resumeOnFocus = false;
    await _player.stop();
  }

  Future<void> setMuted(bool muted) async {
    if (_disposed) return;
    if (_muted == muted) return;
    _muted = muted;
    if (muted) {
      _resumeOnFocus = false;
      await _player.stop();
    } else {
      if (_currentTrack != null) {
        unawaited(_playTrack(_currentTrack!, forceRestart: true));
      }
    }
    notifyListeners();
  }

  Future<void> setVolume(double volume) async {
    if (_disposed) return;
    final clamped = volume.clamp(0.0, 1.0);
    await _player.setVolume(clamped);
  }

  Future<void> _fadeVolume(
      {required double to, Duration duration = Duration.zero}) async {
    if (_disposed) return;
    if (duration <= Duration.zero) {
      await _player.setVolume(to);
      return;
    }

    const int steps = 12;
    final double start = _player.volume;
    final double delta = (to - start) / steps;
    final int stepDuration = (duration.inMilliseconds / steps).round();

    for (int i = 1; i <= steps; i++) {
      if (_disposed) return;
      await _player.setVolume(start + delta * i);
      await Future<void>.delayed(Duration(milliseconds: stepDuration));
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (_disposed) return;
    switch (state) {
      case AppLifecycleState.inactive:
      case AppLifecycleState.paused:
        _resumeOnFocus = _player.playing;
        unawaited(_player.pause());
        break;
      case AppLifecycleState.resumed:
        if (_resumeOnFocus && !_muted && _currentTrack != null) {
          unawaited(_player.play());
        }
        break;
      case AppLifecycleState.detached:
      case AppLifecycleState.hidden:
        // Nothing to do, hidden is web-only.
        break;
    }
  }

  @override
  void dispose() {
    if (_disposed) return;
    _disposed = true;
    WidgetsBinding.instance.removeObserver(this);
    _player.dispose();
    super.dispose();
  }
}
