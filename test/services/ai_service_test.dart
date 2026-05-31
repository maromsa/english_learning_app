import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:english_learning_app/l10n/spark_strings.dart';
import 'package:english_learning_app/services/ai_service.dart';
import 'package:english_learning_app/services/network/app_http_client.dart';
import 'package:english_learning_app/widgets/ai_generate_panel.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../test_utils/test_http_adapter.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const baseUrl = 'https://english-app-ai.onrender.com';
  const request = AiGenerateRequest(
    prompt: 'apple',
    imageBase64: 'aGVsbG8=',
    crop: AiImageCropRect(x: 0.1, y: 0.2, width: 0.6, height: 0.6),
  );

  group('AiService.generate', () {
    test('retries 502 up to three times then throws server_overloaded', () async {
      var attempts = 0;
      final dio = Dio();
      dio.httpClientAdapter = TestHttpClientAdapter((options, _) async {
        attempts++;
        expect(
          options.uri.path,
          endsWith('/api/v1/generate'),
        );
        return ResponseBody.fromString(
          'Bad Gateway',
          502,
          headers: {
            Headers.contentTypeHeader: ['text/plain'],
          },
        );
      });

      final service = AiService(
        baseUrl: Uri.parse(baseUrl),
        httpClient: AppHttpClient(dio: dio),
        max502Attempts: 3,
      );

      await expectLater(
        service.generate(request),
        throwsA(
          isA<AiServiceException>().having(
            (error) => error.code,
            'code',
            'server_overloaded',
          ),
        ),
      );
      expect(attempts, 3);
    });

    test('maps 503 to server_overloaded without retrying', () async {
      var attempts = 0;
      final dio = Dio();
      dio.httpClientAdapter = TestHttpClientAdapter((options, _) async {
        attempts++;
        return ResponseBody.fromString('Service Unavailable', 503);
      });

      final service = AiService(
        baseUrl: Uri.parse(baseUrl),
        httpClient: AppHttpClient(dio: dio),
      );

      await expectLater(
        service.generate(request),
        throwsA(
          isA<AiServiceException>().having(
            (error) => error.code,
            'code',
            'server_overloaded',
          ),
        ),
      );
      expect(attempts, 1);
    });

    test('maps 504 to backend_unavailable', () async {
      final dio = Dio();
      dio.httpClientAdapter = TestHttpClientAdapter((_, __) async {
        return ResponseBody.fromString('Gateway Timeout', 504);
      });

      final service = AiService(
        baseUrl: Uri.parse(baseUrl),
        httpClient: AppHttpClient(dio: dio),
      );

      await expectLater(
        service.generate(request),
        throwsA(
          isA<AiServiceException>().having(
            (error) => error.code,
            'code',
            'backend_unavailable',
          ),
        ),
      );
    });

    test('succeeds when a later 502 retry returns 200', () async {
      var attempts = 0;
      final dio = Dio();
      dio.httpClientAdapter = TestHttpClientAdapter((options, _) async {
        attempts++;
        if (attempts < 2) {
          return ResponseBody.fromString('Bad Gateway', 502);
        }

        final body = jsonEncode({
          'imageUrl': 'https://cdn.example.com/apple.png',
        });
        return ResponseBody.fromString(
          body,
          200,
          headers: {
            Headers.contentTypeHeader: ['application/json'],
          },
        );
      });

      final service = AiService(
        baseUrl: Uri.parse(baseUrl),
        httpClient: AppHttpClient(dio: dio),
        max502Attempts: 3,
      );

      final result = await service.generate(request);
      expect(result.imageUrl, 'https://cdn.example.com/apple.png');
      expect(attempts, 2);
    });

    test('maps connection errors to network_error', () async {
      final dio = Dio();
      dio.httpClientAdapter = TestHttpClientAdapter((_, __) async {
        throw DioException(
          requestOptions: RequestOptions(path: '/api/v1/generate'),
          type: DioExceptionType.connectionError,
        );
      });

      final service = AiService(
        baseUrl: Uri.parse(baseUrl),
        httpClient: AppHttpClient(dio: dio),
      );

      await expectLater(
        service.generate(request),
        throwsA(
          isA<AiServiceException>().having(
            (error) => error.code,
            'code',
            'network_error',
          ),
        ),
      );
    });
  });

  group('AiGeneratePanel — 502 regression', () {
    testWidgets(
      'dismisses spinner and shows localized message after gateway failure',
      (tester) async {
        final dio = Dio();
        dio.httpClientAdapter = TestHttpClientAdapter((_, __) async {
          return ResponseBody.fromString('Bad Gateway', 502);
        });

        final service = AiService(
          baseUrl: Uri.parse(baseUrl),
          httpClient: AppHttpClient(dio: dio),
          max502Attempts: 1,
        );

        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: AiGeneratePanel(
                service: service,
                request: request,
              ),
            ),
          ),
        );

        await tester.tap(find.text('צרו תמונה'));
        await tester.pump();
        expect(find.byType(CircularProgressIndicator), findsOneWidget);

        await tester.pumpAndSettle();

        expect(find.byType(CircularProgressIndicator), findsNothing);
        expect(find.text(SparkStrings.aiServerOverloaded), findsOneWidget);
        expect(find.byKey(const Key('ai_generate_error')), findsOneWidget);

        final state = tester.state<State<StatefulWidget>>(
          find.byType(AiGeneratePanel),
        ) as AiGeneratePanelState;
        expect(state.isGenerating, isFalse);
        expect(state.errorMessage, SparkStrings.aiServerOverloaded);
      },
    );
  });
}
