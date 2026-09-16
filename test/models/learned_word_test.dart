import 'package:english_learning_app/models/learned_word.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('LearnedWord', () {
    test('toJson / fromJson round-trip', () {
      final word = LearnedWord(
        word: 'cat',
        translation: 'חתול',
        dateLearned: DateTime(2026, 9, 16, 10, 30),
      );
      final restored = LearnedWord.fromJson(word.toJson());
      expect(restored.word, 'cat');
      expect(restored.translation, 'חתול');
      expect(restored.dateLearned, DateTime(2026, 9, 16, 10, 30));
    });

    test('toJson omits an empty translation', () {
      final word = LearnedWord(
        word: 'cat',
        dateLearned: DateTime(2026, 9, 16),
      );
      expect(word.toJson().containsKey('translation'), isFalse);
    });

    test('fromJson tolerates a missing or malformed document', () {
      final restored = LearnedWord.fromJson(const {});
      expect(restored.word, isEmpty);
      expect(restored.translation, isNull);
      expect(restored.dateLearned, DateTime.fromMillisecondsSinceEpoch(0));

      expect(
        LearnedWord.fromJson(const {
          'word': 12,
          'translation': '',
          'dateLearned': 'not-a-date',
        }).word,
        isEmpty,
      );
    });

    test('fromJson accepts millisecond timestamps', () {
      final when = DateTime(2026, 9, 16, 8);
      final restored = LearnedWord.fromJson({
        'word': 'dog',
        'dateLearned': when.millisecondsSinceEpoch,
      });
      expect(restored.word, 'dog');
      expect(restored.dateLearned, when);
    });
  });
}
