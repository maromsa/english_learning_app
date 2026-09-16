import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/daily_streak.dart';

/// Local persistence for the practice daily streak.
///
/// State is **per-child**: the key is namespaced by profile id
/// (`user_<id>_daily_streak`), matching `EquippedAvatarService` /
/// `AvatarInventoryService`. A signed-out guest falls back to a stable
/// `guest` prefix so their streak survives until they create a profile.
///
/// Firebase-agnostic by design (CLAUDE.md §2.1) — an optional
/// [SharedPreferences] can be injected in tests. Cloud mirroring lives in
/// [ChildProfileSyncService]; this service stays the local source of truth.
class DailyStreakService {
  DailyStreakService({SharedPreferences? prefs}) : _injectedPrefs = prefs;

  final SharedPreferences? _injectedPrefs;
  SharedPreferences? _prefs;

  Future<SharedPreferences> get _sharedPrefs async =>
      _injectedPrefs ?? (_prefs ??= await SharedPreferences.getInstance());

  static const String _guestPrefix = 'guest';

  String _key(String? userId) =>
      'user_${(userId == null || userId.isEmpty) ? _guestPrefix : userId}'
      '_daily_streak';

  /// Loads the persisted streak for [userId], or an empty one if nothing
  /// has been saved yet or the stored value can't be parsed.
  Future<DailyStreak> load(String? userId) async {
    try {
      final prefs = await _sharedPrefs;
      final raw = prefs.getString(_key(userId));
      if (raw == null || raw.isEmpty) return DailyStreak.empty();
      final decoded = jsonDecode(raw);
      if (decoded is! Map<String, dynamic>) return DailyStreak.empty();
      return DailyStreak.fromJson(decoded);
    } catch (e) {
      debugPrint('Error loading daily streak: $e');
      return DailyStreak.empty();
    }
  }

  /// Persists [streak] for [userId]. Best-effort: a write failure is
  /// logged and swallowed rather than thrown, matching the rest of the
  /// local persistence layer.
  Future<void> save(String? userId, DailyStreak streak) async {
    try {
      final prefs = await _sharedPrefs;
      await prefs.setString(_key(userId), jsonEncode(streak.toJson()));
    } catch (e) {
      debugPrint('Error saving daily streak: $e');
    }
  }

  /// Applies a streak pulled from the cloud onto the device store for
  /// [userId], merging with whatever is already there so a locally-recorded
  /// practice day can never be dropped by a stale cloud copy.
  Future<void> applyMergedSnapshot(String? userId, DailyStreak cloud) async {
    final local = await load(userId);
    await save(userId, DailyStreak.merge(local, cloud));
  }
}
