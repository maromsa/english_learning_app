import 'dart:math';

import 'package:english_learning_app/models/sentence_question.dart';

/// Pre-authored baseline sentences for [SentencePracticeScreen].
///
/// These are hand-written so the mode is immediately playable offline, with no
/// dependency on a per-level word pack or the Gemini proxy. Each entry keeps
/// one word out of the sentence and offers kid-friendly distractors; the
/// Hebrew translation gives pre-readers the meaning.
///
/// Keep the copy simple (present tense, one clause, common vocabulary) and the
/// distractors in the same part of speech as the answer.
class SentencePracticeCatalog {
  SentencePracticeCatalog._();

  static const List<SentenceQuestion> all = [
    SentenceQuestion(
      fullEnglishSentence: 'The cat is sleeping on the bed',
      hebrewTranslation: 'החתול ישן על המיטה',
      missingWord: 'cat',
      options: ['cat', 'car', 'cup'],
    ),
    SentenceQuestion(
      fullEnglishSentence: 'I drink water when I am thirsty',
      hebrewTranslation: 'אני שותה מים כשאני צמא',
      missingWord: 'water',
      options: ['bread', 'water', 'paper'],
    ),
    SentenceQuestion(
      fullEnglishSentence: 'The sun is very hot today',
      hebrewTranslation: 'השמש חמה מאוד היום',
      missingWord: 'hot',
      options: ['cold', 'hot', 'soft'],
    ),
    SentenceQuestion(
      fullEnglishSentence: 'She reads a book before she sleeps',
      hebrewTranslation: 'היא קוראת ספר לפני שהיא ישנה',
      missingWord: 'book',
      options: ['book', 'ball', 'box'],
    ),
    SentenceQuestion(
      fullEnglishSentence: 'We play in the park after school',
      hebrewTranslation: 'אנחנו משחקים בפארק אחרי בית הספר',
      missingWord: 'park',
      options: ['park', 'plane', 'plate'],
    ),
    SentenceQuestion(
      fullEnglishSentence: 'The dog runs fast in the garden',
      hebrewTranslation: 'הכלב רץ מהר בגינה',
      missingWord: 'runs',
      options: ['runs', 'eats', 'sits'],
    ),
    SentenceQuestion(
      fullEnglishSentence: 'My mother makes soup for dinner',
      hebrewTranslation: 'אמא שלי מכינה מרק לארוחת ערב',
      missingWord: 'soup',
      options: ['soup', 'snow', 'song'],
    ),
    SentenceQuestion(
      fullEnglishSentence: 'The bird sings a happy song',
      hebrewTranslation: 'הציפור שרה שיר שמח',
      missingWord: 'happy',
      options: ['happy', 'heavy', 'hungry'],
    ),
  ];

  /// A ready-to-play session: [all] shuffled and capped at [count]. Each
  /// question's option order is also shuffled so the answer isn't always in
  /// the same slot. Pass a seeded [random] for deterministic output in tests.
  static List<SentenceQuestion> session({
    int count = 8,
    Random? random,
  }) {
    final rng = random ?? Random();
    final pool = List<SentenceQuestion>.from(all)..shuffle(rng);
    final take = count <= 0 ? pool.length : min(count, pool.length);
    return pool.take(take).map((q) {
      final shuffledOptions = List<String>.from(q.optionsWithAnswer)
        ..shuffle(rng);
      return SentenceQuestion(
        fullEnglishSentence: q.fullEnglishSentence,
        hebrewTranslation: q.hebrewTranslation,
        missingWord: q.missingWord,
        options: shuffledOptions,
      );
    }).toList(growable: false);
  }
}
