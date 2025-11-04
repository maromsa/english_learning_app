import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class DailyRewardResult {
  const DailyRewardResult({
    required this.claimed,
    required this.reward,
    required this.streak,
  });

  final bool claimed;
  final int reward;
  final int streak;
}

class DailyRewardService {
  DailyRewardService({DateTime Function()? now, math.Random? random})
      : _now = now ?? DateTime.now,
        _random = random ?? math.Random();

  static const String _lastClaimKey = 'daily_reward_last_claim';
  static const String _streakKey = 'daily_reward_streak';

  static const int minReward = 10;
  static const int maxReward = 20;
  static const int _streakBonus = 3;
  static const int _maxBonusMultiplier = 5;

  final DateTime Function() _now;
  final math.Random _random;

  Future<DailyRewardResult> claimReward() async {
    final prefs = await SharedPreferences.getInstance();
    final today = DateUtils.dateOnly(_now());
    final lastClaimMillis = prefs.getInt(_lastClaimKey);

    int streak = 0;
    if (lastClaimMillis != null) {
      final lastClaimDate = DateUtils.dateOnly(
        DateTime.fromMillisecondsSinceEpoch(lastClaimMillis),
      );

      if (lastClaimDate == today) {
        streak = prefs.getInt(_streakKey) ?? 1;
        return DailyRewardResult(claimed: false, reward: 0, streak: streak);
      }

      if (lastClaimDate.add(const Duration(days: 1)) == today) {
        streak = (prefs.getInt(_streakKey) ?? 0) + 1;
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

    return DailyRewardResult(claimed: true, reward: reward, streak: streak);
  }
}
