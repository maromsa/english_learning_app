import 'package:flutter/foundation.dart';

import '../models/daily_streak.dart';
import '../services/child_profile_sync_service.dart';
import '../services/daily_streak_service.dart';
import '../services/notification_service.dart';
import 'coin_provider.dart';

/// Bonus coins granted the first time a practice streak reaches [day].
class StreakMilestoneReward {
  const StreakMilestoneReward({required this.day, required this.coins});

  final int day;
  final int coins;
}

/// Reactive owner of the practice daily streak (🔥).
///
/// Persistence is per-child and local-first (see [DailyStreakService]).
/// When the active profile belongs to a signed-in parent account (see
/// [setParentUid]), a successful [recordPractice] also pushes the new
/// streak to [ChildProfileSyncService]. Guests and local (non-cloud)
/// profiles have no [parentUid], so they stay local-only.
///
/// [now] is injectable so tests can pin calendar days without wall-clock
/// flakes. Date math compares **calendar days**, not 24h durations, so a
/// DST transition cannot unfairly reset a child's streak.
class DailyStreakProvider with ChangeNotifier {
  DailyStreakProvider({
    DailyStreak? initial,
    DailyStreakService? service,
    ChildProfileSyncService? syncService,
    DateTime Function()? now,
    CoinProvider? coinProvider,
    NotificationService? notificationService,
  })  : _streak = initial ?? DailyStreak.empty(),
        _service = service ?? DailyStreakService(),
        _injectedSyncService = syncService,
        _now = now ?? DateTime.now,
        _coinProvider = coinProvider,
        _notifications = notificationService;

  /// Day-count → bonus coins. Day 3 / 7 / 14 of a consecutive streak.
  static const Map<int, int> milestoneRewards = {
    3: 20,
    7: 50,
    14: 100,
  };

  final DailyStreakService _service;
  final ChildProfileSyncService? _injectedSyncService;
  ChildProfileSyncService? _lazySyncService;
  final DateTime Function() _now;
  final CoinProvider? _coinProvider;
  final NotificationService? _notifications;
  DailyStreak _streak;
  String? _userId;
  String? _parentUid;
  bool _disposed = false;
  StreakMilestoneReward? _pendingMilestone;

  /// Real default is created lazily so widget tests that never set a
  /// [parentUid] don't need a Firebase app.
  ChildProfileSyncService get _syncService =>
      _injectedSyncService ?? (_lazySyncService ??= ChildProfileSyncService());

  DailyStreak get streak => _streak;
  int get currentStreak => _streak.currentStreak;
  DateTime? get lastPracticeDate => _streak.lastPracticeDate;
  List<int> get claimedMilestones => _streak.claimedMilestones;

  /// Most recent milestone unlocked by [recordPractice], if any.
  /// Consumed by the UI via [consumePendingMilestone].
  StreakMilestoneReward? get pendingMilestone => _pendingMilestone;

  void _notify() {
    if (!_disposed) notifyListeners();
  }

  /// Points persistence at [userId]'s namespace (guest when null).
  void setUserId(String? userId) {
    _userId = userId;
  }

  /// Points cloud sync at the signed-in parent's Firestore account, or
  /// `null` for guests / local (non-cloud) profiles — which then stay
  /// local-only. Should be set alongside [setUserId] whenever the active
  /// profile changes.
  void setParentUid(String? parentUid) {
    _parentUid = parentUid;
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
  /// When the new streak count hits a [milestoneRewards] day that has not
  /// yet been claimed on this streak, bonus coins are granted through
  /// [CoinProvider] and [pendingMilestone] is set for the celebratory UI.
  ///
  /// Returns `true` when today's practice was newly recorded, `false` when
  /// the child had already practiced today (or the provider is disposed).
  Future<bool> recordPractice() async {
    if (_disposed) return false;

    final today = _dateOnly(_now());
    final last = _streak.lastPracticeDate == null
        ? null
        : _dateOnly(_streak.lastPracticeDate!);

    if (last == today) return false;

    final yesterday = DateTime(today.year, today.month, today.day - 1);
    final continued = last == yesterday;
    final nextCount = continued ? _streak.currentStreak + 1 : 1;
    final claimed =
        continued ? List<int>.from(_streak.claimedMilestones) : <int>[];

    StreakMilestoneReward? unlocked;
    final rewardCoins = milestoneRewards[nextCount];
    if (rewardCoins != null && !claimed.contains(nextCount)) {
      claimed.add(nextCount);
      unlocked = StreakMilestoneReward(day: nextCount, coins: rewardCoins);
      final coins = _coinProvider;
      if (coins != null) {
        await coins.addCoins(rewardCoins);
      }
    }

    _streak = DailyStreak(
      currentStreak: nextCount,
      lastPracticeDate: today,
      claimedMilestones: claimed,
    );
    _pendingMilestone = unlocked;
    await _service.save(_userId, _streak);
    _notify();
    await _pushToCloud();
    await _rescheduleReminderForNextDay();
    return true;
  }

  /// Drop today's pending nag and schedule the 16:00 reminder for tomorrow.
  /// Failures are non-fatal: local streak already persisted.
  Future<void> _rescheduleReminderForNextDay() async {
    final notifications = _notifications;
    if (notifications == null) return;
    try {
      final settings = await notifications.getSettings();
      await notifications.cancelAllReminders();
      await notifications.scheduleDailyReminder(
        hour: settings.hour,
        minute: settings.minute,
        skipToday: true,
      );
      if (settings.srsEnabled) {
        await notifications.scheduleSrsReminder();
      }
    } catch (e) {
      debugPrint('Error rescheduling practice reminder: $e');
    }
  }

  /// Publishes the current [_streak] to Firestore via
  /// [ChildProfileSyncService]. Failures are non-fatal: local persistence
  /// already succeeded, and this is a best-effort mirror.
  Future<void> _pushToCloud() async {
    final parentUid = _parentUid;
    final userId = _userId;
    if (parentUid == null || userId == null || userId.isEmpty) return;
    try {
      await _syncService.updatePracticeStreak(parentUid, userId, _streak);
    } catch (e) {
      debugPrint('Error syncing practice streak to the cloud: $e');
    }
  }

  /// Returns the milestone unlocked by the latest [recordPractice] call
  /// (if any) and clears it so the dialog is shown once.
  StreakMilestoneReward? consumePendingMilestone() {
    final pending = _pendingMilestone;
    _pendingMilestone = null;
    return pending;
  }

  static DateTime _dateOnly(DateTime dt) => DateTime(dt.year, dt.month, dt.day);

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }
}
