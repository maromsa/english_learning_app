import 'package:english_learning_app/models/word_data.dart';
import 'package:english_learning_app/services/word_mastery_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('WordMasteryService', () {
    late SharedPreferences prefs;
    late WordMasteryService service;

    setUp(() async {
      SharedPreferences.setMockInitialValues(<String, Object>{});
      prefs = await SharedPreferences.getInstance();
      service = WordMasteryService(prefs: prefs);
    });

    test('returns default entry when no data exists', () async {
      final entry = await service.getMastery(
        userId: 'user1',
        levelId: 'level1',
        word: 'Apple',
      );

      expect(entry.masteryLevel, 0.0);
      expect(entry.lastReviewed, isNull);
    });

    test('recordSuccessfulReview increases mastery and sets lastReviewed',
        () async {
      final before = await service.getMastery(
        userId: 'user1',
        levelId: 'level1',
        word: 'Apple',
      );
      expect(before.masteryLevel, 0.0);

      final after = await service.recordSuccessfulReview(
        userId: 'user1',
        levelId: 'level1',
        word: 'Apple',
        delta: 0.5,
      );

      expect(after.masteryLevel, closeTo(0.5, 0.0001));
      expect(after.lastReviewed, isNotNull);
    });

    test('setMastery clamps values into range and persists', () async {
      final entry = await service.setMastery(
        userId: 'user1',
        levelId: 'level1',
        word: 'Banana',
        masteryLevel: 2.0,
      );

      expect(entry.masteryLevel, 1.0);

      final loaded = await service.getMastery(
        userId: 'user1',
        levelId: 'level1',
        word: 'Banana',
      );
      expect(loaded.masteryLevel, 1.0);
    });

    test(
        'recordPronunciationScore keeps best stars and sets mastery on 3 stars',
        () async {
      final twoStar = await service.recordPronunciationScore(
        userId: 'user1',
        levelId: 'level1',
        word: 'Dog',
        stars: 2,
      );
      expect(twoStar.bestPronunciationStars, 2);
      expect(twoStar.masteryLevel, closeTo(2 / 3, 0.0001));

      final threeStar = await service.recordPronunciationScore(
        userId: 'user1',
        levelId: 'level1',
        word: 'Dog',
        stars: 3,
      );
      expect(threeStar.bestPronunciationStars, 3);
      expect(threeStar.masteryLevel, 1.0);
      expect(threeStar.isMastered, isTrue);

      final loaded = await service.getMastery(
        userId: 'user1',
        levelId: 'level1',
        word: 'Dog',
      );
      expect(loaded.bestPronunciationStars, 3);
      expect(loaded.masteryLevel, 1.0);
    });

    test('recordPronunciationScore schedules the next SRS review', () async {
      final reviewedAt = DateTime(2026, 1, 1);

      final first = await service.recordPronunciationScore(
        userId: 'user1',
        levelId: 'level1',
        word: 'Elephant',
        stars: 3,
        reviewedAt: reviewedAt,
      );
      expect(first.srsStreak, 1);
      expect(first.nextReviewDate, reviewedAt.add(const Duration(days: 1)));

      final second = await service.recordPronunciationScore(
        userId: 'user1',
        levelId: 'level1',
        word: 'Elephant',
        stars: 3,
        reviewedAt: reviewedAt,
      );
      expect(second.srsStreak, 2);
      expect(second.nextReviewDate, reviewedAt.add(const Duration(days: 3)));

      final missed = await service.recordPronunciationScore(
        userId: 'user1',
        levelId: 'level1',
        word: 'Elephant',
        stars: 1,
        reviewedAt: reviewedAt,
      );
      expect(missed.srsStreak, 0);
      expect(missed.nextReviewDate, reviewedAt.add(const Duration(days: 1)));
    });

    test('applyToWord merges mastery into WordData', () async {
      final base = WordData(
        word: 'Cat',
        searchHint: 'cute cat',
        isCompleted: true,
      );

      final mastery = await service.setMastery(
        userId: 'user1',
        levelId: 'level1',
        word: 'Cat',
        masteryLevel: 0.8,
      );

      final merged = service.applyToWord(base, mastery);

      expect(merged.word, 'Cat');
      expect(merged.searchHint, 'cute cat');
      expect(merged.isCompleted, true);
      expect(merged.masteryLevel, closeTo(0.8, 0.0001));
      expect(merged.lastReviewed, isNotNull);
    });

    group('getWordsDueForReview', () {
      test('returns nothing for a user with no graded words', () async {
        final due = await service.getWordsDueForReview(userId: 'user1');
        expect(due, isEmpty);
      });

      test('excludes words whose nextReviewDate is in the future', () async {
        final reviewedAt = DateTime(2026, 1, 1);
        await service.recordPronunciationScore(
          userId: 'user1',
          levelId: 'level1',
          word: 'Apple',
          stars: 3,
          reviewedAt: reviewedAt,
        );

        final due = await service.getWordsDueForReview(
          userId: 'user1',
          now: reviewedAt, // still day 0 — review isn't due until day 1.
        );
        expect(due, isEmpty);
      });

      test('includes words whose nextReviewDate has arrived', () async {
        final reviewedAt = DateTime(2026, 1, 1);
        await service.recordPronunciationScore(
          userId: 'user1',
          levelId: 'level1',
          word: 'Apple',
          stars: 1, // 1 star -> due again tomorrow.
          reviewedAt: reviewedAt,
        );

        final due = await service.getWordsDueForReview(
          userId: 'user1',
          now: reviewedAt.add(const Duration(days: 1)),
        );

        expect(due, hasLength(1));
        expect(due.single.levelId, 'level1');
        expect(due.single.word, 'Apple');
        expect(due.single.mastery.srsStreak, 0);
      });

      test('filters to a single level when levelId is supplied', () async {
        final reviewedAt = DateTime(2026, 1, 1);
        final dueAt = reviewedAt.add(const Duration(days: 1));

        await service.recordPronunciationScore(
          userId: 'user1',
          levelId: 'level1',
          word: 'Apple',
          stars: 1,
          reviewedAt: reviewedAt,
        );
        await service.recordPronunciationScore(
          userId: 'user1',
          levelId: 'level2',
          word: 'Banana',
          stars: 1,
          reviewedAt: reviewedAt,
        );

        final due = await service.getWordsDueForReview(
          userId: 'user1',
          levelId: 'level1',
          now: dueAt,
        );

        expect(due, hasLength(1));
        expect(due.single.word, 'Apple');
      });

      test('never-graded words are not due', () async {
        // recordSuccessfulReview doesn't run the SRS algorithm, so it never
        // sets a nextReviewDate.
        await service.recordSuccessfulReview(
          userId: 'user1',
          levelId: 'level1',
          word: 'Cherry',
        );

        final due = await service.getWordsDueForReview(userId: 'user1');
        expect(due, isEmpty);
      });
    });

    group('getDueWordDataForLevel', () {
      test('returns an empty list when nothing is due', () async {
        final catalog = [WordData(word: 'Apple')];
        final due = await service.getDueWordDataForLevel(
          userId: 'user1',
          levelId: 'level1',
          catalog: catalog,
        );
        expect(due, isEmpty);
      });

      test('resolves due entries against the catalog, merged with mastery',
          () async {
        final reviewedAt = DateTime(2026, 1, 1);
        await service.recordPronunciationScore(
          userId: 'user1',
          levelId: 'level1',
          word: 'Apple',
          stars: 1,
          reviewedAt: reviewedAt,
        );
        // Build a streak of 2 (3-day interval) so Banana's next review
        // lands after the check below, unlike Apple's — should be excluded
        // from the result.
        await service.recordPronunciationScore(
          userId: 'user1',
          levelId: 'level1',
          word: 'Banana',
          stars: 3,
          reviewedAt: reviewedAt.subtract(const Duration(days: 3)),
        );
        await service.recordPronunciationScore(
          userId: 'user1',
          levelId: 'level1',
          word: 'Banana',
          stars: 3,
          reviewedAt: reviewedAt,
        );

        final catalog = [
          WordData(word: 'Apple', searchHint: 'red fruit'),
          WordData(word: 'Banana'),
          WordData(word: 'Cherry'), // never graded — never due.
        ];

        final due = await service.getDueWordDataForLevel(
          userId: 'user1',
          levelId: 'level1',
          catalog: catalog,
          now: reviewedAt.add(const Duration(days: 1)),
        );

        expect(due, hasLength(1));
        expect(due.single.word, 'Apple');
        expect(due.single.searchHint, 'red fruit');
        expect(due.single.masteryLevel, greaterThan(0.0));
      });

      test('skips due entries no longer present in the catalog', () async {
        final reviewedAt = DateTime(2026, 1, 1);
        await service.recordPronunciationScore(
          userId: 'user1',
          levelId: 'level1',
          word: 'RemovedWord',
          stars: 1,
          reviewedAt: reviewedAt,
        );

        final due = await service.getDueWordDataForLevel(
          userId: 'user1',
          levelId: 'level1',
          catalog: const [],
          now: reviewedAt.add(const Duration(days: 1)),
        );

        expect(due, isEmpty);
      });
    });
  });
}
