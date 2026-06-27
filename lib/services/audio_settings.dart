import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// App-wide audio mute setting.
///
/// A single source of truth consulted by every audio service
/// ([SoundService], [SparkVoiceService], [BackgroundMusicService]) before
/// playing anything. When [muted] is true all sound is suppressed. The value
/// is persisted across launches via [SharedPreferences].
class AudioSettings with ChangeNotifier {
  static final AudioSettings _instance = AudioSettings._internal();
  factory AudioSettings() => _instance;
  AudioSettings._internal();

  static const String _prefsKey = 'is_audio_muted';

  bool _muted = false;
  bool _disposed = false;

  /// Whether all app audio is currently muted.
  bool get muted => _muted;

  void _notify() {
    if (!_disposed) notifyListeners();
  }

  /// Load the persisted mute preference. Safe to call multiple times.
  Future<void> load() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      _muted = prefs.getBool(_prefsKey) ?? false;
      _notify();
    } catch (e) {
      debugPrint('AudioSettings: failed to load mute preference: $e');
    }
  }

  /// Update the mute preference and persist it.
  Future<void> setMuted(bool value) async {
    if (_muted == value) return;
    _muted = value;
    _notify();
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(_prefsKey, value);
    } catch (e) {
      debugPrint('AudioSettings: failed to save mute preference: $e');
    }
  }

  /// Convenience flip used by simple UI toggles.
  Future<void> toggle() => setMuted(!_muted);

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }
}
