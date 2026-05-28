import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/level_data.dart';
import '../models/parent_dashboard_stats.dart';
import 'daily_reward_service.dart';
import 'level_progress_service.dart';
import 'level_repository.dart';
import 'local_user_data_service.dart';

/// Reads on-device progress for the active child profile.
class ParentProgressService {
  ParentProgressService({
    LevelRepository? levelRepository,
    LevelProgressService? levelProgressService,
    LocalUserDataService? localUserDataService,
    DailyRewardService? dailyRewardService,
    SharedPreferences? prefs,
  })  : _levelRepository = levelRepository ?? LevelRepository(),
        _levelProgressService =
            levelProgressService ?? LevelProgressService(),
        _localUserDataService =
            localUserDataService ?? LocalUserDataService(),
        _dailyRewardService = dailyRewardService ?? DailyRewardService(),
        _prefsFuture =
            prefs != null ? Future.value(prefs) : SharedPreferences.getInstance();

  final LevelRepository _levelRepository;
  final LevelProgressService _levelProgressService;
  final LocalUserDataService _localUserDataService;
  final DailyRewardService _dailyRewardService;
  final Future<SharedPreferences> _prefsFuture;

  static const List<String> _achievementIds = <String>[
    'first_correct',
    'streak_5',
    'coin_collector',
    'map_builder',
    'level_1_complete',
    'add_word',
  ];

  Future<ParentDashboardStats> loadStats({
    required String userId,
    required String childName,
    required bool isLocalUser,
    DateTime? lastPlayedAt,
  }) async {
    final levels = await _levelRepository.loadLevels();
    final prefs = await _prefsFuture;

    final totalStars = await _totalStars(userId, levels, prefs);
    final wordsPracticed = await _countPracticedWords(
      userId: userId,
      levels: levels,
      isLocalUser: isLocalUser,
    );
    final levelsCompleted = await _countCompletedLevels(
      userId: userId,
      levels: levels,
      isLocalUser: isLocalUser,
    );
    final totalWordsInCatalog =
        levels.fold<int>(0, (sum, level) => sum + level.words.length);
    final coins = await _coins(userId, isLocalUser, prefs);
    final achievementsUnlocked =
        _countUnlockedAchievements(prefs, userId);
    final dailyMissions = _dailyMissionCounts(prefs, userId);
    final wordsMastered = _countMasteredWords(prefs, userId);
    _dailyRewardService.setUserId(userId);
    final dailyStreak = await _dailyRewardService.getCurrentStreak();

    return ParentDashboardStats(
      childName: childName,
      totalStars: totalStars,
      dailyStreak: dailyStreak,
      wordsPracticed: wordsPracticed,
      totalWordsInCatalog: totalWordsInCatalog,
      levelsCompleted: levelsCompleted,
      totalLevels: levels.length,
      coins: coins,
      achievementsUnlocked: achievementsUnlocked,
      achievementsTotal: _achievementIds.length,
      dailyMissionsCompleted: dailyMissions.$1,
      dailyMissionsTotal: dailyMissions.$2,
      wordsMastered: wordsMastered,
      lastPlayedAt: lastPlayedAt,
    );
  }

  Future<int> _totalStars(
    String userId,
    List<LevelData> levels,
    SharedPreferences prefs,
  ) async {
    final fromUserKeys = await _localUserDataService.getAllLevelStars(userId);
    var total = fromUserKeys.values.fold<int>(0, (sum, stars) => sum + stars);

    for (final level in levels) {
      if (fromUserKeys.containsKey(level.id)) {
        continue;
      }
      final legacy = prefs.getInt('level_${level.id}_stars') ?? 0;
      total += legacy;
    }

    return total;
  }

  Future<int> _countPracticedWords({
    required String userId,
    required List<LevelData> levels,
    required bool isLocalUser,
  }) async {
    final practiced = <String>{};
    for (final level in levels) {
      final completed = await _levelProgressService.getCompletedWords(
        userId,
        level.id,
        isLocalUser: isLocalUser,
      );
      practiced.addAll(completed);
    }
    return practiced.length;
  }

  Future<int> _countCompletedLevels({
    required String userId,
    required List<LevelData> levels,
    required bool isLocalUser,
  }) async {
    var completed = 0;
    for (final level in levels) {
      if (level.words.isEmpty) {
        continue;
      }
      final done = await _levelProgressService.isLevelCompleted(
        userId,
        level.id,
        level.words.length,
        isLocalUser: isLocalUser,
      );
      if (done) {
        completed++;
      }
    }
    return completed;
  }

  Future<int> _coins(
    String userId,
    bool isLocalUser,
    SharedPreferences prefs,
  ) async {
    if (isLocalUser) {
      return _localUserDataService.getCoins(userId);
    }
    return prefs.getInt('user_${userId}_coins') ??
        prefs.getInt('totalCoins') ??
        0;
  }

  int _countUnlockedAchievements(SharedPreferences prefs, String userId) {
    var count = 0;
    for (final id in _achievementIds) {
      if (prefs.getBool('user_${userId}_achievement_$id') ??
          prefs.getBool('achievement_$id') ??
          false) {
        count++;
      }
    }
    return count;
  }

  (int, int) _dailyMissionCounts(SharedPreferences prefs, String userId) {
    final stored = prefs.getStringList('user_${userId}_daily_missions_payload') ??
        prefs.getStringList('daily_missions_payload');
    if (stored == null || stored.isEmpty) {
      return (0, 0);
    }

    var completed = 0;
    for (final json in stored) {
      try {
        final decoded = jsonDecode(json) as Map<String, dynamic>;
        final progress = decoded['progress'] as int? ?? 0;
        final target = decoded['target'] as int? ?? 0;
        if (target > 0 && progress >= target) {
          completed++;
        }
      } catch (e) {
        debugPrint('ParentProgressService: skip mission payload: $e');
      }
    }
    return (completed, stored.length);
  }

  int _countMasteredWords(SharedPreferences prefs, String userId) {
    final sanitizedUser =
        userId.replaceAll(RegExp(r'[^a-zA-Z0-9_\-]'), '_');
    final prefix = 'word_mastery.v1.$sanitizedUser.';
    var count = 0;

    for (final key in prefs.getKeys()) {
      if (!key.startsWith(prefix)) {
        continue;
      }
      final raw = prefs.getString(key);
      if (raw == null || raw.isEmpty) {
        continue;
      }
      try {
        final decoded = jsonDecode(raw);
        if (decoded is Map<String, dynamic>) {
          final mastery = decoded['masteryLevel'];
          if (mastery is num && mastery >= 1.0) {
            count++;
          }
        }
      } catch (_) {
        // Ignore malformed entries.
      }
    }
    return count;
  }
}
