import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'streak_shield_service.dart';

class DailyRewardResult {
  const DailyRewardResult({
    required this.claimed,
    required this.reward,
    required this.streak,
    this.shieldUsed = false,
  });

  final bool claimed;
  final int reward;
  final int streak;
  /// True when a Streak Shield was consumed to preserve the streak.
  final bool shieldUsed;
}

class DailyRewardService {
  DailyRewardService({
    DateTime Function()? now,
    math.Random? random,
    StreakShieldService? shieldService,
  })  : _now = now ?? DateTime.now,
        _random = random ?? math.Random(),
        _shield = shieldService;

  static const String _legacyLastClaimKey = 'daily_reward_last_claim';
  static const String _legacyStreakKey = 'daily_reward_streak';

  String? _userId;

  void setUserId(String? userId) {
    _userId = userId;
  }

  String get _lastClaimKey => _userId == null
      ? _legacyLastClaimKey
      : 'user_${_userId}_daily_reward_last_claim';

  String get _streakKey => _userId == null
      ? _legacyStreakKey
      : 'user_${_userId}_daily_reward_streak';

  static const int minReward = 10;
  static const int maxReward = 20;
  static const int _streakBonus = 3;
  static const int _maxBonusMultiplier = 5;

  final DateTime Function() _now;
  final math.Random _random;
  final StreakShieldService? _shield;

  /// Current daily-login streak (device-local; see [claimReward]).
  Future<int> getCurrentStreak() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getInt(_streakKey) ?? 0;
  }

  Future<DailyRewardResult> claimReward() async {
    final prefs = await SharedPreferences.getInstance();
    final today = DateUtils.dateOnly(_now());
    final lastClaimMillis = prefs.getInt(_lastClaimKey);

    int streak = 0;
    bool shieldUsed = false;

    if (lastClaimMillis != null) {
      final lastClaimDate = DateUtils.dateOnly(
        DateTime.fromMillisecondsSinceEpoch(lastClaimMillis),
      );

      if (lastClaimDate == today) {
        streak = prefs.getInt(_streakKey) ?? 1;
        return DailyRewardResult(
            claimed: false, reward: 0, streak: streak, shieldUsed: false);
      }

      // Compare calendar days, not a 24h duration: `add(Duration(days: 1))`
      // breaks on DST-transition days (23/25-hour days), which would unfairly
      // reset the child's streak twice a year.
      final yesterday = DateTime(today.year, today.month, today.day - 1);
      if (lastClaimDate == yesterday) {
        // Consecutive day — streak continues normally.
        streak = (prefs.getInt(_streakKey) ?? 0) + 1;
      } else {
        // Missed at least one day. Check if the player has a shield.
        final savedStreak = prefs.getInt(_streakKey) ?? 0;
        if (savedStreak > 0 && _shield != null) {
          shieldUsed = await _shield!.consumeShield();
        }
        if (shieldUsed) {
          // Shield absorbed the break — continue the streak.
          streak = savedStreak + 1;
        }
        // else streak stays 0, will be set to 1 below.
      }
    }

    if (streak == 0) {
      streak = 1;
    }

    final baseReward = minReward + _random.nextInt(maxReward - minReward + 1);
    final bonusMultiplier = math.min(streak - 1, _maxBonusMultiplier);
    final reward = baseReward + bonusMultiplier * _streakBonus;

    await prefs.setInt(_lastClaimKey, today.millisecondsSinceEpoch);
    await prefs.setInt(_streakKey, streak);

    return DailyRewardResult(
        claimed: true, reward: reward, streak: streak, shieldUsed: shieldUsed);
  }
}
