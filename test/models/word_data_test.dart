// test/models/word_data_test.dart
import 'package:flutter_test/flutter_test.dart';
import 'package:english_learning_app/models/word_data.dart';

void main() {
  group('WordData', () {
    test('should create WordData with required fields', () {
      final word = WordData(word: 'Apple');
      expect(word.word, 'Apple');
      expect(word.searchHint, null);
      expect(word.isCompleted, false);
      expect(word.stickerUnlocked, false);
      expect(word.imageUrl, null);
      expect(word.publicId, null);
    });

    test('should create WordData with all fields', () {
      final word = WordData(
        word: 'Banana',
        searchHint: 'yellow banana fruit',
        imageUrl: 'https://example.com/banana.jpg',
        publicId: 'banana_123',
        isCompleted: true,
        stickerUnlocked: true,
      );
      expect(word.word, 'Banana');
      expect(word.searchHint, 'yellow banana fruit');
      expect(word.imageUrl, 'https://example.com/banana.jpg');
      expect(word.publicId, 'banana_123');
      expect(word.isCompleted, true);
      expect(word.stickerUnlocked, true);
    });

    test('should allow modifying isCompleted', () {
      final word = WordData(word: 'Cat');
      word.isCompleted = true;
      expect(word.isCompleted, true);
    });

    test('should allow modifying stickerUnlocked', () {
      final word = WordData(word: 'Dog');
      word.stickerUnlocked = true;
      expect(word.stickerUnlocked, true);
    });

    test('fromJson prefers searchHint over query', () {
      final parsed = WordData.fromJson({
        'word': 'Orange',
        'searchHint': 'fresh orange fruit',
        'query': 'citrus orange',
      });

      expect(parsed.searchHint, 'fresh orange fruit');
    });

    test('fromJson falls back to query when searchHint missing', () {
      final parsed = WordData.fromJson({
        'word': 'Grapes',
        'query': 'purple grape bunch',
      });

      expect(parsed.searchHint, 'purple grape bunch');
    });

    test('toJson persists searchHint', () {
      final word = WordData(word: 'Apple', searchHint: 'crisp apple fruit');
      final json = word.toJson();

      expect(json['searchHint'], 'crisp apple fruit');
      expect(json['word'], 'Apple');
    });
  });
}
