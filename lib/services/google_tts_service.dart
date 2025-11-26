import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';

import 'network/app_http_client.dart';

class GoogleTtsService {
  GoogleTtsService({
    required String apiKey,
    List<String>? voicePreference,
    AppHttpClient? httpClient,
    this.languageCode = 'he-IL',
    this.speakingRate = 0.8,
    this.pitch = 0.0,
    this.volumeGainDb = 2.0,
  })  : _apiKey = apiKey,
        _voices = voicePreference ??
            const [
              'he-IL-Standard-B',
              'he-IL-Neural2-B',
              'he-IL-Wavenet-B',
            ],
        _httpClient = httpClient ??
            AppHttpClient(
              connectTimeout: const Duration(seconds: 10),
              receiveTimeout: const Duration(seconds: 10),
              sendTimeout: const Duration(seconds: 10),
            );

  final String _apiKey;
  final List<String> _voices;
  final AppHttpClient _httpClient;

  final String languageCode;
  final double speakingRate;
  final double pitch;
  final double volumeGainDb;

  Future<Uint8List?> synthesize({
    required String text,
    Iterable<String>? overrideVoices,
    String? languageCodeOverride,
    double? speakingRateOverride,
    double? pitchOverride,
    double? volumeGainOverride,
  }) async {
    final trimmed = text.trim();
    if (trimmed.isEmpty) {
      return null;
    }

    final resolvedLanguage = languageCodeOverride ?? languageCode;
    final resolvedRate = speakingRateOverride ?? speakingRate;
    final resolvedPitch = pitchOverride ?? pitch;
    final resolvedVolume = volumeGainOverride ?? volumeGainDb;
    final voices = overrideVoices?.toList(growable: false) ?? _voices;
    for (final voice in voices) {
      try {
        final response = await _httpClient.dio.postUri<Map<String, dynamic>>(
          Uri.parse(
            'https://texttospeech.googleapis.com/v1/text:synthesize?key=$_apiKey',
          ),
          data: {
            'input': {'text': trimmed},
            'voice': {
              'languageCode': resolvedLanguage,
              'name': voice,
              'ssmlGender': 'FEMALE',
            },
            'audioConfig': {
              'audioEncoding': 'MP3',
              'speakingRate': resolvedRate,
              'pitch': resolvedPitch,
              'volumeGainDb': resolvedVolume,
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
          if (audioContent == null || audioContent.isEmpty) {
            continue;
          }
          return base64Decode(audioContent);
        } else {
          debugPrint(
            'GoogleTtsService voice $voice failed '
            'with status ${response.statusCode}',
          );
        }
      } on DioException catch (error, stackTrace) {
        debugPrint('GoogleTtsService voice $voice error: ${error.message}');
        debugPrint('$stackTrace');
      }
    }

    return null;
  }

  void dispose() {
    _httpClient.close();
  }
}
