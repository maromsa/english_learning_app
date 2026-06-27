// lib/services/srs_service.dart
//
// SRS (Spaced Repetition System) Service — SM-2 implementation.
//
// Responsibilities:
//   1. Persist SrsCard state per user in SQLite (AppDatabase) + SharedPreferences.
//   2. Provide a due-word queue sorted by overdue-ness and mastery.
//   3. Record reviews (correct / incorrect / pronunciation stars).
//   4. Migrate legacy WordMasteryEntry data into SrsCard format.
//   5. Sync dirty cards to Firestore via SyncEngine (offline-first).
//
// Storage key format (SharedPreferences — kept for backwards compat):
//   srs.v1.<userId>.<levelId>.<wordId>

import 'dart:async';
import 'dart:convert';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/srs_card.dart';
import '../models/word_data.dart';
import 'app_database.dart';
import 'notification_service.dart';
import 'sync_engine.dart';
import 'word_mastery_service.dart';

/// Converts a raw SM-2 grade (0–5) from a simple correct/incorrect signal.
///
/// Use this when you only know pass/fail, not the nuanced difficulty.
/// Correct → grade 4 (good), Incorrect → grade 1 (remembered after seeing).
int gradeFromCorrect(bool correct) => correct ? 4 : 1;

class SrsService {
  SrsService({
    SharedPreferences? prefs,
    FirebaseFirestore? firestore,
    WordMasteryService? legacyMasteryService,
    String? namespacePrefix,
    AppDatabase? db,
    SyncEngine? syncEngine,
  })  : _prefsFuture = prefs != null
            ? Future.value(prefs)
            : SharedPreferences.getInstance(),
        _firestore = firestore ?? FirebaseFirestore.instance,
        _legacyService = legacyMasteryService ?? WordMasteryService(),
        _prefix = namespacePrefix ?? _defaultPrefix,
        _db = db ?? AppDatabase.instance,
        _syncEngine = syncEngine;

  static const String _defaultPrefix = 'srs.v1';
  static const String _firestoreCollection = 'srs_cards';

  final Future<SharedPreferences> _prefsFuture;
  final FirebaseFirestore _firestore;
  final WordMasteryService _legacyService;
  final String _prefix;
  final AppDatabase _db;
  SyncEngine? _syncEngine;

  SyncEngine get _sync => _syncEngine ??= SyncEngine(db: _db);

  // In-memory cache to avoid repeated JSON parses within a session.
  final Map<String, SrsCard> _cache = {};

  // ---------------------------------------------------------------------------
  // Public API
  // ---------------------------------------------------------------------------

  /// Returns the SrsCard for a word, migrating legacy mastery data if needed.
  Future<SrsCard> getCard({
    required String userId,
    required String levelId,
    required String word,
  }) async {
    final key = _cacheKey(userId, levelId, word);
    if (_cache.containsKey(key)) return _cache[key]!;

    // 1. Try SQLite first (primary offline store).
    final dbRow = await _db.getSrsCard(
      userId: userId,
      levelId: levelId,
      wordId: word.toLowerCase(),
    );
    if (dbRow != null) {
      final card = _cardFromRow(dbRow);
      _cache[key] = card;
      return card;
    }

    // 2. Fallback to SharedPreferences (legacy / migration path).
    final stored = await _loadFromPrefs(userId, levelId, word);
    if (stored != null) {
      _cache[key] = stored;
      // Write to SQLite so future reads are faster.
      await _saveToDb(userId, levelId, stored);
      return stored;
    }

    // 3. Migrate from legacy WordMasteryEntry if available.
    final legacy = await _legacyService.getMastery(
      userId: userId,
      levelId: levelId,
      word: word,
    );

    final card = _migrateFromLegacy(word, legacy);
    _cache[key] = card;
    // Persist migrated card so we don't re-migrate every session.
    await _saveToPrefs(userId, levelId, card);
    await _saveToDb(userId, levelId, card);
    return card;
  }

  /// Returns all cards for a level.
  Future<List<SrsCard>> getAllCards({
    required String userId,
    required String levelId,
    required List<WordData> words,
  }) async {
    final results = <SrsCard>[];
    for (final word in words) {
      final card = await getCard(
        userId: userId,
        levelId: levelId,
        word: word.word,
      );
      results.add(card);
    }
    return results;
  }

  /// Returns words sorted for a review session.
  ///
  /// Ordering:
  ///   1. Due cards (nextReviewDate ≤ now), sorted by most overdue first.
  ///   2. New cards (never reviewed), sorted by natural order.
  ///   3. Not-yet-due cards, sorted by next review date ascending.
  Future<List<WordData>> getSortedForSession({
    required String userId,
    required String levelId,
    required List<WordData> words,
  }) async {
    final cards = await getAllCards(
      userId: userId,
      levelId: levelId,
      words: words,
    );

    final cardMap = {for (final c in cards) c.wordId.toLowerCase(): c};
    final now = DateTime.now();

    int sortKey(WordData w) {
      final card = cardMap[w.word.toLowerCase()];
      if (card == null || card.lastReviewDate == null) return 0; // new — second
      if (card.isDue) return -1; // due — first
      return 1; // future — last
    }

    final sorted = List<WordData>.from(words);
    sorted.sort((a, b) {
      final ka = sortKey(a);
      final kb = sortKey(b);
      if (ka != kb) return ka.compareTo(kb);

      final ca = cardMap[a.word.toLowerCase()];
      final cb = cardMap[b.word.toLowerCase()];
      if (ca == null && cb == null) return 0;
      if (ca == null) return 1;
      if (cb == null) return -1;

      if (ka == -1) {
        // Both due — most overdue first (smallest nextReviewDate).
        final dateA = ca.nextReviewDate ?? now;
        final dateB = cb.nextReviewDate ?? now;
        return dateA.compareTo(dateB);
      }
      if (ka == 1) {
        // Both future — soonest next review first.
        final dateA = ca.nextReviewDate ?? now;
        final dateB = cb.nextReviewDate ?? now;
        return dateA.compareTo(dateB);
      }
      // Both new — keep natural order.
      return 0;
    });

    return sorted;
  }

  /// Records a review result and persists the updated card.
  ///
  /// [grade] is SM-2 grade 0–5. Use [gradeFromCorrect] for simple pass/fail.
  Future<SrsCard> recordReview({
    required String userId,
    required String levelId,
    required String word,
    required int grade,
    DateTime? reviewedAt,
  }) async {
    final current = await getCard(userId: userId, levelId: levelId, word: word);
    final updated = current.review(grade: grade, reviewedAt: reviewedAt);

    await _persist(userId, levelId, updated);

    // Also keep legacy WordMasteryService in sync so existing UI (progress bars,
    // level completion) continues to work without changes.
    await _syncToLegacy(userId, levelId, word, updated);

    return updated;
  }

  /// Records a pronunciation score (1–3 stars).
  Future<SrsCard> recordPronunciationScore({
    required String userId,
    required String levelId,
    required String word,
    required int stars,
    DateTime? reviewedAt,
  }) async {
    final current = await getCard(userId: userId, levelId: levelId, word: word);
    final updated = current
        .withPronunciationScore(stars)
        .copyWith(lastReviewDate: reviewedAt ?? DateTime.now());

    await _persist(userId, levelId, updated);
    await _syncToLegacy(userId, levelId, word, updated);
    return updated;
  }

  /// Counts how many cards are due right now for a level.
  Future<int> countDue({
    required String userId,
    required String levelId,
    required List<WordData> words,
  }) async {
    int count = 0;
    for (final word in words) {
      final card = await getCard(
          userId: userId, levelId: levelId, word: word.word);
      if (card.isDue) count++;
    }
    return count;
  }

  /// Returns the weakest N words (lowest mastery that have been seen at least once).
  Future<List<WordData>> getWeakWords({
    required String userId,
    required String levelId,
    required List<WordData> allWords,
    int limit = 5,
  }) async {
    final cards = await getAllCards(
      userId: userId,
      levelId: levelId,
      words: allWords,
    );
    final cardMap = {for (final c in cards) c.wordId.toLowerCase(): c};

    final seen = allWords
        .where((w) =>
            (cardMap[w.word.toLowerCase()]?.lastReviewDate) != null)
        .toList();

    seen.sort((a, b) {
      final ma = cardMap[a.word.toLowerCase()]?.masteryLevel ?? 0.0;
      final mb = cardMap[b.word.toLowerCase()]?.masteryLevel ?? 0.0;
      return ma.compareTo(mb); // ascending — weakest first
    });

    return seen.take(limit).toList();
  }

  /// Syncs all dirty SRS cards to Firestore via SyncEngine (offline-first).
  ///
  /// The SyncEngine reads from SQLite (dirty=1 rows) and batch-uploads to
  /// Firestore, then marks rows clean. If offline, dirty rows remain and will
  /// be retried on the next call.
  Future<void> syncToFirestore({
    required String userId,
    required String levelId,
    required List<WordData> words,
  }) async {
    try {
      final synced = await _sync.syncDirtyCards(userId);
      if (synced > 0) {
        debugPrint('SrsService: synced $synced dirty cards to Firestore');
      }
    } catch (e) {
      debugPrint('SrsService.syncToFirestore: $e');
    }

    // After sync, schedule an SRS reminder for the next due card.
    unawaited(_scheduleNextSrsReminder(userId));
  }

  /// Reads the earliest next-review date from SQLite and schedules a
  /// local notification. No-op on web or if no cards have a future due date.
  Future<void> _scheduleNextSrsReminder(String userId) async {
    try {
      final rows = await _db.getAllSrsCards(userId: userId);
      DateTime? earliest;
      final now = DateTime.now();
      for (final row in rows) {
        final ms = row['next_review_ms'] as int?;
        if (ms == null) continue;
        final dt = DateTime.fromMillisecondsSinceEpoch(ms);
        if (dt.isBefore(now)) continue;
        if (earliest == null || dt.isBefore(earliest)) earliest = dt;
      }
      if (earliest != null) {
        await NotificationService.instance.scheduleSrsReminder(when: earliest);
      }
    } catch (e) {
      debugPrint('SrsService._scheduleNextSrsReminder: $e');
    }
  }

  /// Pulls Firestore data for [levelId] and merges into local SQLite.
  /// Call once per level when the user opens it for the first time or
  /// explicitly refreshes.
  Future<void> pullFromFirestore({
    required String userId,
    required String levelId,
  }) async {
    await _sync.pullLevelFromFirestore(userId: userId, levelId: levelId);
  }

  // ---------------------------------------------------------------------------
  // Internal helpers
  // ---------------------------------------------------------------------------

  Future<void> _persist(String userId, String levelId, SrsCard card) async {
    _cache[_cacheKey(userId, levelId, card.wordId)] = card;
    // Dual-write: SQLite (primary) + SharedPreferences (legacy fallback).
    await Future.wait([
      _saveToDb(userId, levelId, card, dirty: true),
      _saveToPrefs(userId, levelId, card),
    ]);
  }

  Future<void> _syncToLegacy(
    String userId,
    String levelId,
    String word,
    SrsCard card,
  ) async {
    try {
      await _legacyService.setMastery(
        userId: userId,
        levelId: levelId,
        word: word,
        masteryLevel: card.masteryLevel,
        lastReviewed: card.lastReviewDate,
      );
    } catch (e) {
      debugPrint('SrsService._syncToLegacy: $e');
    }
  }

  Future<SrsCard?> _loadFromPrefs(
      String userId, String levelId, String word) async {
    try {
      final prefs = await _prefsFuture;
      final key = _prefsKey(userId, levelId, word);
      final raw = prefs.getString(key);
      if (raw == null || raw.isEmpty) return null;
      final json = jsonDecode(raw) as Map<String, dynamic>;
      return SrsCard.fromJson(json);
    } catch (e) {
      debugPrint('SrsService._loadFromPrefs: $e');
      return null;
    }
  }

  Future<void> _saveToPrefs(
      String userId, String levelId, SrsCard card) async {
    try {
      final prefs = await _prefsFuture;
      final key = _prefsKey(userId, levelId, card.wordId);
      await prefs.setString(key, jsonEncode(card.toJson()));
    } catch (e) {
      debugPrint('SrsService._saveToPrefs: $e');
    }
  }

  SrsCard _migrateFromLegacy(String word, WordMasteryEntry legacy) {
    if (legacy.masteryLevel == 0.0 && legacy.lastReviewed == null) {
      return SrsCard(wordId: word.toLowerCase());
    }

    // Estimate SM-2 state from legacy mastery level.
    // mastery 0.25 → 1 rep, 0.5 → 2 reps, 0.75 → 3 reps, 1.0 → 4+ reps.
    final estimatedReps = (legacy.masteryLevel * 4).round().clamp(0, 5);
    final estimatedInterval =
        estimatedReps == 0 ? 1 : [1, 1, 6, 12, 24, 48][estimatedReps];
    final nextReview = legacy.lastReviewed != null
        ? legacy.lastReviewed!.add(Duration(days: estimatedInterval))
        : DateTime.now();

    return SrsCard(
      wordId: word.toLowerCase(),
      repetitions: estimatedReps,
      easeFactor: 2.5,
      intervalDays: estimatedInterval,
      nextReviewDate: nextReview,
      lastReviewDate: legacy.lastReviewed,
      masteryLevel: legacy.masteryLevel,
      bestPronunciationStars: legacy.bestPronunciationStars,
    );
  }

  String _cacheKey(String userId, String levelId, String word) =>
      '$userId|$levelId|${word.toLowerCase()}';

  String _prefsKey(String userId, String levelId, String word) {
    return '$_prefix.${_sanitize(userId)}.${_sanitize(levelId)}.${_sanitize(word.toLowerCase())}';
  }

  String _sanitize(String value) =>
      value.replaceAll(RegExp(r'[^a-zA-Z0-9_\-]'), '_');

  // ---------------------------------------------------------------------------
  // SQLite helpers
  // ---------------------------------------------------------------------------

  Future<void> _saveToDb(
    String userId,
    String levelId,
    SrsCard card, {
    bool dirty = false,
  }) async {
    try {
      await _db.upsertSrsCard(
        userId: userId,
        levelId: levelId,
        wordId: card.wordId.toLowerCase(),
        repetitions: card.repetitions,
        easeFactor: card.easeFactor,
        intervalDays: card.intervalDays,
        masteryLevel: card.masteryLevel,
        bestStars: card.bestPronunciationStars,
        nextReviewDate: card.nextReviewDate,
        lastReviewDate: card.lastReviewDate,
        dirty: dirty,
      );
    } catch (e) {
      debugPrint('SrsService._saveToDb: $e');
    }
  }

  SrsCard _cardFromRow(Map<String, dynamic> row) {
    return SrsCard(
      wordId: row['word_id'] as String,
      repetitions: (row['repetitions'] as int?) ?? 0,
      easeFactor: (row['ease_factor'] as num?)?.toDouble() ?? 2.5,
      intervalDays: (row['interval_days'] as int?) ?? 1,
      masteryLevel: (row['mastery_level'] as num?)?.toDouble() ?? 0.0,
      bestPronunciationStars: (row['best_stars'] as int?) ?? 0,
      nextReviewDate: row['next_review_ms'] != null
          ? DateTime.fromMillisecondsSinceEpoch(row['next_review_ms'] as int)
          : null,
      lastReviewDate: row['last_review_ms'] != null
          ? DateTime.fromMillisecondsSinceEpoch(row['last_review_ms'] as int)
          : null,
    );
  }
}
