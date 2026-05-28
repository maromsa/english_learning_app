import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:english_learning_app/data/scavenger_hunt_catalog.dart';
import 'package:english_learning_app/models/scavenger_hunt_challenge.dart';
import 'package:english_learning_app/services/gemini_proxy_service.dart';
import 'package:english_learning_app/services/network/app_http_client.dart';
import 'package:english_learning_app/services/scavenger_hunt_service.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('ScavengerHuntCatalog', () {
    test('pickSession returns distinct challenges', () {
      final session = ScavengerHuntCatalog.pickSession(count: 5);
      expect(session.length, 5);
      expect(session.map((c) => c.id).toSet().length, 5);
    });
  });

  group('ScavengerHuntService.validateFind', () {
    test('approves when proxy returns high confidence', () async {
      final dio = Dio();
      dio.interceptors.add(
        InterceptorsWrapper(
          onRequest: (options, handler) {
            handler.resolve(
              Response<Map<String, dynamic>>(
                data: <String, dynamic>{
                  'approved': true,
                  'confidence': 0.9,
                },
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
      final service = ScavengerHuntService(proxy);

      const challenge = ScavengerHuntChallenge(
        id: 'test',
        promptHebrew: 'מצאו תפוח',
        validationWord: 'apple',
        kind: ScavengerChallengeKind.object,
        emoji: '🍎',
      );

      final result = await service.validateFind(
        Uint8List.fromList(<int>[1]),
        challenge,
      );

      expect(result.approved, isTrue);
    });

    test('rejects when confidence is below threshold', () async {
      final dio = Dio();
      dio.interceptors.add(
        InterceptorsWrapper(
          onRequest: (options, handler) {
            handler.resolve(
              Response<Map<String, dynamic>>(
                data: <String, dynamic>{
                  'approved': true,
                  'confidence': 0.1,
                },
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
      final service = ScavengerHuntService(proxy);

      const challenge = ScavengerHuntChallenge(
        id: 'test',
        promptHebrew: 'מצאו כחול',
        validationWord: 'blue',
        kind: ScavengerChallengeKind.color,
        emoji: '💙',
      );

      final result = await service.validateFind(
        Uint8List.fromList(<int>[1]),
        challenge,
      );

      expect(result.approved, isFalse);
    });
  });
}
