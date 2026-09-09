import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/parent_dashboard_stats.dart';
import '../models/weekly_recap.dart';
import 'local_user_data_service.dart';

/// Builds the [WeeklyRecap] shown on the Parent Dashboard from on-device data
/// only (the daily activity log, the daily "coins earned" log, and SRS cards).
///
/// Firebase-agnostic (CLAUDE.md §2.1). [SharedPreferences] and
/// [LocalUserDataService] can be injected for tests; [loadRecap] takes an
/// optional `now` so the 7-day window can be pinned.
class WeeklyRecapService {
  WeeklyRecapService({
    SharedPreferences? prefs,
    LocalUserDataService? localUserDataService,
  })  : _injectedPrefs = prefs,
        _local = localUserDataService ?? LocalUserDataService();

  final SharedPreferences? _injectedPrefs;
  final LocalUserDataService _local;

  Future<SharedPreferences> get _prefs async =>
      _injectedPrefs ?? await SharedPreferences.getInstance();

  /// Written by `ParentProgressService.recordSession` — same key here so the
  /// recap reads the exact log the game screens populate.
  static const String _activityPrefix = 'parent_activity.v1';

  static const int _windowDays = 7;

  static String _sanitize(String value) =>
      value.replaceAll(RegExp(r'[^a-zA-Z0-9_\-]'), '_');

  Future<WeeklyRecap> loadRecap({
    required String userId,
    DateTime? now,
  }) async {
    final today = _startOfDay(now ?? DateTime.now());
    final prefs = await _prefs;

    final days = _weekDays(prefs, userId, today);
    final coins = await _local.weeklyCoinsEarned(userId, now: today);
    final mastered = _wordsMasteredThisWeek(prefs, userId, today);

    return WeeklyRecap(
      days: days,
      coinsEarned: coins,
      wordsMasteredThisWeek: mastered,
    );
  }

  // ── Activity (words / minutes per day) ─────────────────────────────────────

  List<DailyActivity> _weekDays(
    SharedPreferences prefs,
    String userId,
    DateTime today,
  ) {
    final key = '${_activityPrefix}_${_sanitize(userId)}';
    final byDay = <String, Map<String, dynamic>>{};
    final raw = prefs.getString(key);
    if (raw != null && raw.isNotEmpty) {
      try {
        for (final entry in (jsonDecode(raw) as List<dynamic>)) {
          if (entry is Map<String, dynamic>) {
            final day = entry['day'];
            if (day is String) byDay[day] = entry;
          }
        }
      } catch (e) {
        debugPrint('WeeklyRecapService: bad activity log: $e');
      }
    }

    return List.generate(_windowDays, (i) {
      final date = today.subtract(Duration(days: _windowDays - 1 - i));
      final entry = byDay[LocalUserDataService.dayKey(date)];
      return DailyActivity(
        date: date,
        words: (entry?['words'] as int?) ?? 0,
        minutes: (entry?['minutes'] as int?) ?? 0,
      );
    });
  }

  // ── Words at mastery reviewed this week ────────────────────────────────────

  int _wordsMasteredThisWeek(
    SharedPreferences prefs,
    String userId,
    DateTime today,
  ) {
    final prefix = 'srs.v1.${_sanitize(userId)}.';
    final cutoff = today.subtract(const Duration(days: _windowDays - 1));
    var count = 0;

    for (final key in prefs.getKeys()) {
      if (!key.startsWith(prefix)) continue;
      final raw = prefs.getString(key);
      if (raw == null || raw.isEmpty) continue;
      try {
        final json = jsonDecode(raw) as Map<String, dynamic>;
        final mastery = (json['masteryLevel'] as num?)?.toDouble() ?? 0.0;
        if (mastery < 1.0) continue;
        final reviewed = DateTime.tryParse(
          json['lastReviewDate'] as String? ?? '',
        );
        if (reviewed != null && !_startOfDay(reviewed).isBefore(cutoff)) {
          count++;
        }
      } catch (_) {
        // Skip an unparseable card — never let it break the recap.
      }
    }
    return count;
  }

  static DateTime _startOfDay(DateTime d) => DateTime(d.year, d.month, d.day);
}
