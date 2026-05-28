import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:english_learning_app/services/gemini_proxy_service.dart';
import 'package:english_learning_app/services/network/app_http_client.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('GeminiProxyService.validateImageMatch', () {
    test('parses approved and confidence from validate response', () async {
      final dio = Dio();
      dio.interceptors.add(
        InterceptorsWrapper(
          onRequest: (options, handler) {
            expect(options.data, isA<Map<String, dynamic>>());
            final body = options.data as Map<String, dynamic>;
            expect(body['word'], 'apple');
            expect(body.containsKey('mode'), isFalse);

            handler.resolve(
              Response<Map<String, dynamic>>(
                data: <String, dynamic>{
                  'approved': true,
                  'confidence': 0.92,
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

      final result = await service.validateImageMatch(
        Uint8List.fromList(<int>[1, 2, 3]),
        'apple',
      );

      expect(result, isNotNull);
      expect(result!.approved, isTrue);
      expect(result.confidence, closeTo(0.92, 0.001));
    });

    test('returns null when response is missing approved', () async {
      final dio = Dio();
      dio.interceptors.add(
        InterceptorsWrapper(
          onRequest: (options, handler) {
            handler.resolve(
              Response<Map<String, dynamic>>(
                data: <String, dynamic>{'confidence': 0.5},
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

      final result = await service.validateImageMatch(
        Uint8List.fromList(<int>[1]),
        'ball',
      );

      expect(result, isNull);
    });
  });
}
