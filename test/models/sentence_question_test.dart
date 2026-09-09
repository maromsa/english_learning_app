// test/models/sentence_question_test.dart

import 'package:english_learning_app/models/sentence_question.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('SentenceQuestion', () {
    const question = SentenceQuestion(
      fullEnglishSentence: 'The cat is on the roof',
      hebrewTranslation: 'החתול על הגג',
      missingWord: 'cat',
      options: ['dog', 'cat', 'car'],
    );

    test('displaySentence swaps the first whole-word match for a blank', () {
      expect(question.displaySentence, 'The ____ is on the roof');
    });

    test('displaySentence appends a blank when the word is not found', () {
      const q = SentenceQuestion(
        fullEnglishSentence: 'She is running fast',
        hebrewTranslation: 'היא רצה מהר',
        missingWord: 'run',
        options: ['run', 'jump'],
      );
      expect(q.displaySentence, 'She is running fast ____');
    });

    test('optionsWithAnswer includes the answer once, de-duplicated', () {
      const q = SentenceQuestion(
        fullEnglishSentence: 'I like the Cat',
        hebrewTranslation: 'אני אוהב את החתול',
        missingWord: 'cat',
        options: ['cat', 'CAT', 'dog'],
      );
      expect(q.optionsWithAnswer, ['cat', 'dog']);
    });

    test('optionsWithAnswer adds the answer when options omit it', () {
      const q = SentenceQuestion(
        fullEnglishSentence: 'A red apple',
        hebrewTranslation: 'תפוח אדום',
        missingWord: 'apple',
        options: ['banana', 'orange'],
      );
      expect(q.optionsWithAnswer, ['banana', 'orange', 'apple']);
    });

    test('isCorrect is case- and whitespace-insensitive', () {
      expect(question.isCorrect('  CAT '), isTrue);
      expect(question.isCorrect('dog'), isFalse);
    });

    test('isPlayable is false without a sentence, word, or enough options', () {
      expect(question.isPlayable, isTrue);
      expect(
        const SentenceQuestion(
          fullEnglishSentence: '',
          hebrewTranslation: 'x',
          missingWord: 'cat',
          options: ['cat', 'dog'],
        ).isPlayable,
        isFalse,
      );
      expect(
        const SentenceQuestion(
          fullEnglishSentence: 'The cat sleeps',
          hebrewTranslation: 'x',
          missingWord: 'cat',
          options: [],
        ).isPlayable,
        // only the answer -> 1 option -> not playable
        isFalse,
      );
    });

    test('fromJson tolerates missing / malformed fields', () {
      final q = SentenceQuestion.fromJson(const {
        'fullEnglishSentence': '  The sun is hot  ',
        'missingWord': ' sun ',
        'options': ['sun', 42, '', 'moon'],
      });
      expect(q.fullEnglishSentence, 'The sun is hot');
      expect(q.hebrewTranslation, '');
      expect(q.missingWord, 'sun');
      expect(q.options, ['sun', '42', 'moon']);
    });

    test('toJson round-trips through fromJson', () {
      final restored = SentenceQuestion.fromJson(question.toJson());
      expect(restored.fullEnglishSentence, question.fullEnglishSentence);
      expect(restored.hebrewTranslation, question.hebrewTranslation);
      expect(restored.missingWord, question.missingWord);
      expect(restored.options, question.options);
    });
  });
}
