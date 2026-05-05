import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:english_learning_app/services/gemini_proxy_service.dart';
import 'package:english_learning_app/services/network/app_http_client.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('GeminiProxyService.describeSceneAndQuizChild', () {
    test('parses structured JSON from text field when available', () async {
      final innerJson = jsonEncode({
        'description': 'תיאור ידידותי של הסצנה',
        'targetObjects': ['ball', 'dog'],
        'hebrewTeachingPoints': ['הסבר 1', 'הסבר 2'],
        'quizQuestions': ['איפה הכדור?', 'תוכל לומר dog באנגלית?'],
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

      final client = AppHttpClient(dio: dio);
      final service = GeminiProxyService(
        Uri.parse('https://example.com/geminiProxy'),
        httpClient: client,
      );

      final result = await service.describeSceneAndQuizChild(
        Uint8List.fromList(<int>[1, 2, 3]),
      );

      expect(result, isNotNull);
      expect(result!['description'], 'תיאור ידידותי של הסצנה');
      expect(result['targetObjects'], contains('ball'));
    });

    test('falls back to simple description map when JSON cannot be parsed',
        () async {
      final dio = Dio();
      dio.interceptors.add(
        InterceptorsWrapper(
          onRequest: (options, handler) {
            handler.resolve(
              Response<Map<String, dynamic>>(
                data: <String, dynamic>{'text': 'Just a plain description'},
                statusCode: 200,
                requestOptions: options,
              ),
            );
          },
        ),
      );

      final client = AppHttpClient(dio: dio);
      final service = GeminiProxyService(
        Uri.parse('https://example.com/geminiProxy'),
        httpClient: client,
      );

      final result = await service.describeSceneAndQuizChild(
        Uint8List.fromList(<int>[1, 2, 3]),
      );

      expect(result, isNotNull);
      expect(result!['description'], contains('Just a plain description'));
    });
  });
}

