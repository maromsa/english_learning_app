import 'dart:convert';

import 'package:crypto/crypto.dart';
import 'package:dio/dio.dart';
import 'package:english_learning_app/app_config.dart';
import 'package:english_learning_app/services/audio/bytes_audio_source.dart';
import 'package:english_learning_app/services/audio_settings.dart';
import 'package:english_learning_app/services/network/auth_token_provider.dart';
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
  /// In-memory MP3 cache, bounded to avoid unbounded growth in long sessions
  /// (each clip is tens of KB). Evicts oldest-inserted entries; the disk
  /// cache still holds everything.
  static const int _memoryCacheMaxEntries = 40;
  final Map<String, List<int>> _memoryCache = {};

  void _putInMemoryCache(String key, List<int> bytes) {
    // Re-inserting moves the key to the end (most recent) of insertion order.
    _memoryCache.remove(key);
    _memoryCache[key] = bytes;
    while (_memoryCache.length > _memoryCacheMaxEntries) {
      _memoryCache.remove(_memoryCache.keys.first);
    }
  }

  // Legacy fallback key — only populated when GOOGLE_TTS_API_KEY is provided
  // via --dart-define. Proxy is always tried first; this is only used if the
  // proxy call fails and a direct key happens to be present.
  String? get _apiKey {
    final key = AppConfig.googleTtsApiKey;
    return key.isNotEmpty ? key : null;
  }
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
  ///
  /// For English, tries ElevenLabs first; falls back to Google TTS.
  Future<bool> prefetch({
    required String text,
    bool isEnglish = false,
    SparkEmotion emotion = SparkEmotion.neutral,
    bool networkAllowed = true,
  }) async {
    if (text.trim().isEmpty) {
      return false;
    }

    // ElevenLabs fast path for English.
    if (isEnglish) {
      final elKey = _elevenLabsCacheKey(text, _elevenLabsVoiceId);
      if (_memoryCache.containsKey(elKey)) return true;
      final diskBytes = await _diskCache.read(elKey);
      if (diskBytes != null && diskBytes.isNotEmpty) {
        _putInMemoryCache(elKey, diskBytes);
        return true;
      }
      if (networkAllowed) {
        final ok = await _fetchElevenLabsViaProxy(
          cacheKey: elKey,
          text: text,
          voiceId: _elevenLabsVoiceId,
        );
        if (ok) return true;
      }
      // Fall through to Google TTS.
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
      _putInMemoryCache(key, diskBytes);
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

  /// The ElevenLabs voice ID used for English words.
  /// "Rachel" — clear, child-friendly American English voice.
  static const String _elevenLabsVoiceId = 'EXAVITQu4vr4xnSDxMaL';

  /// Speak text with emotion and language context.
  ///
  /// For English ([isEnglish]=true) the service first tries ElevenLabs (via
  /// proxy), then falls back to Google TTS.
  /// For Hebrew it goes straight to Google TTS.
  ///
  /// Returns `true` when audio was played, `false` when TTS was unavailable.
  Future<bool> speak({
    required String text,
    bool isEnglish = false,
    SparkEmotion emotion = SparkEmotion.neutral,
    bool networkAllowed = true,
  }) async {
    if (text.trim().isEmpty) return false;
    if (AudioSettings().muted) return false;

    try {
      // --- ElevenLabs path (English only) ---
      if (isEnglish) {
        final elKey = _elevenLabsCacheKey(text, _elevenLabsVoiceId);
        var bytes = _memoryCache[elKey];
        bytes ??= await _diskCache.read(elKey);
        if (bytes != null && bytes.isNotEmpty) {
          _putInMemoryCache(elKey, bytes);
          await _playBytes(bytes);
          return true;
        }
        if (networkAllowed) {
          final ok = await _fetchElevenLabsViaProxy(
            cacheKey: elKey,
            text: text,
            voiceId: _elevenLabsVoiceId,
          );
          if (ok) {
            final b = _memoryCache[elKey];
            if (b != null && b.isNotEmpty) {
              await _playBytes(b);
              return true;
            }
          }
        }
        // Fall through to Google TTS below.
      }

      // --- Google TTS path ---
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
        _putInMemoryCache(cacheKey, bytes);
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

  String _elevenLabsCacheKey(String text, String voiceId) {
    final signature = utf8.encode('el-$voiceId-$text');
    return 'el_${sha256.convert(signature)}';
  }

  /// Fetches English TTS from ElevenLabs via the authenticated proxy.
  Future<bool> _fetchElevenLabsViaProxy({
    required String cacheKey,
    required String text,
    required String voiceId,
  }) async {
    try {
      final idToken = await firebaseAuthTokenProvider();
      if (idToken == null) return false;

      final response = await _dio.postUri<Map<String, dynamic>>(
        AppConfig.geminiProxyEndpoint,
        data: {
          'mode': 'elevenlabs',
          'text': text,
          'voiceId': voiceId,
          'modelId': 'eleven_turbo_v2_5',
          'stability': 0.55,
          'similarityBoost': 0.80,
          'style': 0.0,
          'useSpeakerBoost': true,
        },
        options: Options(
          contentType: Headers.jsonContentType,
          responseType: ResponseType.json,
          headers: {'Authorization': 'Bearer $idToken'},
        ),
      );

      if (response.statusCode == 200) {
        return _cacheAudioContent(
          cacheKey,
          response.data?['audioContent'] as String?,
        );
      }
    } catch (e) {
      debugPrint('SparkVoiceService ElevenLabs TTS failed: $e');
    }
    return false;
  }

  /// Fetches synthesized audio, preferring the authenticated Gemini proxy so
  /// the Google TTS API key stays server-side. Falls back to a direct API
  /// call only when a key is still provided via --dart-define (legacy).
  Future<bool> _fetchAndCacheTts({
    required String cacheKey,
    required String ssmlText,
    required String languageCode,
    required String voiceName,
    required double speakingRate,
    required double pitch,
  }) async {
    final viaProxy = await _fetchTtsViaProxy(
      cacheKey: cacheKey,
      ssmlText: ssmlText,
      languageCode: languageCode,
      voiceName: voiceName,
      speakingRate: speakingRate,
      pitch: pitch,
    );
    if (viaProxy) {
      return true;
    }

    return _fetchTtsDirect(
      cacheKey: cacheKey,
      ssmlText: ssmlText,
      languageCode: languageCode,
      voiceName: voiceName,
      speakingRate: speakingRate,
      pitch: pitch,
    );
  }

  Future<bool> _fetchTtsViaProxy({
    required String cacheKey,
    required String ssmlText,
    required String languageCode,
    required String voiceName,
    required double speakingRate,
    required double pitch,
  }) async {
    try {
      final idToken = await firebaseAuthTokenProvider();
      if (idToken == null) {
        return false;
      }

      final response = await _dio.postUri<Map<String, dynamic>>(
        AppConfig.geminiProxyEndpoint,
        data: {
          'mode': 'tts',
          'ssml': ssmlText,
          'languageCode': languageCode,
          'voiceName': voiceName,
          'speakingRate': speakingRate,
          'pitch': pitch,
          'volumeGainDb': 2.0,
        },
        options: Options(
          contentType: Headers.jsonContentType,
          responseType: ResponseType.json,
          headers: {'Authorization': 'Bearer $idToken'},
        ),
      );

      if (response.statusCode == 200) {
        return _cacheAudioContent(
          cacheKey,
          response.data?['audioContent'] as String?,
        );
      }
    } catch (e) {
      debugPrint('SparkVoiceService proxy TTS failed: $e');
    }
    return false;
  }

  Future<bool> _fetchTtsDirect({
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
      final response = await _dio.post<Map<String, dynamic>>(
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
        return _cacheAudioContent(
          cacheKey,
          response.data?['audioContent'] as String?,
        );
      }
    } catch (e) {
      debugPrint('SparkVoiceService TTS fetch failed: $e');
    }
    return false;
  }

  Future<bool> _cacheAudioContent(String cacheKey, String? audioContent) async {
    if (audioContent == null || audioContent.isEmpty) {
      return false;
    }
    final bytes = base64.decode(audioContent);
    _putInMemoryCache(cacheKey, bytes);
    await _diskCache.write(cacheKey, bytes);
    return true;
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
