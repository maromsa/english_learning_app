import 'dart:convert';
import 'dart:io';
import 'package:crypto/crypto.dart';
import 'package:dio/dio.dart';
import 'package:english_learning_app/app_config.dart';
import 'package:flutter/foundation.dart';
import 'package:just_audio/just_audio.dart';
import 'package:path_provider/path_provider.dart';

/// Emotion states for Spark's voice
enum SparkEmotion { neutral, happy, excited, empathetic, teaching }

/// Enhanced TTS service optimized for children
/// Uses Google Cloud TTS with SSML for emotional control and caching
class SparkVoiceService {
  static final SparkVoiceService _instance = SparkVoiceService._internal();
  factory SparkVoiceService() => _instance;
  SparkVoiceService._internal();

  final AudioPlayer _player = AudioPlayer();
  final Dio _dio = Dio();
  
  String? get _apiKey => AppConfig.hasGoogleTts ? AppConfig.googleTtsApiKey : null;
  final String _endpoint = "https://texttospeech.googleapis.com/v1/text:synthesize";

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

    final languageCode = isEnglish ? 'en-US' : 'he-IL';
    final voiceName =
        isEnglish ? 'en-US-Neural2-F' : 'he-IL-Neural2-A';
    var speakingRate = 0.85;
    var pitch = 2.0;
    final ssmlText = _generateSSML(text, emotion, speakingRate, pitch);
    final filePath =
        await _getCachePath(ssmlText, voiceName, pitch, speakingRate);
    final file = File(filePath);
    if (await file.exists()) {
      return true;
    }
    if (!networkAllowed) {
      return false;
    }

    return _fetchAndCacheTts(
      ssmlText: ssmlText,
      languageCode: languageCode,
      voiceName: voiceName,
      speakingRate: speakingRate,
      pitch: pitch,
      file: file,
    );
  }

  /// Speak text with emotion and language context
  Future<void> speak({
    required String text,
    bool isEnglish = false,
    SparkEmotion emotion = SparkEmotion.neutral,
    bool networkAllowed = true,
  }) async {
    if (text.trim().isEmpty) return;

    try {
      // If no Google TTS API key, fall back to FlutterTts
      if (_apiKey == null) {
        debugPrint('Google TTS API key not available, using fallback');
        return;
      }

      // 1. Configure Voice based on context
      String languageCode = isEnglish ? 'en-US' : 'he-IL';
      String voiceName = isEnglish 
          ? 'en-US-Neural2-F'  // Female, warm, clear
          : 'he-IL-Neural2-A';  // Female, friendly

      // 2. Adjust Prosody (Child-friendly settings)
      double speakingRate = 0.85; // Slower for kids
      double pitch = 2.0; // Higher pitch = Friendlier/Younger

      // 3. Apply Emotional SSML
      String ssmlText = _generateSSML(text, emotion, speakingRate, pitch);

      // 4. Check Cache
      final filePath = await _getCachePath(ssmlText, voiceName, pitch, speakingRate);
      final file = File(filePath);

      if (await file.exists()) {
        await _player.setFilePath(filePath);
        await _player.play();
        return;
      }

      if (!networkAllowed) {
        debugPrint('SparkVoiceService: offline, no cached audio for "$text"');
        return;
      }

      // 5. Fetch from Google API if not cached
      final cached = await _fetchAndCacheTts(
        ssmlText: ssmlText,
        languageCode: languageCode,
        voiceName: voiceName,
        speakingRate: speakingRate,
        pitch: pitch,
        file: file,
      );
      if (cached) {
        await _player.setFilePath(filePath);
        await _player.play();
      }
    } catch (e) {
      debugPrint("SparkVoiceService Error: $e");
      // Fallback will be handled by caller
    }
  }

  Future<bool> _fetchAndCacheTts({
    required String ssmlText,
    required String languageCode,
    required String voiceName,
    required double speakingRate,
    required double pitch,
    required File file,
  }) async {
    try {
      final response = await _dio.post(
        '$_endpoint?key=$_apiKey',
        data: {
          "input": {"ssml": ssmlText},
          "voice": {
            "languageCode": languageCode,
            "name": voiceName,
            "ssmlGender": "FEMALE",
          },
          "audioConfig": {
            "audioEncoding": "MP3",
            "speakingRate": speakingRate,
            "pitch": pitch,
            "volumeGainDb": 2.0,
            "effectsProfileId": ["headphone-class-device"],
            "sampleRateHertz": 24000,
          }
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
          await file.writeAsBytes(bytes);
          return true;
        }
      }
    } catch (e) {
      debugPrint('SparkVoiceService TTS fetch failed: $e');
    }
    return false;
  }

  /// Generate SSML with emotional prosody
  String _generateSSML(String text, SparkEmotion emotion, double rate, double pitch) {
    // Adjust parameters based on emotion
    switch (emotion) {
      case SparkEmotion.excited:
        pitch += 4.0;
        rate = 0.95; // Faster when excited
        break;
      case SparkEmotion.empathetic:
        pitch -= 1.0;
        rate = 0.75; // Slower, softer
        break;
      case SparkEmotion.teaching:
        rate = 0.75; // Very clear for English words
        break;
      case SparkEmotion.happy:
        pitch += 2.0;
        rate = 0.88;
        break;
      case SparkEmotion.neutral:
        break;
    }

    // Escape XML special characters
    String escapedText = text
        .replaceAll('&', '&amp;')
        .replaceAll('<', '&lt;')
        .replaceAll('>', '&gt;')
        .replaceAll('"', '&quot;')
        .replaceAll("'", '&apos;');

    // SSML allows us to control prosody (pitch, rate, volume)
    return """
<speak>
  <prosody rate="$rate" pitch="${pitch}st">
    $escapedText
  </prosody>
</speak>
""";
  }

  /// Get cache path for TTS audio
  Future<String> _getCachePath(String text, String voiceName, double pitch, double rate) async {
    final dir = await getTemporaryDirectory();
    // Create a unique signature for this specific request
    final signature = utf8.encode("$text-$voiceName-$pitch-$rate");
    final hash = sha256.convert(signature).toString();
    return '${dir.path}/tts_$hash.mp3';
  }

  /// Stop current speech
  Future<void> stop() async {
    await _player.stop();
  }

  /// Dispose resources
  Future<void> dispose() async {
    await _player.dispose();
    _dio.close();
  }
}

