import 'package:english_learning_app/models/collection_word_item.dart';
import 'package:english_learning_app/models/word_data.dart';
import 'package:english_learning_app/services/word_mastery_service.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('CollectionWordItem', () {
    test('isMastered when mastery entry has 3 stars', () {
      final item = CollectionWordItem(
        word: WordData(word: 'Cat'),
        levelId: 'level_1',
        mastery: WordMasteryEntry(
          masteryLevel: 1.0,
          bestPronunciationStars: 3,
        ),
        isCompleted: true,
      );

      expect(item.isMastered, isTrue);
      expect(item.isLocked, isFalse);
    });

    test('isLocked when completed but not 3-star mastered', () {
      final item = CollectionWordItem(
        word: WordData(word: 'Dog', isCompleted: true),
        levelId: 'level_1',
        mastery: WordMasteryEntry(
          masteryLevel: 0.5,
          bestPronunciationStars: 2,
        ),
        isCompleted: true,
      );

      expect(item.isMastered, isFalse);
      expect(item.isLocked, isTrue);
    });

    test('isLocked when never completed', () {
      final item = CollectionWordItem(
        word: WordData(word: 'Fish'),
        levelId: 'level_1',
        mastery: WordMasteryEntry(masteryLevel: 0.0),
        isCompleted: false,
      );

      expect(item.isMastered, isFalse);
      expect(item.isLocked, isTrue);
    });
  });
}
