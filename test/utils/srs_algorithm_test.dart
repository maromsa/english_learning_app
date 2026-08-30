import 'package:english_learning_app/utils/srs_algorithm.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('SrsAlgorithm.computeNextReview', () {
    final baseDate = DateTime(2026, 1, 1);

    test('3 stars from a fresh streak schedules a 1-day review', () {
      final result = SrsAlgorithm.computeNextReview(
        stars: 3,
        currentStreak: 0,
        now: baseDate,
      );

      expect(result.streak, 1);
      expect(result.nextReviewDate, baseDate.add(const Duration(days: 1)));
    });

    test('3 stars advances the streak through the full interval ladder', () {
      const expectedIntervals = [1, 3, 7, 14, 30];
      var streak = 0;

      for (var i = 0; i < expectedIntervals.length; i++) {
        final result = SrsAlgorithm.computeNextReview(
          stars: 3,
          currentStreak: streak,
          now: baseDate,
        );

        expect(result.streak, i + 1, reason: 'streak after review #${i + 1}');
        expect(
          result.nextReviewDate,
          baseDate.add(Duration(days: expectedIntervals[i])),
          reason: 'interval after review #${i + 1}',
        );
        streak = result.streak;
      }
    });

    test('3 stars caps the interval at 30 days once the streak passes 5', () {
      final result = SrsAlgorithm.computeNextReview(
        stars: 3,
        currentStreak: 9,
        now: baseDate,
      );

      expect(result.streak, 10);
      expect(result.nextReviewDate, baseDate.add(const Duration(days: 30)));
    });

    test('2 stars keeps the streak and schedules a review for tomorrow', () {
      final result = SrsAlgorithm.computeNextReview(
        stars: 2,
        currentStreak: 3,
        now: baseDate,
      );

      expect(result.streak, 3);
      expect(result.nextReviewDate, baseDate.add(const Duration(days: 1)));
    });

    test('2 stars on a zero streak stays at zero', () {
      final result = SrsAlgorithm.computeNextReview(
        stars: 2,
        currentStreak: 0,
        now: baseDate,
      );

      expect(result.streak, 0);
      expect(result.nextReviewDate, baseDate.add(const Duration(days: 1)));
    });

    test('1 star resets the streak and schedules a review for tomorrow', () {
      final result = SrsAlgorithm.computeNextReview(
        stars: 1,
        currentStreak: 4,
        now: baseDate,
      );

      expect(result.streak, 0);
      expect(result.nextReviewDate, baseDate.add(const Duration(days: 1)));
    });

    test('clamps a below-range star rating up to 1 star', () {
      final result = SrsAlgorithm.computeNextReview(
        stars: 0,
        currentStreak: 5,
        now: baseDate,
      );

      expect(result.streak, 0);
      expect(result.nextReviewDate, baseDate.add(const Duration(days: 1)));
    });

    test('clamps an above-range star rating down to 3 stars', () {
      final result = SrsAlgorithm.computeNextReview(
        stars: 5,
        currentStreak: 0,
        now: baseDate,
      );

      expect(result.streak, 1);
      expect(result.nextReviewDate, baseDate.add(const Duration(days: 1)));
    });

    test('clamps a negative incoming streak to zero', () {
      final result = SrsAlgorithm.computeNextReview(
        stars: 3,
        currentStreak: -5,
        now: baseDate,
      );

      expect(result.streak, 1);
      expect(result.nextReviewDate, baseDate.add(const Duration(days: 1)));
    });

    test('defaults now to DateTime.now() when not provided', () {
      final before = DateTime.now();

      final result = SrsAlgorithm.computeNextReview(
        stars: 2,
        currentStreak: 0,
      );

      final expectedEarliest =
          before.add(const Duration(days: 1) - const Duration(minutes: 1));
      final expectedLatest =
          DateTime.now().add(const Duration(days: 1, minutes: 1));

      expect(result.nextReviewDate.isAfter(expectedEarliest), isTrue);
      expect(result.nextReviewDate.isBefore(expectedLatest), isTrue);
    });
  });
}
