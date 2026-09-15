import 'package:flutter/foundation.dart';

import '../models/daily_streak.dart';
import '../services/daily_streak_service.dart';

/// Reactive owner of the practice daily streak (🔥).
///
/// Persistence is per-child and local-only (see [DailyStreakService]).
/// [now] is injectable so tests can pin calendar days without wall-clock
/// flakes. Date math compares **calendar days**, not 24h durations, so a
/// DST transition cannot unfairly reset a child's streak.
class DailyStreakProvider with ChangeNotifier {
  DailyStreakProvider({
    DailyStreak? initial,
    DailyStreakService? service,
    DateTime Function()? now,
  })  : _streak = initial ?? DailyStreak.empty(),
        _service = service ?? DailyStreakService(),
        _now = now ?? DateTime.now;

  final DailyStreakService _service;
  final DateTime Function() _now;
  DailyStreak _streak;
  String? _userId;
  bool _disposed = false;

  DailyStreak get streak => _streak;
  int get currentStreak => _streak.currentStreak;
  DateTime? get lastPracticeDate => _streak.lastPracticeDate;

  void _notify() {
    if (!_disposed) notifyListeners();
  }

  /// Points persistence at [userId]'s namespace (guest when null).
  void setUserId(String? userId) {
    _userId = userId;
  }

  /// Loads the persisted streak for the current profile. Best-effort: a
  /// read failure leaves the previous (or empty) state in place.
  Future<void> load() async {
    try {
      _streak = await _service.load(_userId);
      _notify();
    } catch (e) {
      debugPrint('Error loading daily streak: $e');
    }
  }

  /// Records that the child practiced today.
  ///
  /// - Already practiced today → no-op.
  /// - Last practice was yesterday → increment the streak.
  /// - Last practice is older than yesterday, or never → reset to 1.
  ///
  /// Returns `true` when today's practice was newly recorded, `false` when
  /// the child had already practiced today (or the provider is disposed).
  Future<bool> recordPractice() async {
    final today = _dateOnly(_now());
    final last = _streak.lastPracticeDate == null
        ? null
        : _dateOnly(_streak.lastPracticeDate!);

    if (last == today) return false;

    final yesterday = DateTime(today.year, today.month, today.day - 1);
    final nextCount = last == yesterday ? _streak.currentStreak + 1 : 1;

    _streak = DailyStreak(
      currentStreak: nextCount,
      lastPracticeDate: today,
    );
    await _service.save(_userId, _streak);
    _notify();
    return true;
  }

  static DateTime _dateOnly(DateTime dt) => DateTime(dt.year, dt.month, dt.day);

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }
}
