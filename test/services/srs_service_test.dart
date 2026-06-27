// test/services/srs_service_test.dart
import 'package:english_learning_app/models/srs_card.dart';
import 'package:english_learning_app/models/word_data.dart';
import 'package:english_learning_app/services/srs_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  group('SrsCard — SM-2 algorithm', () {
    test('new card is due immediately', () {
      const card = SrsCard(wordId: 'apple');
      expect(card.isDue, isTrue);
      expect(card.repetitions, 0);
      expect(card.easeFactor, 2.5);
    });

    test('grade 5 (perfect) on first review → 1-day interval', () {
      const card = SrsCard(wordId: 'apple');
      final reviewed = card.review(grade: 5);
      expect(reviewed.repetitions, 1);
      expect(reviewed.intervalDays, 1);
      expect(reviewed.nextReviewDate, isNotNull);
      expect(reviewed.isDue, isFalse);
    });

    test('grade 5 on second review → 6-day interval', () {
      const card = SrsCard(wordId: 'apple');
      final r1 = card.review(grade: 5);
      final r2 = r1.review(grade: 5);
      expect(r2.repetitions, 2);
      expect(r2.intervalDays, 6);
    });

    test('grade 5 on third review → interval ≈ EF * 6', () {
      const card = SrsCard(wordId: 'apple');
      final r1 = card.review(grade: 5);
      final r2 = r1.review(grade: 5);
      final r3 = r2.review(grade: 5);
      expect(r3.repetitions, 3);
      expect(r3.intervalDays, (6 * r3.easeFactor).round());
    });

    test('grade 0 (blackout) resets repetitions to 0', () {
      const card = SrsCard(wordId: 'apple', repetitions: 3, intervalDays: 15);
      final reviewed = card.review(grade: 0);
      expect(reviewed.repetitions, 0);
      expect(reviewed.intervalDays, 1);
    });

    test('grade 1 (wrong) resets repetitions to 0', () {
      const card = SrsCard(wordId: 'apple', repetitions: 2, intervalDays: 6);
      final reviewed = card.review(grade: 1);
      expect(reviewed.repetitions, 0);
      expect(reviewed.intervalDays, 1);
    });

    test('easeFactor never drops below 1.3', () {
      var card = const SrsCard(wordId: 'apple');
      for (int i = 0; i < 20; i++) {
        card = card.review(grade: 0);
      }
      expect(card.easeFactor, greaterThanOrEqualTo(1.3));
    });

    test('easeFactor never exceeds 3.5', () {
      var card = const SrsCard(wordId: 'apple');
      for (int i = 0; i < 20; i++) {
        card = card.review(grade: 5);
      }
      expect(card.easeFactor, lessThanOrEqualTo(3.5));
    });

    test('interval never exceeds 365 days', () {
      var card = const SrsCard(
          wordId: 'apple', easeFactor: 3.5, intervalDays: 200, repetitions: 5);
      card = card.review(grade: 5);
      expect(card.intervalDays, lessThanOrEqualTo(365));
    });

    test('masteryLevel increases with successful reviews', () {
      const card = SrsCard(wordId: 'apple');
      final r1 = card.review(grade: 4);
      final r2 = r1.review(grade: 4);
      final r3 = r2.review(grade: 4);
      expect(r1.masteryLevel, greaterThan(0.0));
      expect(r2.masteryLevel, greaterThan(r1.masteryLevel));
      expect(r3.masteryLevel, greaterThanOrEqualTo(r2.masteryLevel));
    });

    test('masteryLevel stays low after failures', () {
      const card = SrsCard(wordId: 'apple');
      final r1 = card.review(grade: 0);
      expect(r1.masteryLevel, lessThan(0.3));
    });

    test('pronunciation 3 stars gives high mastery', () {
      const card = SrsCard(wordId: 'apple');
      final updated = card.withPronunciationScore(3);
      expect(updated.bestPronunciationStars, 3);
      expect(updated.masteryLevel, greaterThan(0.0));
    });

    test('bestPronunciationStars only increases', () {
      const card = SrsCard(wordId: 'apple', bestPronunciationStars: 3);
      final updated = card.withPronunciationScore(1);
      expect(updated.bestPronunciationStars, 3);
    });

    test('serialise → deserialise round-trip', () {
      final card = const SrsCard(wordId: 'apple').review(grade: 4);
      final json = card.toJson();
      final restored = SrsCard.fromJson(json);
      expect(restored.wordId, card.wordId);
      expect(restored.repetitions, card.repetitions);
      expect(restored.easeFactor, card.easeFactor);
      expect(restored.intervalDays, card.intervalDays);
      expect(restored.masteryLevel, card.masteryLevel);
    });
  });

  group('gradeFromCorrect', () {
    test('correct → grade 4', () => expect(gradeFromCorrect(true), 4));
    test('incorrect → grade 1', () => expect(gradeFromCorrect(false), 1));
  });

  group('SrsService — persistence', () {
    late SharedPreferences prefs;
    late SrsService service;

    setUp(() async {
      SharedPreferences.setMockInitialValues({});
      prefs = await SharedPreferences.getInstance();
      service = SrsService(prefs: prefs);
    });

    test('new word returns default card', () async {
      final card = await service.getCard(
          userId: 'u1', levelId: 'l1', word: 'apple');
      expect(card.repetitions, 0);
      expect(card.isDue, isTrue);
    });

    test('recordReview persists updated card', () async {
      await service.recordReview(
          userId: 'u1', levelId: 'l1', word: 'apple', grade: 4);
      final service2 = SrsService(prefs: prefs);
      final card = await service2.getCard(
          userId: 'u1', levelId: 'l1', word: 'apple');
      expect(card.repetitions, 1);
    });

    test('correct then failure resets repetitions', () async {
      await service.recordReview(
          userId: 'u1', levelId: 'l1', word: 'apple', grade: 4);
      await service.recordReview(
          userId: 'u1', levelId: 'l1', word: 'apple', grade: 4);
      await service.recordReview(
          userId: 'u1', levelId: 'l1', word: 'apple', grade: 0);
      final card = await service.getCard(
          userId: 'u1', levelId: 'l1', word: 'apple');
      expect(card.repetitions, 0);
    });

    test('getSortedForSession puts new words before future-due words', () async {
      // apple: 5 successful reviews → not due for many days
      for (int i = 0; i < 5; i++) {
        await service.recordReview(
            userId: 'u1', levelId: 'l1', word: 'apple', grade: 5);
      }
      final words = [_w('apple'), _w('banana')];
      final sorted = await service.getSortedForSession(
          userId: 'u1', levelId: 'l1', words: words);
      expect(sorted.first.word, 'banana');
    });

    test('getWeakWords returns reviewed words sorted ascending by mastery',
        () async {
      await service.recordReview(
          userId: 'u1', levelId: 'l1', word: 'apple', grade: 5);
      await service.recordReview(
          userId: 'u1', levelId: 'l1', word: 'banana', grade: 1);
      final words = [_w('apple'), _w('banana'), _w('cat')];
      final weak = await service.getWeakWords(
          userId: 'u1', levelId: 'l1', allWords: words, limit: 3);
      // banana has lower mastery (failed review) than apple (perfect review).
      expect(weak.first.word, 'banana');
    });

    test('countDue returns 0 after all words are reviewed successfully',
        () async {
      final words = [_w('apple'), _w('banana')];
      for (final w in words) {
        for (int i = 0; i < 3; i++) {
          await service.recordReview(
              userId: 'u1', levelId: 'l1', word: w.word, grade: 5);
        }
      }
      final due = await service.countDue(
          userId: 'u1', levelId: 'l1', words: words);
      expect(due, 0);
    });
  });
}

WordData _w(String word) => WordData(word: word, searchHint: word);
