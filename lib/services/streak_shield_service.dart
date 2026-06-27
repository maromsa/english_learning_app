// lib/services/streak_shield_service.dart
//
// Streak Shield — a one-use consumable purchased from the shop.
//
// Logic:
//   - The player buys "streak_shield" from the shop (coins → purchase).
//   - When `DailyRewardService` detects a missed day, it asks this service
//     `consumeShield()`. If a shield is active it burns it and returns true,
//     preserving the existing streak count. If false, the streak resets.
//   - A player can hold at most 1 shield at a time.
//   - The shield is stored in SharedPreferences per-user so it persists
//     across app restarts.

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

class StreakShieldService with ChangeNotifier {
  StreakShieldService({SharedPreferences? prefs})
      : _prefsFuture =
            prefs != null ? Future.value(prefs) : SharedPreferences.getInstance();

  final Future<SharedPreferences> _prefsFuture;
  String? _userId;
  bool _hasShield = false;
  bool _initialized = false;

  // --------------------------------------------------------------------------
  // Identity
  // --------------------------------------------------------------------------

  void setUserId(String? userId) {
    if (_userId == userId) return;
    _userId = userId;
    _initialized = false;
    _hasShield = false;
  }

  String get _shieldKey =>
      _userId == null ? 'streak_shield_active' : 'user_${_userId}_streak_shield';

  // --------------------------------------------------------------------------
  // State
  // --------------------------------------------------------------------------

  bool get hasShield => _hasShield;

  Future<void> initialize() async {
    if (_initialized) return;
    final prefs = await _prefsFuture;
    _hasShield = prefs.getBool(_shieldKey) ?? false;
    _initialized = true;
    notifyListeners();
  }

  /// Grant a shield (called by ShopProvider after purchasing `streak_shield`).
  Future<void> grantShield() async {
    if (_hasShield) return; // already have one
    _hasShield = true;
    await _save();
    notifyListeners();
  }

  /// Attempt to use the shield. Returns `true` if the shield was consumed,
  /// `false` if no shield was available.
  ///
  /// Call this when a streak break is about to occur.
  Future<bool> consumeShield() async {
    await initialize();
    if (!_hasShield) return false;
    _hasShield = false;
    await _save();
    notifyListeners();
    return true;
  }

  Future<void> _save() async {
    final prefs = await _prefsFuture;
    if (_hasShield) {
      await prefs.setBool(_shieldKey, true);
    } else {
      await prefs.remove(_shieldKey);
    }
  }
}
