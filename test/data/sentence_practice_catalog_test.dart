// test/data/sentence_practice_catalog_test.dart

import 'dart:math';

import 'package:english_learning_app/data/sentence_practice_catalog.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('SentencePracticeCatalog', () {
    test('ships a baseline set of playable sentences', () {
      expect(SentencePracticeCatalog.all.length, greaterThanOrEqualTo(5));
      for (final q in SentencePracticeCatalog.all) {
        expect(q.isPlayable, isTrue, reason: '"${q.fullEnglishSentence}"');
        expect(
          q.optionsWithAnswer.map((o) => o.toLowerCase()),
          contains(q.missingWord.toLowerCase()),
        );
        expect(q.hebrewTranslation, isNotEmpty);
        // The missing word must actually appear in the sentence so the blank
        // lands mid-sentence rather than being appended.
        expect(q.displaySentence, contains('____'));
        expect(q.displaySentence, isNot(endsWith('____')));
      }
    });

    test('session() is deterministic for a seeded Random', () {
      final a = SentencePracticeCatalog.session(random: Random(7));
      final b = SentencePracticeCatalog.session(random: Random(7));
      expect(
        a.map((q) => q.fullEnglishSentence),
        b.map((q) => q.fullEnglishSentence),
      );
      expect(a.first.options, b.first.options);
    });

    test('session() caps the count and keeps every question playable', () {
      final session =
          SentencePracticeCatalog.session(count: 3, random: Random(1));
      expect(session, hasLength(3));
      for (final q in session) {
        expect(q.isPlayable, isTrue);
        expect(
          q.options.map((o) => o.toLowerCase()),
          contains(q.missingWord.toLowerCase()),
        );
      }
    });

    test('session() defaults to the whole catalog', () {
      expect(
        SentencePracticeCatalog.session(random: Random(1)),
        hasLength(SentencePracticeCatalog.all.length),
      );
    });
  });
}
