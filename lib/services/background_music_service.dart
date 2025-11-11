import 'package:just_audio/just_audio.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Service to manage background music playback throughout the app
class BackgroundMusicService {
  static final BackgroundMusicService _instance = BackgroundMusicService._internal();
  factory BackgroundMusicService() => _instance;
  BackgroundMusicService._internal();

  final AudioPlayer _audioPlayer = AudioPlayer();
  bool _isInitialized = false;
  bool _isEnabled = true;
  double _volume = 0.5;

  /// Initialize the music service
  Future<void> initialize() async {
    if (_isInitialized) return;

    try {
      // Load user preferences
      final prefs = await SharedPreferences.getInstance();
      _isEnabled = prefs.getBool('background_music_enabled') ?? true;
      _volume = prefs.getDouble('background_music_volume') ?? 0.5;

      // Set audio player configuration
      await _audioPlayer.setLoopMode(LoopMode.one);
      await _audioPlayer.setVolume(_volume);

      _isInitialized = true;
    } catch (e) {
      // Handle initialization errors gracefully
      print('BackgroundMusicService initialization error: $e');
    }
  }

  /// Play background music from an asset path
  Future<void> playMusic(String assetPath) async {
    if (!_isInitialized) {
      await initialize();
    }

    if (!_isEnabled) return;

    try {
      // Stop current playback if any
      await _audioPlayer.stop();

      // Load and play the new track
      await _audioPlayer.setAsset(assetPath);
      await _audioPlayer.play();
    } catch (e) {
      // Handle playback errors gracefully (e.g., missing audio file)
      print('BackgroundMusicService play error: $e');
    }
  }

  /// Stop background music
  Future<void> stopMusic() async {
    try {
      await _audioPlayer.stop();
    } catch (e) {
      print('BackgroundMusicService stop error: $e');
    }
  }

  /// Pause background music
  Future<void> pauseMusic() async {
    try {
      await _audioPlayer.pause();
    } catch (e) {
      print('BackgroundMusicService pause error: $e');
    }
  }

  /// Resume background music
  Future<void> resumeMusic() async {
    if (!_isEnabled) return;

    try {
      await _audioPlayer.play();
    } catch (e) {
      print('BackgroundMusicService resume error: $e');
    }
  }

  /// Set music volume (0.0 to 1.0)
  Future<void> setVolume(double volume) async {
    _volume = volume.clamp(0.0, 1.0);
    try {
      await _audioPlayer.setVolume(_volume);
      final prefs = await SharedPreferences.getInstance();
      await prefs.setDouble('background_music_volume', _volume);
    } catch (e) {
      print('BackgroundMusicService setVolume error: $e');
    }
  }

  /// Enable or disable background music
  Future<void> setEnabled(bool enabled) async {
    _isEnabled = enabled;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('background_music_enabled', enabled);

    if (!enabled) {
      await pauseMusic();
    } else {
      await resumeMusic();
    }
  }

  /// Check if music is enabled
  bool get isEnabled => _isEnabled;

  /// Get current volume
  double get volume => _volume;

  /// Check if music is currently playing
  bool get isPlaying => _audioPlayer.playing;

  /// Dispose resources
  Future<void> dispose() async {
    try {
      await _audioPlayer.dispose();
      _isInitialized = false;
    } catch (e) {
      print('BackgroundMusicService dispose error: $e');
    }
  }
}
