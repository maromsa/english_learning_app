import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';

import '../models/player_data.dart';

/// Service for managing player game data in Firestore
class UserDataService {
  UserDataService({FirebaseFirestore? firestore})
      : _firestore = firestore ?? FirebaseFirestore.instance;

  final FirebaseFirestore _firestore;

  /// Get the player data document reference
  DocumentReference<Map<String, dynamic>> _playerDataDoc(String userId) {
    return _firestore.collection('users').doc(userId).collection('gameData').doc('player');
  }

  /// Load player data from Firestore
  Future<PlayerData?> loadPlayerData(String userId) async {
    try {
      final doc = await _playerDataDoc(userId).get();
      if (!doc.exists) {
        debugPrint('Player data not found for user: $userId');
        return null;
      }
      return PlayerData.fromDocument(doc);
    } catch (e) {
      debugPrint('Error loading player data: $e');
      return null;
    }
  }

  /// Save player data to Firestore
  Future<bool> savePlayerData(PlayerData playerData) async {
    try {
      final data = playerData.toMap();
      // Don't overwrite createdAt if it already exists
      if (playerData.createdAt == null) {
        data['createdAt'] = FieldValue.serverTimestamp();
      } else {
        data['createdAt'] = Timestamp.fromDate(playerData.createdAt!);
      }

      await _playerDataDoc(playerData.userId).set(data, SetOptions(merge: true));
      debugPrint('Player data saved successfully for user: ${playerData.userId}');
      return true;
    } catch (e) {
      debugPrint('Error saving player data: $e');
      return false;
    }
  }

  /// Update specific fields in player data (partial update)
  Future<bool> updatePlayerData(
    String userId,
    Map<String, dynamic> updates,
  ) async {
    try {
      updates['updatedAt'] = FieldValue.serverTimestamp();
      await _playerDataDoc(userId).update(updates);
      debugPrint('Player data updated successfully for user: $userId');
      return true;
    } catch (e) {
      debugPrint('Error updating player data: $e');
      return false;
    }
  }

  /// Update coins
  Future<bool> updateCoins(String userId, int coins) async {
    return updatePlayerData(userId, {'coins': coins});
  }

  /// Add purchased item
  Future<bool> addPurchasedItem(String userId, String itemId) async {
    try {
      await _playerDataDoc(userId).update({
        'purchasedItems': FieldValue.arrayUnion([itemId]),
        'updatedAt': FieldValue.serverTimestamp(),
      });
      return true;
    } catch (e) {
      debugPrint('Error adding purchased item: $e');
      return false;
    }
  }

  /// Unlock achievement
  Future<bool> unlockAchievement(String userId, String achievementId) async {
    try {
      await _playerDataDoc(userId).update({
        'achievements.$achievementId': true,
        'updatedAt': FieldValue.serverTimestamp(),
      });
      return true;
    } catch (e) {
      debugPrint('Error unlocking achievement: $e');
      return false;
    }
  }

  /// Update level progress
  Future<bool> updateLevelProgress(
    String userId,
    String levelId,
    LevelProgress progress,
  ) async {
    try {
      await _playerDataDoc(userId).update({
        'levelProgress.$levelId': progress.toMap(),
        'updatedAt': FieldValue.serverTimestamp(),
      });
      return true;
    } catch (e) {
      debugPrint('Error updating level progress: $e');
      return false;
    }
  }

  /// Update daily streak
  Future<bool> updateDailyStreak(
    String userId,
    int streak,
    DateTime? lastClaim,
  ) async {
    final updates = <String, dynamic>{
      'dailyStreak': streak,
      'updatedAt': FieldValue.serverTimestamp(),
    };
    if (lastClaim != null) {
      updates['lastDailyRewardClaim'] = Timestamp.fromDate(lastClaim);
    }
    return updatePlayerData(userId, updates);
  }

  /// Increment statistics
  Future<bool> incrementStat(String userId, String statName, {int amount = 1}) async {
    try {
      await _playerDataDoc(userId).update({
        statName: FieldValue.increment(amount),
        'updatedAt': FieldValue.serverTimestamp(),
      });
      return true;
    } catch (e) {
      debugPrint('Error incrementing stat $statName: $e');
      return false;
    }
  }

  /// Update player character
  Future<bool> updateCharacter(String userId, Map<String, dynamic> characterData) async {
    try {
      await _playerDataDoc(userId).update({
        'character': characterData,
        'updatedAt': FieldValue.serverTimestamp(),
      });
      debugPrint('Character updated successfully for user: $userId');
      return true;
    } catch (e) {
      debugPrint('Error updating character: $e');
      return false;
    }
  }

  /// Sync local data with cloud (merge strategy: cloud wins on conflict)
  Future<PlayerData?> syncWithCloud(String userId, PlayerData localData) async {
    try {
      final cloudData = await loadPlayerData(userId);
      
      if (cloudData == null) {
        // No cloud data exists, save local data
        await savePlayerData(localData);
        return localData;
      }

      // Merge strategy: take maximum values for stats, union for lists
      final merged = PlayerData(
        userId: userId,
        coins: cloudData.coins > localData.coins ? cloudData.coins : localData.coins,
        purchasedItems: [
          ...cloudData.purchasedItems,
          ...localData.purchasedItems,
        ].toSet().toList(),
        achievements: {
          ...cloudData.achievements,
          ...localData.achievements,
        },
        levelProgress: {
          ...cloudData.levelProgress,
          ...localData.levelProgress,
        },
        dailyStreak: cloudData.dailyStreak > localData.dailyStreak
            ? cloudData.dailyStreak
            : localData.dailyStreak,
        lastDailyRewardClaim: cloudData.lastDailyRewardClaim != null &&
                (localData.lastDailyRewardClaim == null ||
                    cloudData.lastDailyRewardClaim!.isAfter(localData.lastDailyRewardClaim!))
            ? cloudData.lastDailyRewardClaim
            : localData.lastDailyRewardClaim,
        totalWordsCompleted: cloudData.totalWordsCompleted > localData.totalWordsCompleted
            ? cloudData.totalWordsCompleted
            : localData.totalWordsCompleted,
        totalQuizzesPlayed: cloudData.totalQuizzesPlayed > localData.totalQuizzesPlayed
            ? cloudData.totalQuizzesPlayed
            : localData.totalQuizzesPlayed,
        bestQuizStreak: cloudData.bestQuizStreak > localData.bestQuizStreak
            ? cloudData.bestQuizStreak
            : localData.bestQuizStreak,
        createdAt: cloudData.createdAt ?? localData.createdAt,
        updatedAt: DateTime.now(),
      );

      await savePlayerData(merged);
      return merged;
    } catch (e) {
      debugPrint('Error syncing with cloud: $e');
      return localData;
    }
  }
}

