import 'package:english_learning_app/models/word_progress_entry.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('WordProgressEntry', () {
    test('fromMap and toMap round-trip', () {
      const entry = WordProgressEntry(
        wordId: 'Apple',
        bestPronunciationStars: 3,
        isMastered: true,
        isCompleted: true,
      );

      final restored = WordProgressEntry.fromMap(entry.toMap());
      expect(restored.wordId, 'Apple');
      expect(restored.bestPronunciationStars, 3);
      expect(restored.isMastered, isTrue);
      expect(restored.isCompleted, isTrue);
    });

    test('fromMap and toMap round-trip the SRS fields', () {
      final nextReview = DateTime(2026, 2, 14);
      final entry = WordProgressEntry(
        wordId: 'Elephant',
        bestPronunciationStars: 3,
        srsStreak: 2,
        nextReviewDate: nextReview,
      );

      final restored = WordProgressEntry.fromMap(entry.toMap());
      expect(restored.srsStreak, 2);
      expect(restored.nextReviewDate, nextReview);
    });

    test(
        'mergeWith keeps the SRS streak/review-date pair from the higher streak',
        () {
      final a = WordProgressEntry(
        wordId: 'Dog',
        srsStreak: 1,
        nextReviewDate: DateTime(2026, 1, 2),
      );
      final b = WordProgressEntry(
        wordId: 'Dog',
        srsStreak: 3,
        nextReviewDate: DateTime(2026, 1, 8),
      );

      final merged = a.mergeWith(b);
      expect(merged.srsStreak, 3);
      expect(merged.nextReviewDate, DateTime(2026, 1, 8));
    });

    test('mergeWith keeps best stars and flags', () {
      const a = WordProgressEntry(
        wordId: 'Dog',
        bestPronunciationStars: 2,
        isMastered: false,
      );
      const b = WordProgressEntry(
        wordId: 'Dog',
        bestPronunciationStars: 3,
        isMastered: true,
        isCompleted: true,
      );

      final merged = a.mergeWith(b);
      expect(merged.bestPronunciationStars, 3);
      expect(merged.isMastered, isTrue);
      expect(merged.isCompleted, isTrue);
    });

    test('encodeWordFirestoreKey escapes dots', () {
      expect(encodeWordFirestoreKey('Mr. Smith'), 'Mr\u2024 Smith');
      expect(decodeWordFirestoreKey('Mr\u2024 Smith'), 'Mr. Smith');
    });
  });
}
