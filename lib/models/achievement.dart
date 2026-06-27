// lib/models/achievement.dart
import 'package:flutter/material.dart';

/// Broad grouping for the trophy room display.
enum AchievementCategory {
  firstSteps,   // beginners
  learning,     // words/levels
  streak,       // daily/quiz streaks
  pronunciation,// speaking & stars
  explorer,     // camera / scene / story
  collector,    // coins / shop
  dedication,   // long-term use
}

class Achievement {
  final String id;
  final String title;
  final String description;
  final IconData icon;
  bool isUnlocked;

  /// Target value for progress-style achievements (e.g. 500 coins, 10 map items).
  final int? requirementValue;

  /// Category for grouping in the trophy room.
  final AchievementCategory category;

  /// Coin reward granted on unlock (0 = no reward).
  final int coinReward;

  Achievement({
    required this.id,
    required this.title,
    required this.description,
    required this.icon,
    this.isUnlocked = false,
    this.requirementValue,
    this.category = AchievementCategory.firstSteps,
    this.coinReward = 0,
  });

  /// Backward-compatible alias for [title].
  String get name => title;
}
