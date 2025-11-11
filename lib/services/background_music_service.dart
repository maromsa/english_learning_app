// lib/services/background_music_service.dart
import 'package:flutter/foundation.dart';
import 'package:just_audio/just_audio.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Service for managing background music throughout the app.
/// Supports different music tracks for different screens and maintains
/// music state across the app lifecycle.
class BackgroundMusicService extends ChangeNotifier {
  final AudioPlayer _audioPlayer = AudioPlayer();
  bool _isMusicEnabled = true;
  bool _isPlaying = false;
  String? _currentTrack;
  
  static const String _musicEnabledKey = 'background_music_enabled';
  
  BackgroundMusicService() {
    _loadMusicPreference();
    _setupPlayerListeners();
  }

  bool get isMusicEnabled => _isMusicEnabled;
  bool get isPlaying => _isPlaying;
  String? get currentTrack => _currentTrack;

  /// Load user's music preference from storage
  Future<void> _loadMusicPreference() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      _isMusicEnabled = prefs.getBool(_musicEnabledKey) ?? true;
      notifyListeners();
    } catch (e) {
      debugPrint('Error loading music preference: $e');
    }
  }

  /// Save user's music preference to storage
  Future<void> _saveMusicPreference() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(_musicEnabledKey, _isMusicEnabled);
    } catch (e) {
      debugPrint('Error saving music preference: $e');
    }
  }

  /// Set up listeners for player state changes
  void _setupPlayerListeners() {
    _audioPlayer.playerStateStream.listen((state) {
      _isPlaying = state.playing;
      notifyListeners();
    });
  }

  /// Play background music from asset path
  Future<void> playMusic(String assetPath, {bool loop = true}) async {
    if (!_isMusicEnabled) {
      return;
    }

    try {
      // If the same track is already playing, don't restart it
      if (_currentTrack == assetPath && _isPlaying) {
        return;
      }

      _currentTrack = assetPath;
      
      await _audioPlayer.setAsset(assetPath);
      await _audioPlayer.setLoopMode(loop ? LoopMode.one : LoopMode.off);
      await _audioPlayer.setVolume(0.3); // Set volume to 30% for background music
      await _audioPlayer.play();
      
      _isPlaying = true;
      notifyListeners();
    } catch (e) {
      debugPrint('Error playing background music: $e');
      // Don't crash if music fails to load - just continue without music
    }
  }

  /// Play music from URL (for streaming online music)
  Future<void> playMusicFromUrl(String url, {bool loop = true}) async {
    if (!_isMusicEnabled) {
      return;
    }

    try {
      if (_currentTrack == url && _isPlaying) {
        return;
      }

      _currentTrack = url;
      
      await _audioPlayer.setUrl(url);
      await _audioPlayer.setLoopMode(loop ? LoopMode.one : LoopMode.off);
      await _audioPlayer.setVolume(0.3);
      await _audioPlayer.play();
      
      _isPlaying = true;
      notifyListeners();
    } catch (e) {
      debugPrint('Error playing background music from URL: $e');
    }
  }

  /// Pause the currently playing music
  Future<void> pauseMusic() async {
    try {
      await _audioPlayer.pause();
      _isPlaying = false;
      notifyListeners();
    } catch (e) {
      debugPrint('Error pausing music: $e');
    }
  }

  /// Resume the paused music
  Future<void> resumeMusic() async {
    if (!_isMusicEnabled) {
      return;
    }

    try {
      await _audioPlayer.play();
      _isPlaying = true;
      notifyListeners();
    } catch (e) {
      debugPrint('Error resuming music: $e');
    }
  }

  /// Stop the music completely
  Future<void> stopMusic() async {
    try {
      await _audioPlayer.stop();
      _currentTrack = null;
      _isPlaying = false;
      notifyListeners();
    } catch (e) {
      debugPrint('Error stopping music: $e');
    }
  }

  /// Toggle music on/off
  Future<void> toggleMusic() async {
    _isMusicEnabled = !_isMusicEnabled;
    await _saveMusicPreference();
    
    if (_isMusicEnabled) {
      // If there was a track playing before, resume it
      if (_currentTrack != null) {
        await resumeMusic();
      }
    } else {
      await pauseMusic();
    }
    
    notifyListeners();
  }

  /// Set volume (0.0 to 1.0)
  Future<void> setVolume(double volume) async {
    try {
      await _audioPlayer.setVolume(volume.clamp(0.0, 1.0));
    } catch (e) {
      debugPrint('Error setting volume: $e');
    }
  }

  @override
  void dispose() {
    _audioPlayer.dispose();
    super.dispose();
  }

  /// Predefined music tracks for different screens
  static const String mapMusic = 'assets/music/map_theme.mp3';
  static const String startupMusic = 'assets/music/startup_theme.mp3';
  static const String levelMusic = 'assets/music/level_theme.mp3';
  
  /// Alternative: Use royalty-free music URLs (if local files not available)
  /// These are placeholder URLs - replace with actual royalty-free music
  static const String mapMusicUrl = 
      'https://www.soundhelix.com/examples/mp3/SoundHelix-Song-1.mp3';
  static const String startupMusicUrl = 
      'https://www.soundhelix.com/examples/mp3/SoundHelix-Song-2.mp3';
}
