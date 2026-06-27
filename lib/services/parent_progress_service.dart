// lib/services/parent_progress_service.dart
//
// Reads on-device progress for the active child profile.
// Extended to return weeklyActivity, weakWords, and session minutes.

import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/level_data.dart';
import '../models/parent_dashboard_stats.dart';
import 'app_database.dart';
import 'daily_reward_service.dart';
import 'level_progress_service.dart';
import 'level_repository.dart';
import 'local_user_data_service.dart';

class ParentProgressService {
  ParentProgressService({
    LevelRepository? levelRepository,
    LevelProgressService? levelProgressService,
    LocalUserDataService? localUserDataService,
    DailyRewardService? dailyRewardService,
    SharedPreferences? prefs,
  })  : _levelRepository = levelRepository ?? LevelRepository(),
        _levelProgressService = levelProgressService ?? LevelProgressService(),
        _localUserDataService = localUserDataService ?? LocalUserDataService(),
        _dailyRewardService = dailyRewardService ?? DailyRewardService(),
        _prefsFuture = prefs != null
            ? Future.value(prefs)
            : SharedPreferences.getInstance();

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

  // Storage key prefix for session activity log.
  static const String _activityPrefix = 'parent_activity.v1';

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
    final achievementsUnlocked = _countUnlockedAchievements(prefs, userId);
    final dailyMissions = _dailyMissionCounts(prefs, userId);
    final wordsMastered = _countMasteredWords(prefs, userId);
    _dailyRewardService.setUserId(userId);
    final dailyStreak = await _dailyRewardService.getCurrentStreak();

    // ── New enriched data ────────────────────────────────────────────────────
    final weeklyActivity = _buildWeeklyActivity(prefs, userId);
    final weakWords = await _findWeakWords(prefs, userId, levels);
    final totalMinutes = _totalSessionMinutes(prefs, userId);
    final weeklyNewWords = weeklyActivity.fold(0, (s, d) => s + d.words);

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
      weeklyActivity: weeklyActivity,
      weakWords: weakWords,
      totalSessionMinutes: totalMinutes,
      weeklyNewWords: weeklyNewWords,
    );
  }

  // ---------------------------------------------------------------------------
  // Activity log — write side (called from game screens)
  // ---------------------------------------------------------------------------

  /// Records that the learner answered [wordCount] words in a session of
  /// [durationMinutes]. Should be called when a Lightning / quiz session ends.
  static Future<void> recordSession({
    required String userId,
    required int wordCount,
    required int durationMinutes,
    SharedPreferences? prefs,
    AppDatabase? db,
  }) async {
    final today = _dayKey(DateTime.now());
    // Write to SQLite (primary).
    try {
      await (db ?? AppDatabase.instance).recordActivity(
        userId: userId,
        day: today,
        wordCount: wordCount,
        minutes: durationMinutes,
      );
    } catch (e) {
      debugPrint('ParentProgressService.recordSession (db): $e');
    }
    // Keep SharedPreferences in sync for backwards compat / quick reads.
    try {
      final p = prefs ?? await SharedPreferences.getInstance();
      final key = '${_activityPrefix}_${_sanitize(userId)}';
      final existing = p.getString(key);
      final log = existing != null
          ? (jsonDecode(existing) as List<dynamic>)
              .whereType<Map<String, dynamic>>()
              .toList()
          : <Map<String, dynamic>>[];

      final idx = log.indexWhere((e) => e['day'] == today);
      if (idx >= 0) {
        log[idx]['words'] = ((log[idx]['words'] as int? ?? 0) + wordCount);
        log[idx]['minutes'] =
            ((log[idx]['minutes'] as int? ?? 0) + durationMinutes);
      } else {
        log.add({'day': today, 'words': wordCount, 'minutes': durationMinutes});
      }

      final trimmed = log.length > 30 ? log.sublist(log.length - 30) : log;
      await p.setString(key, jsonEncode(trimmed));
    } catch (e) {
      debugPrint('ParentProgressService.recordSession (prefs): $e');
    }
  }

  // ---------------------------------------------------------------------------
  // Private helpers (existing)
  // ---------------------------------------------------------------------------

  Future<int> _totalStars(
    String userId,
    List<LevelData> levels,
    SharedPreferences prefs,
  ) async {
    final fromUserKeys = await _localUserDataService.getAllLevelStars(userId);
    var total = fromUserKeys.values.fold<int>(0, (sum, stars) => sum + stars);

    for (final level in levels) {
      if (fromUserKeys.containsKey(level.id)) continue;
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
      if (level.words.isEmpty) continue;
      final done = await _levelProgressService.isLevelCompleted(
        userId,
        level.id,
        level.words.length,
        isLocalUser: isLocalUser,
      );
      if (done) completed++;
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
    final stored =
        prefs.getStringList('user_${userId}_daily_missions_payload') ??
            prefs.getStringList('daily_missions_payload');
    if (stored == null || stored.isEmpty) return (0, 0);

    var completed = 0;
    for (final json in stored) {
      try {
        final decoded = jsonDecode(json) as Map<String, dynamic>;
        final progress = decoded['progress'] as int? ?? 0;
        final target = decoded['target'] as int? ?? 0;
        if (target > 0 && progress >= target) completed++;
      } catch (e) {
        debugPrint('ParentProgressService: skip mission payload: $e');
      }
    }
    return (completed, stored.length);
  }

  int _countMasteredWords(SharedPreferences prefs, String userId) {
    final sanitizedUser = userId.replaceAll(RegExp(r'[^a-zA-Z0-9_\-]'), '_');
    final prefix = 'word_mastery.v1.$sanitizedUser.';
    var count = 0;
    for (final key in prefs.getKeys()) {
      if (!key.startsWith(prefix)) continue;
      final raw = prefs.getString(key);
      if (raw == null || raw.isEmpty) continue;
      try {
        final decoded = jsonDecode(raw);
        if (decoded is Map<String, dynamic>) {
          final mastery = decoded['masteryLevel'];
          if (mastery is num && mastery >= 1.0) count++;
        }
      } catch (_) {}
    }
    return count;
  }

  // ---------------------------------------------------------------------------
  // New enriched helpers
  // ---------------------------------------------------------------------------

  List<DailyActivity> _buildWeeklyActivity(
      SharedPreferences prefs, String userId) {
    // Prefer SharedPreferences for synchronous access in this context.
    // SQLite reads happen async in recordSession and are the write-primary store.
    final key = '${_activityPrefix}_${_sanitize(userId)}';
    final raw = prefs.getString(key);
    final log = raw != null
        ? (jsonDecode(raw) as List<dynamic>)
            .whereType<Map<String, dynamic>>()
            .toList()
        : <Map<String, dynamic>>[];

    final logMap = <String, Map<String, dynamic>>{
      for (final e in log) (e['day'] as String? ?? ''): e,
    };

    final today = DateTime.now();
    return List.generate(7, (i) {
      final date = today.subtract(Duration(days: 6 - i));
      final dayKey = _dayKey(date);
      final entry = logMap[dayKey];
      return DailyActivity(
        date: date,
        words: (entry?['words'] as int?) ?? 0,
        minutes: (entry?['minutes'] as int?) ?? 0,
      );
    });
  }

  Future<List<WeakWord>> _findWeakWords(
    SharedPreferences prefs,
    String userId,
    List<LevelData> levels,
  ) async {
    final sanitizedUser = userId.replaceAll(RegExp(r'[^a-zA-Z0-9_\-]'), '_');
    // Check both SRS keys (srs.v1) and legacy mastery keys (word_mastery.v1).
    final prefixSrs = 'srs.v1.$sanitizedUser.';
    final prefixLegacy = 'word_mastery.v1.$sanitizedUser.';

    // Build level name map.
    final levelNames = <String, String>{
      for (final l in levels) l.id: l.name,
    };

    final results = <WeakWord>[];

    for (final key in prefs.getKeys()) {
      double? mastery;
      String? levelId;
      String? wordId;

      if (key.startsWith(prefixSrs)) {
        final parts = key.substring(prefixSrs.length).split('.');
        if (parts.length < 2) continue;
        levelId = parts[0];
        wordId = parts.sublist(1).join('.');
        final raw = prefs.getString(key);
        if (raw == null) continue;
        try {
          final json = jsonDecode(raw) as Map<String, dynamic>;
          mastery = (json['masteryLevel'] as num?)?.toDouble();
        } catch (_) {
          continue;
        }
      } else if (key.startsWith(prefixLegacy)) {
        final parts = key.substring(prefixLegacy.length).split('.');
        if (parts.length < 2) continue;
        levelId = parts[0];
        wordId = parts.sublist(1).join('.');
        final raw = prefs.getString(key);
        if (raw == null) continue;
        try {
          final json = jsonDecode(raw) as Map<String, dynamic>;
          mastery = (json['masteryLevel'] as num?)?.toDouble();
        } catch (_) {
          continue;
        }
      }

      if (mastery == null || wordId == null || levelId == null) continue;
      // Only include seen words with non-trivial mastery (has been reviewed).
      if (mastery <= 0.0 || mastery >= 0.8) continue;

      results.add(WeakWord(
        word: wordId.replaceAll('_', ' '),
        masteryLevel: mastery,
        levelName: levelNames[levelId] ?? levelId,
      ));
    }

    results.sort((a, b) => a.masteryLevel.compareTo(b.masteryLevel));
    return results.take(8).toList();
  }

  int _totalSessionMinutes(SharedPreferences prefs, String userId) {
    final key = '${_activityPrefix}_${_sanitize(userId)}';
    final raw = prefs.getString(key);
    if (raw == null) return 0;
    try {
      final log = (jsonDecode(raw) as List<dynamic>)
          .whereType<Map<String, dynamic>>();
      return log.fold(0, (sum, e) => sum + ((e['minutes'] as int?) ?? 0));
    } catch (_) {
      return 0;
    }
  }

  static String _dayKey(DateTime date) =>
      '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';

  static String _sanitize(String value) =>
      value.replaceAll(RegExp(r'[^a-zA-Z0-9_\-]'), '_');
}
