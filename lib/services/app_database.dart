// lib/services/app_database.dart
//
// Local SQLite database (via sqflite).
//
// Tables:
//   • srs_cards  — one row per (userId, levelId, wordId); mirrors SrsCard fields.
//   • activity_log — one row per (userId, day); daily word/minute counts.
//
// This is the single source of truth for offline data. Firestore sync is
// one-directional: local → cloud (upload on session end) and cloud → local
// (download on first install / explicit refresh).

import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as p;
import 'package:sqflite/sqflite.dart';

class AppDatabase {
  AppDatabase._();

  static final AppDatabase instance = AppDatabase._();

  static const int _version = 1;
  static const String _dbName = 'spark_local.db';

  Database? _db;

  Future<Database> get database async {
    _db ??= await _open();
    return _db!;
  }

  // ---------------------------------------------------------------------------
  // Open / migrate
  // ---------------------------------------------------------------------------

  Future<Database> _open() async {
    final dir = await getDatabasesPath();
    final path = p.join(dir, _dbName);

    return openDatabase(
      path,
      version: _version,
      onCreate: _onCreate,
      onUpgrade: _onUpgrade,
    );
  }

  Future<void> _onCreate(Database db, int version) async {
    await db.execute('''
      CREATE TABLE srs_cards (
        id              INTEGER PRIMARY KEY AUTOINCREMENT,
        user_id         TEXT    NOT NULL,
        level_id        TEXT    NOT NULL,
        word_id         TEXT    NOT NULL,
        repetitions     INTEGER NOT NULL DEFAULT 0,
        ease_factor     REAL    NOT NULL DEFAULT 2.5,
        interval_days   INTEGER NOT NULL DEFAULT 1,
        mastery_level   REAL    NOT NULL DEFAULT 0.0,
        best_stars      INTEGER NOT NULL DEFAULT 0,
        next_review_ms  INTEGER,
        last_review_ms  INTEGER,
        dirty           INTEGER NOT NULL DEFAULT 1,
        UNIQUE(user_id, level_id, word_id)
      )
    ''');

    await db.execute('''
      CREATE TABLE activity_log (
        id         INTEGER PRIMARY KEY AUTOINCREMENT,
        user_id    TEXT    NOT NULL,
        day        TEXT    NOT NULL,
        words      INTEGER NOT NULL DEFAULT 0,
        minutes    INTEGER NOT NULL DEFAULT 0,
        UNIQUE(user_id, day)
      )
    ''');

    await db.execute(
        'CREATE INDEX idx_srs_user_level ON srs_cards(user_id, level_id)');
    await db.execute(
        'CREATE INDEX idx_srs_next_review ON srs_cards(user_id, next_review_ms)');
    await db.execute(
        'CREATE INDEX idx_activity_user ON activity_log(user_id, day)');
  }

  Future<void> _onUpgrade(Database db, int oldVersion, int newVersion) async {
    // Future migrations go here.
    debugPrint('AppDatabase: upgrading $oldVersion → $newVersion');
  }

  // ---------------------------------------------------------------------------
  // SRS Cards — CRUD
  // ---------------------------------------------------------------------------

  Future<Map<String, dynamic>?> getSrsCard({
    required String userId,
    required String levelId,
    required String wordId,
  }) async {
    final db = await database;
    final rows = await db.query(
      'srs_cards',
      where: 'user_id = ? AND level_id = ? AND word_id = ?',
      whereArgs: [userId, levelId, wordId],
      limit: 1,
    );
    return rows.isEmpty ? null : rows.first;
  }

  Future<List<Map<String, dynamic>>> getSrsCardsForLevel({
    required String userId,
    required String levelId,
  }) async {
    final db = await database;
    return db.query(
      'srs_cards',
      where: 'user_id = ? AND level_id = ?',
      whereArgs: [userId, levelId],
    );
  }

  /// Returns next_review_ms values for ALL SRS cards for [userId].
  /// Used by SrsService to find the earliest upcoming review date for scheduling
  /// a local notification.
  Future<List<Map<String, dynamic>>> getAllSrsCards({
    required String userId,
  }) async {
    final db = await database;
    return db.query(
      'srs_cards',
      columns: ['next_review_ms'],
      where: 'user_id = ? AND next_review_ms IS NOT NULL',
      whereArgs: [userId],
    );
  }

  /// Returns all cards for [userId] with next_review_ms ≤ now (i.e. due).
  Future<List<Map<String, dynamic>>> getDueCards({
    required String userId,
    required String levelId,
  }) async {
    final db = await database;
    final nowMs = DateTime.now().millisecondsSinceEpoch;
    return db.query(
      'srs_cards',
      where:
          'user_id = ? AND level_id = ? AND (next_review_ms IS NULL OR next_review_ms <= ?)',
      whereArgs: [userId, levelId, nowMs],
    );
  }

  /// Returns ALL due cards for [userId] across all levels, including level_id
  /// and word_id columns. Used by SrsReviewScreen for a cross-level review session.
  Future<List<Map<String, dynamic>>> getAllDueCards({
    required String userId,
    int limit = 20,
  }) async {
    final db = await database;
    final nowMs = DateTime.now().millisecondsSinceEpoch;
    return db.query(
      'srs_cards',
      columns: ['level_id', 'word_id', 'mastery_level', 'best_stars',
                 'next_review_ms', 'repetitions', 'ease_factor', 'interval_days'],
      where:
          'user_id = ? AND (next_review_ms IS NULL OR next_review_ms <= ?)',
      whereArgs: [userId, nowMs],
      orderBy: 'next_review_ms ASC',
      limit: limit,
    );
  }

  /// Returns cards with mastery in (0, 0.8) — needs practice.
  Future<List<Map<String, dynamic>>> getWeakCards({
    required String userId,
    int limit = 8,
  }) async {
    final db = await database;
    return db.query(
      'srs_cards',
      where: 'user_id = ? AND mastery_level > 0.0 AND mastery_level < 0.8',
      whereArgs: [userId],
      orderBy: 'mastery_level ASC',
      limit: limit,
    );
  }

  /// Returns total SRS cards ever reviewed (repetitions > 0) for [userId].
  /// Used as a proxy for total words practiced across all levels.
  Future<int> getPracticedCount({required String userId}) async {
    final db = await database;
    final result = await db.rawQuery(
      'SELECT COUNT(*) AS cnt FROM srs_cards WHERE user_id = ? AND repetitions > 0',
      [userId],
    );
    return (result.first['cnt'] as int?) ?? 0;
  }

  /// Returns the number of fully-mastered cards (mastery_level >= 1.0) for [userId].
  Future<int> getMasteredCount({required String userId}) async {
    final db = await database;
    final result = await db.rawQuery(
      'SELECT COUNT(*) AS cnt FROM srs_cards WHERE user_id = ? AND mastery_level >= 1.0',
      [userId],
    );
    return (result.first['cnt'] as int?) ?? 0;
  }

  /// Upserts a single SRS card row. Marks dirty=1 so the sync engine picks it up.
  Future<void> upsertSrsCard({
    required String userId,
    required String levelId,
    required String wordId,
    required int repetitions,
    required double easeFactor,
    required int intervalDays,
    required double masteryLevel,
    required int bestStars,
    DateTime? nextReviewDate,
    DateTime? lastReviewDate,
    bool dirty = true,
  }) async {
    final db = await database;
    await db.insert(
      'srs_cards',
      {
        'user_id': userId,
        'level_id': levelId,
        'word_id': wordId,
        'repetitions': repetitions,
        'ease_factor': easeFactor,
        'interval_days': intervalDays,
        'mastery_level': masteryLevel,
        'best_stars': bestStars,
        'next_review_ms': nextReviewDate?.millisecondsSinceEpoch,
        'last_review_ms': lastReviewDate?.millisecondsSinceEpoch,
        'dirty': dirty ? 1 : 0,
      },
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  /// Returns all dirty (unsynced) SRS cards for a user.
  Future<List<Map<String, dynamic>>> getDirtyCards(String userId) async {
    final db = await database;
    return db.query(
      'srs_cards',
      where: 'user_id = ? AND dirty = 1',
      whereArgs: [userId],
    );
  }

  /// Marks specific cards as clean after a successful Firestore upload.
  Future<void> markCardsSynced({
    required String userId,
    required List<String> wordIds,
    required String levelId,
  }) async {
    if (wordIds.isEmpty) return;
    final db = await database;
    final placeholders = List.filled(wordIds.length, '?').join(', ');
    await db.rawUpdate(
      '''
      UPDATE srs_cards
      SET dirty = 0
      WHERE user_id = ? AND level_id = ? AND word_id IN ($placeholders)
      ''',
      [userId, levelId, ...wordIds],
    );
  }

  // ---------------------------------------------------------------------------
  // Activity Log
  // ---------------------------------------------------------------------------

  /// Adds [wordCount] words and [minutes] to today's log entry (or creates it).
  Future<void> recordActivity({
    required String userId,
    required String day, // 'YYYY-MM-DD'
    required int wordCount,
    required int minutes,
  }) async {
    final db = await database;
    await db.rawInsert(
      '''
      INSERT INTO activity_log(user_id, day, words, minutes)
      VALUES(?, ?, ?, ?)
      ON CONFLICT(user_id, day) DO UPDATE SET
        words   = words   + excluded.words,
        minutes = minutes + excluded.minutes
      ''',
      [userId, day, wordCount, minutes],
    );
  }

  /// Returns the last [days] activity entries, newest first.
  Future<List<Map<String, dynamic>>> getRecentActivity({
    required String userId,
    int days = 30,
  }) async {
    final db = await database;
    return db.query(
      'activity_log',
      where: 'user_id = ?',
      whereArgs: [userId],
      orderBy: 'day DESC',
      limit: days,
    );
  }

  // ---------------------------------------------------------------------------
  // Housekeeping
  // ---------------------------------------------------------------------------

  Future<void> close() async {
    await _db?.close();
    _db = null;
  }

  /// Wipes all data for a given user (e.g. on sign-out / profile deletion).
  Future<void> deleteUserData(String userId) async {
    final db = await database;
    await db.delete('srs_cards', where: 'user_id = ?', whereArgs: [userId]);
    await db.delete('activity_log', where: 'user_id = ?', whereArgs: [userId]);
  }
}
