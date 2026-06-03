import 'dart:convert';
import 'dart:typed_data';

import 'package:english_learning_app/utils/word_image_url.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('word_image_url', () {
    test('isEphemeralWebBlobUrl detects blob scheme', () {
      expect(isEphemeralWebBlobUrl('blob:https://example/a'), isTrue);
      expect(isEphemeralWebBlobUrl('data:image/png;base64,abc'), isFalse);
      expect(isEphemeralWebBlobUrl(null), isFalse);
    });

    test('dataImageUrlFromBytes round-trips through decodeDataImageUrl', () {
      const payload = [1, 2, 3, 4];
      final dataUrl = dataImageUrlFromBytes(Uint8List.fromList(payload));
      expect(isInlineDataImageUrl(dataUrl), isTrue);

      final decoded = decodeDataImageUrl(dataUrl);
      expect(decoded, Uint8List.fromList(payload));
    });

    test('decodeDataImageUrl rejects non-base64 data URLs', () {
      expect(
        decodeDataImageUrl('data:image/png,not-base64'),
        isNull,
      );
    });

    test('decodeDataImageUrl parses standard base64 data URLs', () {
      final bytes = utf8.encode('hello');
      final dataUrl =
          'data:image/jpeg;base64,${base64Encode(bytes)}';
      expect(decodeDataImageUrl(dataUrl), bytes);
    });
  });
}
