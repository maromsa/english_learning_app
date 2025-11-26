import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Service for managing local user game data (coins, stars, etc.)
class LocalUserDataService {
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
          'user_${userId}_achievement_$achievementId', unlocked);
    } catch (e) {
      debugPrint('Error saving achievement for user $userId: $e');
    }
  }
}
