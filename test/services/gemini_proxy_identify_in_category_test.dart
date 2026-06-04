import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:english_learning_app/models/object_identification_result.dart';
import 'package:english_learning_app/services/gemini_proxy_service.dart';
import 'package:english_learning_app/services/network/app_http_client.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('GeminiProxyService.buildCategoryIdentifyPrompt', () {
    test('includes target category and JSON error shapes', () {
      final prompt = GeminiProxyService.buildCategoryIdentifyPrompt('Fruits');
      expect(prompt, contains('Fruits'));
      expect(prompt, contains('category_mismatch'));
      expect(prompt, contains('{"word":'));
    });
  });

  group('GeminiProxyService.parseCategoryIdentifyResponse', () {
    test('parses success word JSON', () {
      final result = GeminiProxyService.parseCategoryIdentifyResponse(
        '{"word": "Apple"}',
      );
      expect(result, isA<ObjectIdentificationSuccess>());
      expect((result! as ObjectIdentificationSuccess).word, 'Apple');
    });

    test('parses category mismatch JSON', () {
      final result = GeminiProxyService.parseCategoryIdentifyResponse(
        '{"error": "category_mismatch", "identified": "Houseplant"}',
      );
      expect(result, isA<ObjectIdentificationCategoryMismatch>());
      expect(
        (result! as ObjectIdentificationCategoryMismatch).identified,
        'Houseplant',
      );
    });

    test('parses unclear JSON and legacy plain text', () {
      expect(
        GeminiProxyService.parseCategoryIdentifyResponse('{"error": "unclear"}'),
        isA<ObjectIdentificationUnclear>(),
      );
      expect(
        GeminiProxyService.parseCategoryIdentifyResponse('unclear'),
        isA<ObjectIdentificationUnclear>(),
      );
      expect(
        GeminiProxyService.parseCategoryIdentifyResponse('Banana'),
        isA<ObjectIdentificationSuccess>(),
      );
    });

    test('strips markdown code fences', () {
      final result = GeminiProxyService.parseCategoryIdentifyResponse(
        '```json\n{"word": "Orange"}\n```',
      );
      expect(result, isA<ObjectIdentificationSuccess>());
      expect((result! as ObjectIdentificationSuccess).word, 'Orange');
    });
  });

  group('GeminiProxyService.identifyObjectInCategory', () {
    test('sends category prompt and parses mismatch from proxy', () async {
      final dio = Dio();
      dio.interceptors.add(
        InterceptorsWrapper(
          onRequest: (options, handler) {
            final body = options.data as Map<String, dynamic>;
            expect(body['mode'], 'identify');
            final prompt = body['prompt'] as String;
            expect(prompt, contains('Fruits'));
            expect(prompt, contains('category_mismatch'));

            handler.resolve(
              Response<Map<String, dynamic>>(
                data: <String, dynamic>{
                  'text': jsonEncode({
                    'error': 'category_mismatch',
                    'identified': 'Houseplant',
                  }),
                },
                statusCode: 200,
                requestOptions: options,
              ),
            );
          },
        ),
      );

      final service = GeminiProxyService(
        Uri.parse('https://example.com/geminiProxy'),
        httpClient: AppHttpClient(dio: dio),
      );

      final result = await service.identifyObjectInCategory(
        Uint8List.fromList(<int>[1, 2, 3]),
        targetCategory: 'Fruits',
      );

      expect(result, isA<ObjectIdentificationCategoryMismatch>());
      expect(
        (result! as ObjectIdentificationCategoryMismatch).identified,
        'Houseplant',
      );
    });
  });
}
