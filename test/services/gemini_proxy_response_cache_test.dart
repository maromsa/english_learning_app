import 'package:english_learning_app/services/gemini_proxy_response_cache.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('GeminiProxyResponseCache', () {
    test('cacheKeyForPayload is stable for equivalent maps', () {
      final a = GeminiProxyResponseCache.cacheKeyForPayload({
        'mode': 'text',
        'prompt': 'hello',
        'system_instruction': 'be kind',
      });
      final b = GeminiProxyResponseCache.cacheKeyForPayload({
        'system_instruction': 'be kind',
        'prompt': 'hello',
        'mode': 'text',
      });

      expect(a, isNotNull);
      expect(a, b);
    });

    test('cacheKeyForPayload returns null for image payloads', () {
      final key = GeminiProxyResponseCache.cacheKeyForPayload({
        'mode': 'identify',
        'prompt': 'what is this',
        'imageBase64': 'abc',
      });

      expect(key, isNull);
    });

    test('get returns null when ttl is zero', () {
      final cache = GeminiProxyResponseCache(
        maxEntries: 4,
        ttl: Duration.zero,
      );
      const key = 'test-key';
      cache.put(key, {'text': 'cached'});
      expect(cache.get(key), isNull);
    });

    test('evicts oldest entry when maxEntries exceeded', () {
      final cache = GeminiProxyResponseCache(maxEntries: 2);

      cache.put('a', {'text': '1'});
      cache.put('b', {'text': '2'});
      cache.put('c', {'text': '3'});

      expect(cache.get('a'), isNull);
      expect(cache.get('b')?['text'], '2');
      expect(cache.get('c')?['text'], '3');
    });
  });
}
