import 'package:dio/dio.dart';
import 'package:english_learning_app/services/gemini_proxy_response_cache.dart';
import 'package:english_learning_app/services/gemini_proxy_service.dart';
import 'package:english_learning_app/services/network/app_http_client.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('GeminiProxyService response cache', () {
    test('generateText uses cache on identical prompts', () async {
      var requestCount = 0;
      final dio = Dio();
      dio.interceptors.add(
        InterceptorsWrapper(
          onRequest: (options, handler) {
            requestCount++;
            handler.resolve(
              Response<Map<String, dynamic>>(
                data: <String, dynamic>{'text': 'cached story'},
                statusCode: 200,
                requestOptions: options,
              ),
            );
          },
        ),
      );

      final cache = GeminiProxyResponseCache(maxEntries: 8);
      final service = GeminiProxyService(
        Uri.parse('https://example.com/geminiProxy'),
        httpClient: AppHttpClient(dio: dio),
        responseCache: cache,
      );

      final first = await service.generateText('Tell me about cats');
      final second = await service.generateText('Tell me about cats');

      expect(first, 'cached story');
      expect(second, 'cached story');
      expect(requestCount, 1);
    });
  });
}
