import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/word_data.dart';
import '../utils/srs_algorithm.dart';

/// Snapshot of a learner's mastery for a single word.
class WordMasteryEntry {
  const WordMasteryEntry({
    required this.masteryLevel,
    this.lastReviewed,
    this.bestPronunciationStars = 0,
    this.nextReviewDate,
    this.srsStreak = 0,
  });

  /// Mastery score in the range \[0.0, 1.0].
  final double masteryLevel;

  /// When the learner last reviewed this word in a meaningful way.
  final DateTime? lastReviewed;

  /// Best Gemini pronunciation rating (1–3) achieved for this word.
  final int bestPronunciationStars;

  /// When this word should next be presented for review, per
  /// [SrsAlgorithm]. Null until the first pronunciation score is recorded.
  final DateTime? nextReviewDate;

  /// Consecutive-3-star streak used by [SrsAlgorithm] to size the next
  /// review interval.
  final int srsStreak;

  /// Whether the learner has achieved a perfect (3-star) pronunciation.
  bool get isMastered => masteryLevel >= 1.0 || bestPronunciationStars >= 3;

  /// Whether this word is due for spaced-repetition review right now.
  bool get isDueForReview {
    if (nextReviewDate == null) return true;
    return !DateTime.now().isBefore(nextReviewDate!);
  }

  WordMasteryEntry copyWith({
    double? masteryLevel,
    DateTime? lastReviewed,
    int? bestPronunciationStars,
    DateTime? nextReviewDate,
    int? srsStreak,
  }) {
    return WordMasteryEntry(
      masteryLevel: masteryLevel ?? this.masteryLevel,
      lastReviewed: lastReviewed ?? this.lastReviewed,
      bestPronunciationStars:
          bestPronunciationStars ?? this.bestPronunciationStars,
      nextReviewDate: nextReviewDate ?? this.nextReviewDate,
      srsStreak: srsStreak ?? this.srsStreak,
    );
  }

  Map<String, dynamic> toJson() => {
        'masteryLevel': masteryLevel,
        if (lastReviewed != null)
          'lastReviewed': lastReviewed!.toIso8601String(),
        if (bestPronunciationStars > 0)
          'bestPronunciationStars': bestPronunciationStars,
        if (nextReviewDate != null)
          'nextReviewDate': nextReviewDate!.toIso8601String(),
        if (srsStreak > 0) 'srsStreak': srsStreak,
      };

  static WordMasteryEntry fromJson(Map<String, dynamic> json) {
    final rawMastery = json['masteryLevel'];
    double mastery = 0.0;
    if (rawMastery is num) {
      mastery = rawMastery.toDouble();
    } else if (rawMastery is String) {
      mastery = double.tryParse(rawMastery.trim()) ?? 0.0;
    }

    DateTime? lastReviewed;
    final rawReviewed = json['lastReviewed'];
    if (rawReviewed is String && rawReviewed.trim().isNotEmpty) {
      lastReviewed = DateTime.tryParse(rawReviewed.trim());
    } else if (rawReviewed is int) {
      try {
        lastReviewed = DateTime.fromMillisecondsSinceEpoch(rawReviewed);
      } catch (_) {
        lastReviewed = null;
      }
    }

    final rawStars = json['bestPronunciationStars'];
    var bestStars = 0;
    if (rawStars is int) {
      bestStars = rawStars.clamp(0, 3);
    } else if (rawStars is num) {
      bestStars = rawStars.toInt().clamp(0, 3);
    }

    DateTime? nextReviewDate;
    final rawNextReview = json['nextReviewDate'];
    if (rawNextReview is String && rawNextReview.trim().isNotEmpty) {
      nextReviewDate = DateTime.tryParse(rawNextReview.trim());
    } else if (rawNextReview is int) {
      try {
        nextReviewDate = DateTime.fromMillisecondsSinceEpoch(rawNextReview);
      } catch (_) {
        nextReviewDate = null;
      }
    }

    final rawStreak = json['srsStreak'];
    var srsStreak = 0;
    if (rawStreak is int) {
      srsStreak = rawStreak < 0 ? 0 : rawStreak;
    } else if (rawStreak is num) {
      final asInt = rawStreak.toInt();
      srsStreak = asInt < 0 ? 0 : asInt;
    }

    return WordMasteryEntry(
      masteryLevel: _clampMastery(mastery),
      lastReviewed: lastReviewed,
      bestPronunciationStars: bestStars,
      nextReviewDate: nextReviewDate,
      srsStreak: srsStreak,
    );
  }

  static double _clampMastery(double value) {
    if (value.isNaN || value.isInfinite) {
      return 0.0;
    }
    return value.clamp(0.0, 1.0);
  }
}

/// A single word due for spaced-repetition review, per [SrsAlgorithm].
class DueWordEntry {
  const DueWordEntry({
    required this.levelId,
    required this.word,
    required this.mastery,
  });

  /// The level this word belongs to.
  final String levelId;

  /// The word text, exactly as originally recorded (not sanitized/lowercased).
  final String word;

  /// The word's full mastery snapshot, including its `nextReviewDate` and
  /// `srsStreak`.
  final WordMasteryEntry mastery;
}

/// Service responsible for persisting and retrieving per-user word mastery.
///
/// Data is stored in SharedPreferences using versioned, namespaced keys so it
/// does not interfere with existing progress and coin/star persistence.
class WordMasteryService {
  WordMasteryService({
    SharedPreferences? prefs,
    String? namespacePrefix,
  })  : _prefsFuture = prefs != null
            ? Future.value(prefs)
            : SharedPreferences.getInstance(),
        _namespacePrefix = namespacePrefix ?? _defaultPrefix;

  static const String _defaultPrefix = 'word_mastery.v1';

  /// Separator used inside the per-user due-review index between a level id
  /// and a word — chosen because it cannot appear in either (unlike `.` or
  /// `_`, which level ids and words can legitimately contain).
  static const String _indexSeparator = '';

  final Future<SharedPreferences> _prefsFuture;
  final String _namespacePrefix;

  /// Returns the stored mastery entry for a word, or a default entry with
  /// mastery `0.0` when no data exists yet.
  Future<WordMasteryEntry> getMastery({
    required String userId,
    required String levelId,
    required String word,
  }) async {
    final prefs = await _prefsFuture;
    final key = _buildKey(userId, levelId, word);
    final raw = prefs.getString(key);
    if (raw == null || raw.isEmpty) {
      return const WordMasteryEntry(masteryLevel: 0.0, lastReviewed: null);
    }
    try {
      final decoded = jsonDecode(raw);
      if (decoded is Map<String, dynamic>) {
        return WordMasteryEntry.fromJson(decoded);
      }

      // Backward-friendly: if an older version ever stored just a number or
      // plain string, interpret it as the mastery value.
      if (decoded is num) {
        return WordMasteryEntry(
          masteryLevel: WordMasteryEntry._clampMastery(decoded.toDouble()),
          lastReviewed: null,
        );
      }
      if (decoded is String) {
        final parsed = double.tryParse(decoded.trim());
        if (parsed != null) {
          return WordMasteryEntry(
            masteryLevel: WordMasteryEntry._clampMastery(parsed),
            lastReviewed: null,
          );
        }
      }
    } catch (error, stackTrace) {
      debugPrint('Failed to decode mastery for $key: $error');
      debugPrint('$stackTrace');
    }

    return const WordMasteryEntry(masteryLevel: 0.0, lastReviewed: null);
  }

  /// Records a strong review signal for a word, typically when the learner
  /// successfully completes a word task.
  ///
  /// - Increases mastery by [delta] (default 0.25) up to a maximum of 1.0.
  /// - Updates [lastReviewed] to [reviewedAt] (or `DateTime.now()`).
  Future<WordMasteryEntry> recordSuccessfulReview({
    required String userId,
    required String levelId,
    required String word,
    double delta = 0.25,
    DateTime? reviewedAt,
  }) async {
    final current = await getMastery(
      userId: userId,
      levelId: levelId,
      word: word,
    );

    final nextMastery =
        WordMasteryEntry._clampMastery(current.masteryLevel + delta);
    final nextEntry = current.copyWith(
      masteryLevel: nextMastery,
      lastReviewed: reviewedAt ?? DateTime.now(),
    );

    await _saveEntry(
      userId: userId,
      levelId: levelId,
      word: word,
      entry: nextEntry,
    );
    return nextEntry;
  }

  /// Records a pronunciation score from Gemini (1–3 stars).
  ///
  /// Keeps the best star rating seen so far and raises [masteryLevel] to at
  /// least `stars / 3`. A 3-star attempt sets full mastery (`1.0`).
  ///
  /// Also runs [SrsAlgorithm] against this grade to schedule the word's next
  /// spaced-repetition review ([WordMasteryEntry.nextReviewDate]) and update
  /// its streak ([WordMasteryEntry.srsStreak]).
  Future<WordMasteryEntry> recordPronunciationScore({
    required String userId,
    required String levelId,
    required String word,
    required int stars,
    DateTime? reviewedAt,
  }) async {
    final clampedStars = stars.clamp(1, 3);
    final current = await getMastery(
      userId: userId,
      levelId: levelId,
      word: word,
    );

    final nextStars = clampedStars > current.bestPronunciationStars
        ? clampedStars
        : current.bestPronunciationStars;
    final masteryFromStars = nextStars / 3.0;
    var nextMastery = current.masteryLevel > masteryFromStars
        ? current.masteryLevel
        : masteryFromStars;
    if (clampedStars == 3) {
      nextMastery = 1.0;
    }

    final srsResult = SrsAlgorithm.computeNextReview(
      stars: clampedStars,
      currentStreak: current.srsStreak,
      now: reviewedAt,
    );

    final nextEntry = current.copyWith(
      masteryLevel: WordMasteryEntry._clampMastery(nextMastery),
      bestPronunciationStars: nextStars,
      lastReviewed: reviewedAt ?? DateTime.now(),
      nextReviewDate: srsResult.nextReviewDate,
      srsStreak: srsResult.streak,
    );

    await _saveEntry(
      userId: userId,
      levelId: levelId,
      word: word,
      entry: nextEntry,
    );
    return nextEntry;
  }

  /// Sets the mastery for a word explicitly (for example when importing legacy
  /// completion data or when a word is considered fully mastered).
  Future<WordMasteryEntry> setMastery({
    required String userId,
    required String levelId,
    required String word,
    required double masteryLevel,
    DateTime? lastReviewed,
  }) async {
    final entry = WordMasteryEntry(
      masteryLevel: WordMasteryEntry._clampMastery(masteryLevel),
      lastReviewed: lastReviewed ?? DateTime.now(),
    );
    await _saveEntry(
      userId: userId,
      levelId: levelId,
      word: word,
      entry: entry,
    );
    return entry;
  }

  /// Convenience helper to merge mastery into an existing [WordData] instance.
  WordData applyToWord(WordData word, WordMasteryEntry mastery) {
    return WordData(
      word: word.word,
      searchHint: word.searchHint,
      publicId: word.publicId,
      imageUrl: word.imageUrl,
      isCompleted: word.isCompleted,
      stickerUnlocked: word.stickerUnlocked,
      masteryLevel: mastery.masteryLevel,
      lastReviewed: mastery.lastReviewed,
    );
  }

  /// Returns every word (across all levels, unless [levelId] narrows it to
  /// one) that is due for spaced-repetition review right now — i.e. has a
  /// `nextReviewDate` at or before [now] (defaults to [DateTime.now]).
  ///
  /// Words that have never been graded via [recordPronunciationScore] have
  /// no `nextReviewDate` yet and are not "due" in this sense — they simply
  /// haven't entered the review cycle.
  Future<List<DueWordEntry>> getWordsDueForReview({
    required String userId,
    String? levelId,
    DateTime? now,
  }) async {
    final prefs = await _prefsFuture;
    final indexed = prefs.getStringList(_indexKey(userId)) ?? const <String>[];
    final today = now ?? DateTime.now();

    final due = <DueWordEntry>[];
    for (final composite in indexed) {
      final separatorIndex = composite.indexOf(_indexSeparator);
      if (separatorIndex < 0) continue;
      final entryLevelId = composite.substring(0, separatorIndex);
      final entryWord = composite.substring(separatorIndex + 1);
      if (levelId != null && entryLevelId != levelId) continue;

      final mastery = await getMastery(
        userId: userId,
        levelId: entryLevelId,
        word: entryWord,
      );
      final reviewDate = mastery.nextReviewDate;
      if (reviewDate != null && !today.isBefore(reviewDate)) {
        due.add(
          DueWordEntry(
            levelId: entryLevelId,
            word: entryWord,
            mastery: mastery,
          ),
        );
      }
    }
    return due;
  }

  /// Returns the highest `srsStreak` across every word this user has ever
  /// graded via [recordPronunciationScore] — an all-time high-water mark,
  /// unlike [getWordsDueForReview] which only considers words due *right
  /// now*. A long-streak word gets a longer review interval and so spends
  /// most of its time not due, meaning it wouldn't show up there at all.
  ///
  /// Returns 0 when the user has never been graded.
  Future<int> getHighestSrsStreak(String userId) async {
    final prefs = await _prefsFuture;
    final indexed = prefs.getStringList(_indexKey(userId)) ?? const <String>[];

    var highest = 0;
    for (final composite in indexed) {
      final separatorIndex = composite.indexOf(_indexSeparator);
      if (separatorIndex < 0) continue;
      final entryLevelId = composite.substring(0, separatorIndex);
      final entryWord = composite.substring(separatorIndex + 1);

      final mastery = await getMastery(
        userId: userId,
        levelId: entryLevelId,
        word: entryWord,
      );
      if (mastery.srsStreak > highest) {
        highest = mastery.srsStreak;
      }
    }
    return highest;
  }

  /// Convenience wrapper around [getWordsDueForReview] for a single level:
  /// resolves the due word ids against [catalog] (that level's full word
  /// list) and returns the matching [WordData], merged with each word's
  /// mastery via [applyToWord].
  ///
  /// Words in the due index that no longer exist in [catalog] (e.g. removed
  /// from the level's data since they were last graded) are silently
  /// skipped rather than surfaced as an error.
  Future<List<WordData>> getDueWordDataForLevel({
    required String userId,
    required String levelId,
    required List<WordData> catalog,
    DateTime? now,
  }) async {
    final dueEntries = await getWordsDueForReview(
      userId: userId,
      levelId: levelId,
      now: now,
    );
    if (dueEntries.isEmpty) return const <WordData>[];

    final masteryByLowerWord = <String, WordMasteryEntry>{
      for (final entry in dueEntries) entry.word.toLowerCase(): entry.mastery,
    };

    final result = <WordData>[];
    for (final word in catalog) {
      final mastery = masteryByLowerWord[word.word.toLowerCase()];
      if (mastery != null) {
        result.add(applyToWord(word, mastery));
      }
    }
    return result;
  }

  Future<void> _saveEntry({
    required String userId,
    required String levelId,
    required String word,
    required WordMasteryEntry entry,
  }) async {
    try {
      final prefs = await _prefsFuture;
      final key = _buildKey(userId, levelId, word);
      final encoded = jsonEncode(entry.toJson());
      final ok = await prefs.setString(key, encoded);
      if (!ok) {
        debugPrint('WordMasteryService: Failed to persist $key');
      }
      await _addToIndex(prefs, userId: userId, levelId: levelId, word: word);
    } catch (error, stackTrace) {
      debugPrint('WordMasteryService: Error saving mastery: $error');
      debugPrint('$stackTrace');
    }
  }

  /// Records that (userId, levelId, word) has a stored mastery entry, so
  /// [getWordsDueForReview] can enumerate it later without having to guess
  /// original level/word text back out of [_buildKey]'s sanitized form.
  Future<void> _addToIndex(
    SharedPreferences prefs, {
    required String userId,
    required String levelId,
    required String word,
  }) async {
    final indexKey = _indexKey(userId);
    final existing = prefs.getStringList(indexKey) ?? <String>[];
    final composite = '$levelId$_indexSeparator$word';
    if (!existing.contains(composite)) {
      existing.add(composite);
      await prefs.setStringList(indexKey, existing);
    }
  }

  String _indexKey(String userId) =>
      '$_namespacePrefix.index.${_sanitize(userId)}';

  String _buildKey(String userId, String levelId, String word) {
    final normalizedUser = _sanitize(userId);
    final normalizedLevel = _sanitize(levelId);
    final normalizedWord = _sanitize(word.toLowerCase());
    return '$_namespacePrefix.$normalizedUser.$normalizedLevel.$normalizedWord';
  }

  String _sanitize(String value) {
    return value.replaceAll(RegExp(r'[^a-zA-Z0-9_\-]'), '_');
  }
}
