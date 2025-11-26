import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:english_learning_app/services/ai_image_validator.dart';
import 'package:english_learning_app/services/network/app_http_client.dart';
import 'package:flutter_test/flutter_test.dart';

import '../test_utils/test_http_adapter.dart';

void main() {
  group('HttpFunctionAiImageValidator', () {
    final sampleBytes = Uint8List.fromList(
      List<int>.generate(6, (index) => index),
    );
    final endpoint = Uri.parse('https://example.com/validate');

    test('returns approval when backend responds with approved flag', () async {
      late RequestOptions capturedRequest;
      final dio = Dio();
      dio.httpClientAdapter = TestHttpClientAdapter((options, stream) async {
        capturedRequest = options;
        final body = jsonEncode({'approved': true, 'confidence': 0.92});
        return ResponseBody.fromString(
          body,
          200,
          headers: {
            Headers.contentTypeHeader: ['application/json']
          },
        );
      });

      final validator = HttpFunctionAiImageValidator(
        endpoint,
        client: AppHttpClient(dio: dio),
      );

      final approved = await validator.validate(
        sampleBytes,
        'Apple',
        mimeType: 'image/png',
      );

      expect(approved, isTrue);
      expect(validator.lastConfidence, closeTo(0.92, 1e-6));
      expect(validator.lastApproval, isTrue);

      final payloadRaw = capturedRequest.data;
      final payload = payloadRaw is Map<String, dynamic>
          ? payloadRaw
          : jsonDecode(
              utf8.decode(payloadRaw as List<int>),
            ) as Map<String, dynamic>;
      expect(payload['word'], 'Apple');
      expect(payload['mimeType'], 'image/png');
      expect(payload['imageBase64'], base64Encode(sampleBytes));

      validator.dispose();
    });

    test(
      'falls back to confidence threshold when approval flag missing',
      () async {
        final validator = HttpFunctionAiImageValidator(
          endpoint,
          client: AppHttpClient(
            dio: Dio()
              ..httpClientAdapter = TestHttpClientAdapter(
                (_, __) async => ResponseBody.fromString(
                  jsonEncode({'confidence': '0.73'}),
                  200,
                  headers: {
                    Headers.contentTypeHeader: ['application/json']
                  },
                ),
              ),
          ),
        );

        final approved = await validator.validate(sampleBytes, 'Banana');

        expect(approved, isTrue);
        expect(validator.lastApproval, isTrue);
        expect(validator.lastConfidence, closeTo(0.73, 1e-6));

        validator.dispose();
      },
    );

    test('respects custom minimumConfidence threshold', () async {
      final validator = HttpFunctionAiImageValidator(
        endpoint,
        minimumConfidence: 0.8,
        client: AppHttpClient(
          dio: Dio()
            ..httpClientAdapter = TestHttpClientAdapter(
              (_, __) async => ResponseBody.fromString(
                jsonEncode({'confidence': 0.71}),
                200,
                headers: {
                  Headers.contentTypeHeader: ['application/json']
                },
              ),
            ),
        ),
      );

      final approved = await validator.validate(sampleBytes, 'Cherry');

      expect(approved, isFalse);
      expect(validator.lastApproval, isFalse);
      expect(validator.lastConfidence, closeTo(0.71, 1e-6));

      validator.dispose();
    });

    test('returns false on non-200 or malformed responses', () async {
      var firstCall = true;
      final validator = HttpFunctionAiImageValidator(
        endpoint,
        client: AppHttpClient(
          dio: Dio()
            ..httpClientAdapter = TestHttpClientAdapter((_, __) async {
              if (firstCall) {
                firstCall = false;
                return ResponseBody.fromString('nope', 500);
              }
              return ResponseBody.fromString(
                jsonEncode({'unexpected': true}),
                200,
                headers: {
                  Headers.contentTypeHeader: ['application/json']
                },
              );
            }),
        ),
      );

      final firstAttempt = await validator.validate(
        sampleBytes,
        'Durian',
        mimeType: 'image/jpeg',
      );
      expect(firstAttempt, isFalse);
      expect(validator.lastApproval, isNull);
      expect(validator.lastConfidence, isNull);

      final secondAttempt = await validator.validate(sampleBytes, 'Durian');
      expect(secondAttempt, isFalse);
      expect(validator.lastApproval, isNull);
      expect(validator.lastConfidence, isNull);

      validator.dispose();
    });
  });
}
