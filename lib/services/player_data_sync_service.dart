import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/player_data.dart';
import '../providers/character_provider.dart';
import '../providers/coin_provider.dart';
import '../providers/shop_provider.dart';
import '../services/achievement_service.dart';
import '../services/user_data_service.dart';

/// Service for syncing player data between local storage and cloud
class PlayerDataSyncService {
  PlayerDataSyncService({
    UserDataService? userDataService,
  }) : _userDataService = userDataService ?? UserDataService();

  final UserDataService _userDataService;

  /// Sync all player data from cloud to local providers
  Future<void> syncFromCloud(
    String userId, {
    required CoinProvider coinProvider,
    required ShopProvider shopProvider,
    required AchievementService achievementService,
    CharacterProvider? characterProvider,
  }) async {
    try {
      debugPrint('Starting cloud sync for user: $userId');

      // Load player data from cloud
      final cloudData = await _userDataService.loadPlayerData(userId);

      if (cloudData == null) {
        debugPrint('No cloud data found, creating initial player data');
        // Create initial player data from local state
        await _createInitialPlayerData(userId, coinProvider, shopProvider, achievementService);
        return;
      }

      // Sync coins
      if (cloudData.coins > 0) {
        await coinProvider.setCoins(cloudData.coins);
        debugPrint('Synced coins from cloud: ${cloudData.coins}');
      }

      // Sync purchased items
      if (cloudData.purchasedItems.isNotEmpty) {
        final prefs = await SharedPreferences.getInstance();
        await prefs.setStringList('purchased_items', cloudData.purchasedItems);
        await shopProvider.loadPurchasedItems();
        debugPrint('Synced purchased items from cloud: ${cloudData.purchasedItems.length}');
      }

      // Sync achievements
      if (cloudData.achievements.isNotEmpty) {
        final prefs = await SharedPreferences.getInstance();
        for (final entry in cloudData.achievements.entries) {
          if (entry.value) {
            await prefs.setBool('achievement_${entry.key}', true);
          }
        }
        await achievementService.loadAchievements();
        debugPrint('Synced achievements from cloud: ${cloudData.achievements.length}');
      }

      // Sync character
      if (cloudData.character != null && characterProvider != null) {
        await characterProvider.setCharacter(cloudData.character!);
        debugPrint('Synced character from cloud: ${cloudData.character!.characterName}');
      }

      debugPrint('Cloud sync completed successfully');
    } catch (e, stackTrace) {
      debugPrint('Error syncing from cloud: $e');
      debugPrint('Stack trace: $stackTrace');
    }
  }

  /// Create initial player data in cloud from local state
  Future<void> _createInitialPlayerData(
    String userId,
    CoinProvider coinProvider,
    ShopProvider shopProvider,
    AchievementService achievementService,
  ) async {
    try {
      final prefs = await SharedPreferences.getInstance();

      // Get local data
      final coins = prefs.getInt('totalCoins') ?? 0;
      final purchasedItems = prefs.getStringList('purchased_items') ?? [];
      final achievements = <String, bool>{};

      // Load achievements
      for (final achievement in achievementService.achievements) {
        final isUnlocked = prefs.getBool('achievement_${achievement.id}') ?? false;
        if (isUnlocked) {
          achievements[achievement.id] = true;
        }
      }

      // Create player data
      final playerData = PlayerData(
        userId: userId,
        coins: coins,
        purchasedItems: purchasedItems,
        achievements: achievements,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );

      // Save to cloud
      await _userDataService.savePlayerData(playerData);
      debugPrint('Created initial player data in cloud');
    } catch (e) {
      debugPrint('Error creating initial player data: $e');
    }
  }

  /// Sync local data to cloud (for when user is already authenticated)
  Future<void> syncToCloud(
    String userId, {
    required CoinProvider coinProvider,
    required ShopProvider shopProvider,
    required AchievementService achievementService,
  }) async {
    try {
      debugPrint('Syncing local data to cloud for user: $userId');

      final prefs = await SharedPreferences.getInstance();

      // Get local data
      final coins = prefs.getInt('totalCoins') ?? 0;
      final purchasedItems = prefs.getStringList('purchased_items') ?? [];
      final achievements = <String, bool>{};

      // Load achievements
      for (final achievement in achievementService.achievements) {
        final isUnlocked = prefs.getBool('achievement_${achievement.id}') ?? false;
        if (isUnlocked) {
          achievements[achievement.id] = true;
        }
      }

      // Load existing cloud data or create new
      final cloudData = await _userDataService.loadPlayerData(userId);
      final playerData = cloudData ?? PlayerData(
        userId: userId,
        coins: coins,
        purchasedItems: purchasedItems,
        achievements: achievements,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );

      // Merge with local data (local wins for now, but we can improve this)
      final mergedData = playerData.copyWith(
        coins: coins > playerData.coins ? coins : playerData.coins,
        purchasedItems: [
          ...playerData.purchasedItems,
          ...purchasedItems,
        ].toSet().toList(),
        achievements: {
          ...playerData.achievements,
          ...achievements,
        },
        updatedAt: DateTime.now(),
      );

      await _userDataService.savePlayerData(mergedData);
      debugPrint('Synced local data to cloud successfully');
    } catch (e) {
      debugPrint('Error syncing to cloud: $e');
    }
  }
}

