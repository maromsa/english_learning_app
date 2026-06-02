import 'dart:convert';

import 'package:crypto/crypto.dart';
import 'package:dio/dio.dart';
import 'package:english_learning_app/app_config.dart';
import 'package:english_learning_app/services/audio/bytes_audio_source.dart';
import 'package:english_learning_app/services/spark_voice_disk_cache.dart';
import 'package:english_learning_app/services/spark_voice_disk_cache_export.dart';
import 'package:english_learning_app/services/tts_voice_config.dart';
import 'package:flutter/foundation.dart';
import 'package:just_audio/just_audio.dart';

/// Emotion states for Spark's voice
enum SparkEmotion { neutral, happy, excited, empathetic, teaching }

/// Enhanced TTS service optimized for children.
/// Uses Google Cloud TTS with SSML; plays MP3 bytes via [just_audio] on all platforms.
class SparkVoiceService {
  static final SparkVoiceService _instance = SparkVoiceService._internal();
  factory SparkVoiceService() => _instance;
  SparkVoiceService._internal();

  final AudioPlayer _player = AudioPlayer();
  final Dio _dio = Dio();
  final SparkVoiceDiskCache _diskCache = createSparkVoiceDiskCache();
  final Map<String, List<int>> _memoryCache = {};

  String? get _apiKey =>
      AppConfig.hasGoogleTts ? AppConfig.googleTtsApiKey : null;
  final String _endpoint =
      'https://texttospeech.googleapis.com/v1/text:synthesize';

  String _cacheKey(
    String ssmlText,
    String voiceName,
    double pitch,
    double rate,
  ) {
    final signature = utf8.encode('$ssmlText-$voiceName-$pitch-$rate');
    return sha256.convert(signature).toString();
  }

  /// Pre-download TTS audio for offline practice packs.
  Future<bool> prefetch({
    required String text,
    bool isEnglish = false,
    SparkEmotion emotion = SparkEmotion.neutral,
    bool networkAllowed = true,
  }) async {
    if (text.trim().isEmpty || _apiKey == null) {
      return false;
    }

    final languageCode = TtsVoiceConfig.languageCodeFor(isEnglish: isEnglish);
    final voiceName = TtsVoiceConfig.ssmlVoiceFor(isEnglish: isEnglish);
    const speakingRate = 0.85;
    const pitch = 2.0;
    final ssmlText = _generateSSML(text, emotion, speakingRate, pitch);
    final key = _cacheKey(ssmlText, voiceName, pitch, speakingRate);

    if (_memoryCache.containsKey(key)) {
      return true;
    }
    final diskBytes = await _diskCache.read(key);
    if (diskBytes != null && diskBytes.isNotEmpty) {
      _memoryCache[key] = diskBytes;
      return true;
    }
    if (!networkAllowed) {
      return false;
    }

    return _fetchAndCacheTts(
      cacheKey: key,
      ssmlText: ssmlText,
      languageCode: languageCode,
      voiceName: voiceName,
      speakingRate: speakingRate,
      pitch: pitch,
    );
  }

  /// Speak text with emotion and language context.
  /// Returns `true` when audio was played, `false` when TTS was unavailable.
  Future<bool> speak({
    required String text,
    bool isEnglish = false,
    SparkEmotion emotion = SparkEmotion.neutral,
    bool networkAllowed = true,
  }) async {
    if (text.trim().isEmpty) return false;

    final apiKey = _apiKey;
    if (apiKey == null) {
      debugPrint('Google TTS API key not available, using fallback');
      return false;
    }

    try {
      final languageCode = TtsVoiceConfig.languageCodeFor(isEnglish: isEnglish);
      final voiceName = TtsVoiceConfig.ssmlVoiceFor(isEnglish: isEnglish);

      const double speakingRate = 0.85;
      const double pitch = 2.0;

      final String ssmlText =
          _generateSSML(text, emotion, speakingRate, pitch);
      final cacheKey = _cacheKey(ssmlText, voiceName, pitch, speakingRate);

      var bytes = _memoryCache[cacheKey];
      bytes ??= await _diskCache.read(cacheKey);
      if (bytes != null && bytes.isNotEmpty) {
        _memoryCache[cacheKey] = bytes;
        await _playBytes(bytes);
        return true;
      }

      if (!networkAllowed) {
        debugPrint('SparkVoiceService: offline, no cached audio for "$text"');
        return false;
      }

      final cached = await _fetchAndCacheTts(
        cacheKey: cacheKey,
        ssmlText: ssmlText,
        languageCode: languageCode,
        voiceName: voiceName,
        speakingRate: speakingRate,
        pitch: pitch,
      );
      if (!cached) {
        return false;
      }

      bytes = _memoryCache[cacheKey];
      if (bytes == null || bytes.isEmpty) {
        return false;
      }
      await _playBytes(bytes);
      return true;
    } catch (e, st) {
      debugPrint('SparkVoiceService Error: $e');
      debugPrint('$st');
      return false;
    }
  }

  Future<void> _playBytes(List<int> bytes) async {
    await _player.stop();
    await _player.setAudioSource(BytesAudioSource(bytes));
    await _player.play();
  }

  Future<bool> _fetchAndCacheTts({
    required String cacheKey,
    required String ssmlText,
    required String languageCode,
    required String voiceName,
    required double speakingRate,
    required double pitch,
  }) async {
    final apiKey = _apiKey;
    if (apiKey == null) {
      return false;
    }

    try {
      final response = await _dio.post(
        '$_endpoint?key=$apiKey',
        data: {
          'input': {'ssml': ssmlText},
          'voice': {
            'languageCode': languageCode,
            'name': voiceName,
            'ssmlGender': 'FEMALE',
          },
          'audioConfig': {
            'audioEncoding': 'MP3',
            'speakingRate': speakingRate,
            'pitch': pitch,
            'volumeGainDb': 2.0,
            'effectsProfileId': ['headphone-class-device'],
            'sampleRateHertz': 24000,
          },
        },
        options: Options(
          contentType: Headers.jsonContentType,
          responseType: ResponseType.json,
        ),
      );

      if (response.statusCode == 200) {
        final audioContent = response.data?['audioContent'] as String?;
        if (audioContent != null && audioContent.isNotEmpty) {
          final bytes = base64.decode(audioContent);
          _memoryCache[cacheKey] = bytes;
          await _diskCache.write(cacheKey, bytes);
          return true;
        }
      }
    } catch (e) {
      debugPrint('SparkVoiceService TTS fetch failed: $e');
    }
    return false;
  }

  /// Generate SSML with emotional prosody
  String _generateSSML(
      String text, SparkEmotion emotion, double rate, double pitch) {
    switch (emotion) {
      case SparkEmotion.excited:
        pitch += 4.0;
        rate = 0.95;
        break;
      case SparkEmotion.empathetic:
        pitch -= 1.0;
        rate = 0.75;
        break;
      case SparkEmotion.teaching:
        rate = 0.75;
        break;
      case SparkEmotion.happy:
        pitch += 2.0;
        rate = 0.88;
        break;
      case SparkEmotion.neutral:
        break;
    }

    final String escapedText = text
        .replaceAll('&', '&amp;')
        .replaceAll('<', '&lt;')
        .replaceAll('>', '&gt;')
        .replaceAll('"', '&quot;')
        .replaceAll("'", '&apos;');

    return '''
<speak>
  <prosody rate="$rate" pitch="${pitch}st">
    $escapedText
  </prosody>
</speak>
''';
  }

  Future<void> stop() async {
    await _player.stop();
  }

  Future<void> dispose() async {
    await _player.dispose();
    _dio.close();
  }
}
