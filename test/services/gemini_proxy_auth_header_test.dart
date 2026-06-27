import 'package:dio/dio.dart';
import 'package:english_learning_app/services/gemini_proxy_service.dart';
import 'package:english_learning_app/services/network/app_http_client.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  Dio captureHeadersDio(void Function(RequestOptions options) onRequest) {
    final dio = Dio();
    dio.interceptors.add(
      InterceptorsWrapper(
        onRequest: (options, handler) {
          onRequest(options);
          handler.resolve(
            Response<Map<String, dynamic>>(
              data: <String, dynamic>{'text': 'ok'},
              statusCode: 200,
              requestOptions: options,
            ),
          );
        },
      ),
    );
    return dio;
  }

  group('GeminiProxyService authentication header', () {
    test('sends Authorization Bearer header when a token is available',
        () async {
      String? capturedAuth;
      final dio = captureHeadersDio((options) {
        capturedAuth = options.headers['Authorization'] as String?;
      });

      final service = GeminiProxyService(
        Uri.parse('https://example.com/geminiProxy'),
        httpClient: AppHttpClient(dio: dio),
        enableResponseCache: false,
        authTokenProvider: () async => 'fake-id-token',
      );

      final result = await service.generateText('hello');

      expect(result, 'ok');
      expect(capturedAuth, 'Bearer fake-id-token');
    });

    test('omits Authorization header when no token is available', () async {
      bool hasAuthHeader = true;
      final dio = captureHeadersDio((options) {
        hasAuthHeader = options.headers.containsKey('Authorization');
      });

      final service = GeminiProxyService(
        Uri.parse('https://example.com/geminiProxy'),
        httpClient: AppHttpClient(dio: dio),
        enableResponseCache: false,
        authTokenProvider: () async => null,
      );

      final result = await service.generateText('hello');

      expect(result, 'ok');
      expect(hasAuthHeader, isFalse);
    });

    test('returns null gracefully on a 401 from the proxy', () async {
      final dio = Dio();
      dio.interceptors.add(
        InterceptorsWrapper(
          onRequest: (options, handler) {
            handler.reject(
              DioException(
                requestOptions: options,
                response: Response<Map<String, dynamic>>(
                  data: <String, dynamic>{'error': 'Unauthorized'},
                  statusCode: 401,
                  requestOptions: options,
                ),
                type: DioExceptionType.badResponse,
              ),
            );
          },
        ),
      );

      final service = GeminiProxyService(
        Uri.parse('https://example.com/geminiProxy'),
        httpClient: AppHttpClient(dio: dio),
        enableResponseCache: false,
        authTokenProvider: () async => 'expired-token',
      );

      final result = await service.generateText('hello');

      expect(result, isNull);
    });
  });
}
