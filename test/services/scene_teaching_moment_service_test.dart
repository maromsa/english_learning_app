import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:english_learning_app/models/scavenger_hunt_challenge.dart';
import 'package:english_learning_app/services/gemini_proxy_service.dart';
import 'package:english_learning_app/services/network/app_http_client.dart';
import 'package:english_learning_app/services/scene_teaching_moment_service.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const challenge = ScavengerHuntChallenge(
    id: 'ball',
    promptHebrew: 'מצאו כדור!',
    validationWord: 'ball',
    kind: ScavengerChallengeKind.object,
    emoji: '⚽',
  );

  group('SceneTeachingMomentService.fetchForSuccessPhoto', () {
    test('returns parsed moment when scene_description succeeds', () async {
      final innerJson = jsonEncode({
        'description': 'תיאור יפה',
        'targetObjects': ['ball', 'shoe'],
        'hebrewTeachingPoints': ['כדור באנגלית: ball'],
      });

      final dio = Dio();
      dio.interceptors.add(
        InterceptorsWrapper(
          onRequest: (options, handler) {
            handler.resolve(
              Response<Map<String, dynamic>>(
                data: <String, dynamic>{'text': innerJson},
                statusCode: 200,
                requestOptions: options,
              ),
            );
          },
        ),
      );

      final proxy = GeminiProxyService(
        Uri.parse('https://example.com/geminiProxy'),
        httpClient: AppHttpClient(dio: dio),
      );
      final service = SceneTeachingMomentService(proxy);

      final moment = await service.fetchForSuccessPhoto(
        Uint8List.fromList(<int>[1, 2, 3]),
        challenge,
      );

      expect(moment.isFallback, isFalse);
      expect(moment.description, 'תיאור יפה');
      expect(moment.targetObjects, contains('ball'));
    });

    test('returns fallback when proxy returns null', () async {
      final dio = Dio();
      dio.interceptors.add(
        InterceptorsWrapper(
          onRequest: (options, handler) {
            handler.resolve(
              Response<Map<String, dynamic>>(
                data: null,
                statusCode: 500,
                requestOptions: options,
              ),
            );
          },
        ),
      );

      final proxy = GeminiProxyService(
        Uri.parse('https://example.com/geminiProxy'),
        httpClient: AppHttpClient(dio: dio),
      );
      final service = SceneTeachingMomentService(proxy);

      final moment = await service.fetchForSuccessPhoto(
        Uint8List.fromList(<int>[1]),
        challenge,
      );

      expect(moment.isFallback, isTrue);
      expect(moment.description, isNotEmpty);
    });

    test('returns fallback on timeout', () async {
      final dio = Dio();
      dio.interceptors.add(
        InterceptorsWrapper(
          onRequest: (options, handler) async {
            await Future<void>.delayed(const Duration(seconds: 2));
            handler.resolve(
              Response<Map<String, dynamic>>(
                data: <String, dynamic>{'text': '{}'},
                statusCode: 200,
                requestOptions: options,
              ),
            );
          },
        ),
      );

      final proxy = GeminiProxyService(
        Uri.parse('https://example.com/geminiProxy'),
        httpClient: AppHttpClient(dio: dio),
      );
      final service = SceneTeachingMomentService(
        proxy,
        sceneDescriptionTimeout: const Duration(milliseconds: 50),
      );

      final moment = await service.fetchForSuccessPhoto(
        Uint8List.fromList(<int>[1]),
        challenge,
      );

      expect(moment.isFallback, isTrue);
    });
  });
}
