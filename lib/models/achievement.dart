// lib/models/achievement.dart
import 'package:flutter/material.dart';

class Achievement {
  final String id;
  final String title;
  final String description;
  final IconData icon;
  bool isUnlocked;
  /// Target value for progress-style achievements (e.g. 500 coins, 10 map items).
  final int? requirementValue;

  Achievement({
    required this.id,
    required this.title,
    required this.description,
    required this.icon,
    this.isUnlocked = false,
    this.requirementValue,
  });

  /// Backward-compatible alias for [title].
  String get name => title;
}
