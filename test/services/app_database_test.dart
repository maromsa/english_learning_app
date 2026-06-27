// test/services/app_database_test.dart
//
// Unit tests for AppDatabase (sqflite).
// Uses sqflite_common_ffi for in-process SQLite on non-mobile platforms.

import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'package:english_learning_app/services/app_database.dart';

// ---------------------------------------------------------------------------
// Helper: creates a fresh in-memory AppDatabase for each test.
// ---------------------------------------------------------------------------

Future<AppDatabase> _makeTestDb() async {
  sqfliteFfiInit();
  databaseFactory = databaseFactoryFfi;

  // Override the singleton's internal DB with an in-memory instance.
  final db = AppDatabase.instance;
  await db.close(); // ensure clean state
  // Force re-open by clearing the cached reference (via close).
  return db;
}

void main() {
  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  tearDown(() async {
    await AppDatabase.instance.close();
  });

  // ---------------------------------------------------------------------------
  // SRS Cards
  // ---------------------------------------------------------------------------

  group('SRS cards', () {
    test('upsert and retrieve a card', () async {
      final db = await _makeTestDb();

      await db.upsertSrsCard(
        userId: 'u1',
        levelId: 'l1',
        wordId: 'apple',
        repetitions: 2,
        easeFactor: 2.6,
        intervalDays: 6,
        masteryLevel: 0.5,
        bestStars: 2,
        nextReviewDate: DateTime(2030, 1, 10),
        lastReviewDate: DateTime(2030, 1, 4),
      );

      final row = await db.getSrsCard(
        userId: 'u1',
        levelId: 'l1',
        wordId: 'apple',
      );

      expect(row, isNotNull);
      expect(row!['repetitions'], 2);
      expect(row['ease_factor'], closeTo(2.6, 0.01));
      expect(row['mastery_level'], closeTo(0.5, 0.01));
      expect(row['dirty'], 1); // default dirty=true
    });

    test('upsert replaces existing row', () async {
      final db = await _makeTestDb();

      await db.upsertSrsCard(
        userId: 'u1', levelId: 'l1', wordId: 'cat',
        repetitions: 1, easeFactor: 2.5, intervalDays: 1,
        masteryLevel: 0.25, bestStars: 0,
      );
      await db.upsertSrsCard(
        userId: 'u1', levelId: 'l1', wordId: 'cat',
        repetitions: 3, easeFactor: 2.7, intervalDays: 12,
        masteryLevel: 0.75, bestStars: 3,
        dirty: false,
      );

      final row = await db.getSrsCard(userId: 'u1', levelId: 'l1', wordId: 'cat');
      expect(row!['repetitions'], 3);
      expect(row['mastery_level'], closeTo(0.75, 0.01));
      expect(row['dirty'], 0);
    });

    test('getDueCards returns only overdue entries', () async {
      final db = await _makeTestDb();

      final past = DateTime.now().subtract(const Duration(days: 1));
      final future = DateTime.now().add(const Duration(days: 5));

      await db.upsertSrsCard(
        userId: 'u1', levelId: 'l1', wordId: 'due_word',
        repetitions: 2, easeFactor: 2.5, intervalDays: 3,
        masteryLevel: 0.4, bestStars: 0,
        nextReviewDate: past,
      );
      await db.upsertSrsCard(
        userId: 'u1', levelId: 'l1', wordId: 'future_word',
        repetitions: 2, easeFactor: 2.5, intervalDays: 6,
        masteryLevel: 0.6, bestStars: 0,
        nextReviewDate: future,
      );

      final due = await db.getDueCards(userId: 'u1', levelId: 'l1');
      expect(due.length, 1);
      expect(due.first['word_id'], 'due_word');
    });

    test('getWeakCards returns cards with mastery in (0, 0.8)', () async {
      final db = await _makeTestDb();

      await db.upsertSrsCard(
        userId: 'u1', levelId: 'l1', wordId: 'new_word',
        repetitions: 0, easeFactor: 2.5, intervalDays: 1,
        masteryLevel: 0.0, bestStars: 0,
      );
      await db.upsertSrsCard(
        userId: 'u1', levelId: 'l1', wordId: 'weak_word',
        repetitions: 1, easeFactor: 2.5, intervalDays: 1,
        masteryLevel: 0.35, bestStars: 0,
      );
      await db.upsertSrsCard(
        userId: 'u1', levelId: 'l1', wordId: 'strong_word',
        repetitions: 5, easeFactor: 2.5, intervalDays: 48,
        masteryLevel: 1.0, bestStars: 3,
      );

      final weak = await db.getWeakCards(userId: 'u1');
      expect(weak.length, 1);
      expect(weak.first['word_id'], 'weak_word');
    });

    test('getDirtyCards returns only dirty=1 rows', () async {
      final db = await _makeTestDb();

      await db.upsertSrsCard(
        userId: 'u1', levelId: 'l1', wordId: 'dirty',
        repetitions: 1, easeFactor: 2.5, intervalDays: 1,
        masteryLevel: 0.2, bestStars: 0, dirty: true,
      );
      await db.upsertSrsCard(
        userId: 'u1', levelId: 'l1', wordId: 'clean',
        repetitions: 1, easeFactor: 2.5, intervalDays: 1,
        masteryLevel: 0.5, bestStars: 0, dirty: false,
      );

      final dirty = await db.getDirtyCards('u1');
      expect(dirty.length, 1);
      expect(dirty.first['word_id'], 'dirty');
    });

    test('markCardsSynced sets dirty=0', () async {
      final db = await _makeTestDb();

      await db.upsertSrsCard(
        userId: 'u1', levelId: 'l1', wordId: 'apple',
        repetitions: 1, easeFactor: 2.5, intervalDays: 1,
        masteryLevel: 0.2, bestStars: 0, dirty: true,
      );

      await db.markCardsSynced(
          userId: 'u1', levelId: 'l1', wordIds: ['apple']);

      final row = await db.getSrsCard(
          userId: 'u1', levelId: 'l1', wordId: 'apple');
      expect(row!['dirty'], 0);
    });

    test('deleteUserData removes all rows for user', () async {
      final db = await _makeTestDb();

      await db.upsertSrsCard(
        userId: 'u1', levelId: 'l1', wordId: 'apple',
        repetitions: 1, easeFactor: 2.5, intervalDays: 1,
        masteryLevel: 0.2, bestStars: 0,
      );
      await db.upsertSrsCard(
        userId: 'u2', levelId: 'l1', wordId: 'apple',
        repetitions: 1, easeFactor: 2.5, intervalDays: 1,
        masteryLevel: 0.2, bestStars: 0,
      );

      await db.deleteUserData('u1');

      final u1 = await db.getSrsCard(userId: 'u1', levelId: 'l1', wordId: 'apple');
      final u2 = await db.getSrsCard(userId: 'u2', levelId: 'l1', wordId: 'apple');
      expect(u1, isNull);
      expect(u2, isNotNull);
    });
  });

  // ---------------------------------------------------------------------------
  // Activity log
  // ---------------------------------------------------------------------------

  group('Activity log', () {
    test('recordActivity creates a row on first call', () async {
      final db = await _makeTestDb();

      await db.recordActivity(
        userId: 'u1',
        day: '2030-01-01',
        wordCount: 10,
        minutes: 3,
      );

      final rows = await db.getRecentActivity(userId: 'u1');
      expect(rows.length, 1);
      expect(rows.first['words'], 10);
      expect(rows.first['minutes'], 3);
    });

    test('recordActivity accumulates same-day entries', () async {
      final db = await _makeTestDb();

      await db.recordActivity(userId: 'u1', day: '2030-01-01', wordCount: 5, minutes: 2);
      await db.recordActivity(userId: 'u1', day: '2030-01-01', wordCount: 8, minutes: 3);

      final rows = await db.getRecentActivity(userId: 'u1');
      expect(rows.length, 1);
      expect(rows.first['words'], 13);
      expect(rows.first['minutes'], 5);
    });

    test('getRecentActivity returns newest first', () async {
      final db = await _makeTestDb();

      await db.recordActivity(userId: 'u1', day: '2030-01-01', wordCount: 5, minutes: 2);
      await db.recordActivity(userId: 'u1', day: '2030-01-03', wordCount: 8, minutes: 3);
      await db.recordActivity(userId: 'u1', day: '2030-01-02', wordCount: 3, minutes: 1);

      final rows = await db.getRecentActivity(userId: 'u1');
      expect(rows.map((r) => r['day']).toList(),
          ['2030-01-03', '2030-01-02', '2030-01-01']);
    });

    test('getRecentActivity respects limit', () async {
      final db = await _makeTestDb();

      for (var i = 1; i <= 10; i++) {
        await db.recordActivity(
          userId: 'u1',
          day: '2030-01-${i.toString().padLeft(2, '0')}',
          wordCount: i,
          minutes: 1,
        );
      }

      final rows = await db.getRecentActivity(userId: 'u1', days: 3);
      expect(rows.length, 3);
    });
  });
}
