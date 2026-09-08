import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Service for managing local user game data (coins, stars, etc.)
class LocalUserDataService {
  /// `<year>-MM-DD` (year not zero-padded, month/day are) — matches
  /// `ParentProgressService._dayKey` so the two daily logs line up.
  static String dayKey(DateTime date) =>
      '${date.year}-${date.month.toString().padLeft(2, '0')}-'
      '${date.day.toString().padLeft(2, '0')}';

  /// Get coins for a specific user
  Future<int> getCoins(String userId) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return prefs.getInt('user_${userId}_coins') ?? 0;
    } catch (e) {
      debugPrint('Error loading coins for user $userId: $e');
      return 0;
    }
  }

  /// Save coins for a specific user
  Future<void> saveCoins(String userId, int coins) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setInt('user_${userId}_coins', coins);
    } catch (e) {
      debugPrint('Error saving coins for user $userId: $e');
    }
  }

  /// Get the calendar day (`YYYY-MM-DD`) the Daily Practice reward was last
  /// claimed on for a user, or `null` if never claimed.
  Future<String?> getLastDailyPracticeRewardDate(String userId) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return prefs.getString('user_${userId}_daily_practice_reward_date');
    } catch (e) {
      debugPrint(
        'Error loading daily practice reward date for user $userId: $e',
      );
      return null;
    }
  }

  /// Save the calendar day (`YYYY-MM-DD`) the Daily Practice reward was
  /// claimed on for a user.
  Future<void> saveLastDailyPracticeRewardDate(
    String userId,
    String date,
  ) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('user_${userId}_daily_practice_reward_date', date);
    } catch (e) {
      debugPrint(
        'Error saving daily practice reward date for user $userId: $e',
      );
    }
  }

  /// Get stars for a specific level and user
  Future<int> getLevelStars(String userId, String levelId) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return prefs.getInt('user_${userId}_level_${levelId}_stars') ?? 0;
    } catch (e) {
      debugPrint('Error loading stars for user $userId, level $levelId: $e');
      return 0;
    }
  }

  /// Save stars for a specific level and user
  Future<void> saveLevelStars(String userId, String levelId, int stars) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setInt('user_${userId}_level_${levelId}_stars', stars);
    } catch (e) {
      debugPrint('Error saving stars for user $userId, level $levelId: $e');
    }
  }

  /// Get all level stars for a user
  Future<Map<String, int>> getAllLevelStars(String userId) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final keys = prefs.getKeys().where(
            (key) =>
                key.startsWith('user_${userId}_level_') &&
                key.endsWith('_stars'),
          );

      final Map<String, int> stars = {};
      for (final key in keys) {
        final levelId = key
            .replaceFirst('user_${userId}_level_', '')
            .replaceFirst('_stars', '');
        stars[levelId] = prefs.getInt(key) ?? 0;
      }
      return stars;
    } catch (e) {
      debugPrint('Error loading all level stars for user $userId: $e');
      return {};
    }
  }

  /// Clear all data for a user (for reset progress)
  Future<void> clearUserData(String userId) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final keys =
          prefs.getKeys().where((key) => key.startsWith('user_${userId}_'));
      for (final key in keys) {
        await prefs.remove(key);
      }
    } catch (e) {
      debugPrint('Error clearing data for user $userId: $e');
    }
  }

  /// Get purchased items for a user
  Future<List<String>> getPurchasedItems(String userId) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final itemsJson = prefs.getString('user_${userId}_purchased_items');
      if (itemsJson == null || itemsJson.isEmpty) {
        return [];
      }
      return List<String>.from(
        (itemsJson.split(',').where((item) => item.isNotEmpty)),
      );
    } catch (e) {
      debugPrint('Error loading purchased items for user $userId: $e');
      return [];
    }
  }

  /// Save purchased items for a user
  Future<void> savePurchasedItems(String userId, List<String> items) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(
        'user_${userId}_purchased_items',
        items.join(','),
      );
    } catch (e) {
      debugPrint('Error saving purchased items for user $userId: $e');
    }
  }

  /// Get achievement status for a user
  Future<bool> getAchievementStatus(String userId, String achievementId) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return prefs.getBool('user_${userId}_achievement_$achievementId') ??
          false;
    } catch (e) {
      debugPrint('Error loading achievement for user $userId: $e');
      return false;
    }
  }

  /// Save achievement status for a user
  Future<void> saveAchievementStatus(
    String userId,
    String achievementId,
    bool unlocked,
  ) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(
        'user_${userId}_achievement_$achievementId',
        unlocked,
      );
    } catch (e) {
      debugPrint('Error saving achievement for user $userId: $e');
    }
  }

  // ── Daily "coins earned" log (feeds the Weekly Parent Recap) ───────────────

  static String _coinsEarnedKey(String userId) =>
      'user_${userId}_daily_coins_earned';

  /// Adds [amount] to today's "coins earned" tally for [userId]. Rewards only —
  /// callers must not pass spends. Best-effort: a failure is swallowed so it
  /// can never disrupt the coin grant that triggered it. Keeps ~35 days.
  Future<void> recordCoinsEarned(String userId, int amount,
      {DateTime? now}) async {
    if (amount <= 0) return;
    try {
      final prefs = await SharedPreferences.getInstance();
      final key = _coinsEarnedKey(userId);
      final raw = prefs.getString(key);
      final log = <String, int>{};
      if (raw != null && raw.isNotEmpty) {
        final decoded = jsonDecode(raw);
        if (decoded is Map) {
          decoded.forEach((k, v) {
            if (k is String && v is int) log[k] = v;
          });
        }
      }

      final today = dayKey(now ?? DateTime.now());
      log[today] = (log[today] ?? 0) + amount;

      if (log.length > 35) {
        final ordered = log.keys.toList()..sort();
        for (final stale in ordered.take(log.length - 35)) {
          log.remove(stale);
        }
      }
      await prefs.setString(key, jsonEncode(log));
    } catch (e) {
      debugPrint('Error recording coins earned for user $userId: $e');
    }
  }

  /// Total coins earned by [userId] over the last 7 calendar days ending on
  /// [now] (defaults to today) — the window used by the Weekly Parent Recap.
  Future<int> weeklyCoinsEarned(String userId, {DateTime? now}) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_coinsEarnedKey(userId));
      if (raw == null || raw.isEmpty) return 0;
      final decoded = jsonDecode(raw);
      if (decoded is! Map) return 0;

      final today = now ?? DateTime.now();
      final cutoff = DateTime(today.year, today.month, today.day)
          .subtract(const Duration(days: 6));

      var total = 0;
      decoded.forEach((k, v) {
        if (k is! String || v is! int) return;
        final day = DateTime.tryParse(k);
        if (day != null && !day.isBefore(cutoff)) total += v;
      });
      return total;
    } catch (e) {
      debugPrint('Error reading weekly coins for user $userId: $e');
      return 0;
    }
  }
}
