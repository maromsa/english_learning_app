import 'dart:math';

import 'package:english_learning_app/models/learned_word.dart';
import 'package:english_learning_app/providers/word_bank_provider.dart';
import 'package:english_learning_app/providers/word_review_provider.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

LearnedWord _word(String english, String hebrew) => LearnedWord(
      word: english,
      translation: hebrew,
      dateLearned: DateTime(2026, 9, 16),
    );

WordBankProvider _bank(List<LearnedWord> words) =>
    WordBankProvider(initial: words);

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  group('WordReviewProvider', () {
    test('generateQuiz picks a bank word and 3 unique distractors', () {
      final bank = _bank([
        _word('cat', 'חתול'),
        _word('dog', 'כלב'),
        _word('sun', 'שמש'),
        _word('water', 'מים'),
      ]);
      final review = WordReviewProvider(wordBank: bank, random: Random(1));

      review.generateQuiz();

      expect(review.hasQuiz, isTrue);
      expect(review.currentWord, isNotNull);
      expect(
        ['cat', 'dog', 'sun', 'water'],
        contains(review.currentWord!.word),
      );
      expect(review.options, hasLength(4));
      expect(review.options.toSet(), hasLength(4));
      expect(review.options, contains(review.correctTranslation));
    });

    test('checkAnswer is case-insensitive and does not advance the quiz', () {
      final bank = _bank([
        _word('cat', 'חתול'),
        _word('dog', 'כלב'),
        _word('sun', 'שמש'),
        _word('water', 'מים'),
      ]);
      final review = WordReviewProvider(wordBank: bank, random: Random(7));
      review.generateQuiz();
      final target = review.currentWord!;
      final before = target.word;

      expect(review.checkAnswer(review.correctTranslation!), isTrue);
      expect(
          review.checkAnswer(review.correctTranslation!.toUpperCase()), isTrue);
      expect(review.checkAnswer('not-a-translation'), isFalse);
      expect(review.currentWord!.word, before);
    });

    test('a thin bank still produces a quiz via fallback words', () {
      final bank = _bank([_word('cat', 'חתול')]);
      final review = WordReviewProvider(wordBank: bank, random: Random(3));

      review.generateQuiz();

      expect(review.hasQuiz, isTrue);
      expect(review.currentWord!.word, 'cat');
      expect(review.options.length, greaterThanOrEqualTo(3));
      expect(review.options, contains('חתול'));
      expect(
        review.options.where((o) => o != 'חתול'),
        isNotEmpty,
      );
    });

    test('an empty bank uses only fallback words', () {
      final review = WordReviewProvider(
        wordBank: _bank(const []),
        random: Random(11),
      );

      review.generateQuiz();

      expect(review.hasQuiz, isTrue);
      expect(
        WordReviewProvider.fallbackWords.map((w) => w.word),
        contains(review.currentWord!.word),
      );
      expect(review.options.length, greaterThanOrEqualTo(3));
    });

    test('checkAnswer is false before generateQuiz', () {
      final review = WordReviewProvider(
        wordBank: _bank([_word('cat', 'חתול')]),
        random: Random(1),
      );
      expect(review.hasQuiz, isFalse);
      expect(review.checkAnswer('חתול'), isFalse);
    });
  });
}
