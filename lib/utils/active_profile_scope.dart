import 'package:english_learning_app/providers/shop_provider.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/child_profile.dart';
import '../providers/coin_provider.dart';
import '../providers/daily_mission_provider.dart';
import '../providers/user_session_provider.dart';
import '../services/achievement_service.dart';
import '../services/child_profile_service.dart';
import '../services/child_profile_sync_service.dart';
import '../services/daily_reward_service.dart';
import '../services/parent_progress_service.dart';
import '../services/streak_shield_service.dart';

/// Reconfigures app providers when the active child profile changes.
class ActiveProfileScope {
  ActiveProfileScope._();

  static Future<void> apply(
    BuildContext context,
    ChildProfile profile, {
    String? parentUid,
    ChildProfileSyncService? syncService,
    ChildProfileService? profileService,
    ParentProgressService? progressService,
    DailyRewardService? dailyRewardService,
  }) async {
    final coinProvider = context.read<CoinProvider>();
    final shopProvider = context.read<ShopProvider>();
    final achievementService = context.read<AchievementService>();
    final dailyMissionProvider = context.read<DailyMissionProvider>();
    final sessionProvider = context.read<UserSessionProvider>();
    final shieldService = context.read<StreakShieldService>();

    coinProvider.setUserId(profile.id, isLocalUser: true);
    shopProvider.setUserId(profile.id);
    achievementService.setUserId(profile.id);
    dailyMissionProvider.setUserId(profile.id);
    shieldService.setUserId(profile.id);

    // Wire all-missions-complete → achievement unlock.
    dailyMissionProvider.onAllCompleted = (int streakDays) {
      achievementService.onAllMissionsCompleted(
        missionStreakDays: streakDays,
      );
    };

    await Future.wait([
      coinProvider.loadCoins(),
      shopProvider.loadPurchasedItems(),
      achievementService.loadAchievements(),
      dailyMissionProvider.initialize(),
      shieldService.initialize(),
    ]);

    await sessionProvider.switchToChildProfile(
      profileId: profile.id,
      displayName: profile.displayName,
      photoUrl: profile.avatarUrl,
    );

    final service = profileService ?? ChildProfileService();
    final rewardService = dailyRewardService ?? DailyRewardService();
    rewardService.setUserId(profile.id);
    final progress = progressService ??
        ParentProgressService(dailyRewardService: rewardService);

    final stats = await progress.loadStats(
      userId: profile.id,
      childName: profile.displayName,
      isLocalUser: true,
      lastPlayedAt: profile.lastPlayedAt,
    );

    final achievements = _achievementMap(achievementService);

    await service.updateProgressSnapshot(
      profileId: profile.id,
      totalStars: stats.totalStars,
      dailyStreak: stats.dailyStreak,
      completedWordsCount: stats.wordsPracticed,
      achievements: achievements,
      coins: stats.coins,
    );

    if (parentUid != null) {
      final sync =
          syncService ?? ChildProfileSyncService(profileService: service);
      final updated = await service.getProfileById(profile.id);
      if (updated != null) {
        await sync.syncProfileToCloud(parentUid, updated);
      }
    }
  }

  static Map<String, bool> _achievementMap(
    AchievementService achievementService,
  ) {
    return {
      for (final achievement in achievementService.achievements)
        achievement.id: achievement.isUnlocked,
    };
  }
}
