import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/word_data.dart';

/// Snapshot of a learner's mastery for a single word.
class WordMasteryEntry {
  const WordMasteryEntry({
    required this.masteryLevel,
    this.lastReviewed,
    this.bestPronunciationStars = 0,
  });

  /// Mastery score in the range \[0.0, 1.0].
  final double masteryLevel;

  /// When the learner last reviewed this word in a meaningful way.
  final DateTime? lastReviewed;

  /// Best Gemini pronunciation rating (1–3) achieved for this word.
  final int bestPronunciationStars;

  /// Whether the learner has achieved a perfect (3-star) pronunciation.
  bool get isMastered => masteryLevel >= 1.0 || bestPronunciationStars >= 3;

  WordMasteryEntry copyWith({
    double? masteryLevel,
    DateTime? lastReviewed,
    int? bestPronunciationStars,
  }) {
    return WordMasteryEntry(
      masteryLevel: masteryLevel ?? this.masteryLevel,
      lastReviewed: lastReviewed ?? this.lastReviewed,
      bestPronunciationStars:
          bestPronunciationStars ?? this.bestPronunciationStars,
    );
  }

  Map<String, dynamic> toJson() => {
        'masteryLevel': masteryLevel,
        if (lastReviewed != null)
          'lastReviewed': lastReviewed!.toIso8601String(),
        if (bestPronunciationStars > 0)
          'bestPronunciationStars': bestPronunciationStars,
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

    return WordMasteryEntry(
      masteryLevel: _clampMastery(mastery),
      lastReviewed: lastReviewed,
      bestPronunciationStars: bestStars,
    );
  }

  static double _clampMastery(double value) {
    if (value.isNaN || value.isInfinite) {
      return 0.0;
    }
    return value.clamp(0.0, 1.0);
  }
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

    final nextEntry = current.copyWith(
      masteryLevel: WordMasteryEntry._clampMastery(nextMastery),
      bestPronunciationStars: nextStars,
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
    } catch (error, stackTrace) {
      debugPrint('WordMasteryService: Error saving mastery: $error');
      debugPrint('$stackTrace');
    }
  }

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
