// test/providers/daily_streak_provider_test.dart
//
// Unit tests for DailyStreakProvider: calendar-day math (same day / next
// day / skipped day), persistence, profile namespacing, and notifyListeners.

import 'package:english_learning_app/models/daily_streak.dart';
import 'package:english_learning_app/providers/coin_provider.dart';
import 'package:english_learning_app/providers/daily_streak_provider.dart';
import 'package:english_learning_app/services/child_profile_sync_service.dart';
import 'package:english_learning_app/services/daily_streak_service.dart';
import 'package:english_learning_app/services/notification_service.dart';
import 'package:english_learning_app/services/user_data_service.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Records every `save()` call so tests can assert persistence without
/// depending on SharedPreferences internals.
class _RecordingDailyStreakService extends DailyStreakService {
  _RecordingDailyStreakService({required SharedPreferences prefs})
      : super(prefs: prefs);

  int saveCount = 0;
  DailyStreak? lastSaved;

  @override
  Future<void> save(String? userId, DailyStreak streak) async {
    saveCount++;
    lastSaved = streak;
    await super.save(userId, streak);
  }
}

class _Clock {
  _Clock(this.value);
  DateTime value;
}

/// Records every `updatePracticeStreak()` call so tests can assert the
/// cloud sync fired (or didn't) without depending on real network.
class _RecordingChildProfileSyncService extends ChildProfileSyncService {
  _RecordingChildProfileSyncService()
      : super(firestore: FakeFirebaseFirestore());

  int callCount = 0;
  String? lastParentUid;
  String? lastProfileId;
  DailyStreak? lastStreak;

  @override
  Future<bool> updatePracticeStreak(
    String parentUid,
    String profileId,
    DailyStreak streak,
  ) async {
    callCount++;
    lastParentUid = parentUid;
    lastProfileId = profileId;
    lastStreak = streak;
    return true;
  }
}

class _RecordingNotificationService extends NotificationService {
  _RecordingNotificationService() : super(plugin: _UnusedNotificationsPlugin());

  int cancelAllCount = 0;
  int scheduleCount = 0;
  int srsScheduleCount = 0;
  int? lastHour;
  int? lastMinute;
  bool? lastSkipToday;

  @override
  Future<({bool dailyEnabled, int hour, int minute, bool srsEnabled})>
      getSettings() async {
    return (
      dailyEnabled: true,
      hour: NotificationService.defaultReminderHour,
      minute: NotificationService.defaultReminderMinute,
      srsEnabled: false,
    );
  }

  @override
  Future<void> cancelAllReminders() async {
    cancelAllCount++;
  }

  @override
  Future<void> scheduleDailyReminder({
    required int hour,
    required int minute,
    bool skipToday = false,
  }) async {
    scheduleCount++;
    lastHour = hour;
    lastMinute = minute;
    lastSkipToday = skipToday;
  }

  @override
  Future<void> scheduleSrsReminder({DateTime? when}) async {
    srsScheduleCount++;
  }
}

class _UnusedNotificationsPlugin extends Fake
    implements FlutterLocalNotificationsPlugin {}

CoinProvider _coins() => CoinProvider(
      userDataService: UserDataService(firestore: FakeFirebaseFirestore()),
    );

Future<DailyStreakProvider> _provider({
  String? userId,
  String? parentUid,
  required _Clock clock,
  DailyStreakService? service,
  ChildProfileSyncService? syncService,
  CoinProvider? coins,
  NotificationService? notifications,
}) async {
  final provider = DailyStreakProvider(
    service: service ??
        DailyStreakService(prefs: await SharedPreferences.getInstance()),
    syncService: syncService ?? _RecordingChildProfileSyncService(),
    now: () => clock.value,
    coinProvider: coins ?? _coins(),
    notificationService: notifications,
  );
  provider.setUserId(userId);
  provider.setParentUid(parentUid);
  await provider.load();
  return provider;
}

/// Records practice on [days] consecutive calendar days starting at [clock].
Future<void> _practiceConsecutive(
  DailyStreakProvider provider,
  _Clock clock,
  int days,
) async {
  for (var i = 0; i < days; i++) {
    if (i > 0) {
      final current = clock.value;
      clock.value = DateTime(current.year, current.month, current.day + 1);
    }
    await provider.recordPractice();
  }
}

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  group('DailyStreakProvider', () {
    test('initial state is an empty streak', () async {
      final provider = await _provider(clock: _Clock(DateTime(2026, 9, 15)));
      expect(provider.currentStreak, 0);
      expect(provider.lastPracticeDate, isNull);
    });

    test('first practice of a new profile starts the streak at 1', () async {
      final clock = _Clock(DateTime(2026, 9, 15, 10, 30));
      final provider = await _provider(clock: clock);

      final recorded = await provider.recordPractice();

      expect(recorded, isTrue);
      expect(provider.currentStreak, 1);
      expect(provider.lastPracticeDate, DateTime(2026, 9, 15));
    });

    test('same-day practice is a no-op (does not increment or re-save)',
        () async {
      final clock = _Clock(DateTime(2026, 9, 15, 8));
      final service = _RecordingDailyStreakService(
        prefs: await SharedPreferences.getInstance(),
      );
      final provider = await _provider(clock: clock, service: service);

      await provider.recordPractice();
      clock.value = DateTime(2026, 9, 15, 22, 45);
      final recordedAgain = await provider.recordPractice();

      expect(recordedAgain, isFalse);
      expect(provider.currentStreak, 1);
      expect(service.saveCount, 1);
    });

    test('practice on the next calendar day increments the streak', () async {
      final clock = _Clock(DateTime(2026, 9, 15, 18));
      final provider = await _provider(clock: clock);

      await provider.recordPractice();
      clock.value = DateTime(2026, 9, 16, 7, 5);
      await provider.recordPractice();

      expect(provider.currentStreak, 2);
      expect(provider.lastPracticeDate, DateTime(2026, 9, 16));
    });

    test('a skipped day resets the streak to 1', () async {
      final clock = _Clock(DateTime(2026, 9, 15));
      final provider = await _provider(clock: clock);

      await provider.recordPractice();
      clock.value = DateTime(2026, 9, 17, 9);
      await provider.recordPractice();

      expect(provider.currentStreak, 1);
      expect(provider.lastPracticeDate, DateTime(2026, 9, 17));
    });

    test('a longer gap also resets the streak to 1', () async {
      final clock = _Clock(DateTime(2026, 9, 1));
      final provider = await _provider(clock: clock);

      await provider.recordPractice();
      clock.value = DateTime(2026, 9, 10);
      await provider.recordPractice();

      expect(provider.currentStreak, 1);
    });

    test('consecutive days accumulate past 2', () async {
      final clock = _Clock(DateTime(2026, 9, 15));
      final provider = await _provider(clock: clock);

      await provider.recordPractice();
      clock.value = DateTime(2026, 9, 16);
      await provider.recordPractice();
      clock.value = DateTime(2026, 9, 17);
      await provider.recordPractice();

      expect(provider.currentStreak, 3);
    });

    test('month-end wrap still counts as consecutive (calendar days)',
        () async {
      final clock = _Clock(DateTime(2026, 9, 30, 23));
      final provider = await _provider(clock: clock);

      await provider.recordPractice();
      clock.value = DateTime(2026, 10, 1, 1);
      await provider.recordPractice();

      expect(provider.currentStreak, 2);
    });

    test('notifyListeners fires only when the streak actually changes',
        () async {
      final clock = _Clock(DateTime(2026, 9, 15));
      final provider = await _provider(clock: clock);
      var notifications = 0;
      provider.addListener(() => notifications++);

      await provider.recordPractice();
      expect(notifications, 1);

      await provider.recordPractice();
      expect(notifications, 1);
    });

    test('recordPractice persists the new state via the storage service',
        () async {
      final clock = _Clock(DateTime(2026, 9, 15));
      final service = _RecordingDailyStreakService(
        prefs: await SharedPreferences.getInstance(),
      );
      final provider = await _provider(clock: clock, service: service);

      await provider.recordPractice();

      expect(service.saveCount, 1);
      expect(service.lastSaved?.currentStreak, 1);
      expect(service.lastSaved?.lastPracticeDate, DateTime(2026, 9, 15));
    });

    test('state survives a reload from SharedPreferences', () async {
      final clock = _Clock(DateTime(2026, 9, 15));
      final provider = await _provider(userId: 'child_1', clock: clock);
      await provider.recordPractice();

      final reloaded = await _provider(userId: 'child_1', clock: clock);
      expect(reloaded.currentStreak, 1);
      expect(reloaded.lastPracticeDate, DateTime(2026, 9, 15));
    });

    test('two profiles keep separate streaks', () async {
      final clock = _Clock(DateTime(2026, 9, 15));
      final childA = await _provider(userId: 'child_a', clock: clock);
      await childA.recordPractice();

      final childB = await _provider(userId: 'child_b', clock: clock);
      expect(childB.currentStreak, 0);
    });
  });

  group('DailyStreakProvider milestones', () {
    test('day 3 grants 20 bonus coins and sets a pending reward', () async {
      final clock = _Clock(DateTime(2026, 9, 1));
      final coins = _coins();
      final provider = await _provider(clock: clock, coins: coins);

      await _practiceConsecutive(provider, clock, 3);

      expect(provider.currentStreak, 3);
      expect(coins.coins, DailyStreakProvider.milestoneRewards[3]);
      expect(provider.claimedMilestones, [3]);
      expect(provider.pendingMilestone?.day, 3);
      expect(provider.pendingMilestone?.coins, 20);
    });

    test('a milestone is not double-claimed on the same streak', () async {
      final clock = _Clock(DateTime(2026, 9, 1));
      final coins = _coins();
      final provider = await _provider(clock: clock, coins: coins);

      await _practiceConsecutive(provider, clock, 3);
      expect(coins.coins, 20);

      final sameDay = await provider.recordPractice();
      expect(sameDay, isFalse);
      expect(coins.coins, 20);

      clock.value = DateTime(2026, 9, 4);
      await provider.recordPractice();
      expect(provider.currentStreak, 4);
      expect(coins.coins, 20);
      expect(provider.claimedMilestones, [3]);
      expect(provider.pendingMilestone, isNull);
    });

    test('day 7 and day 14 grant their bonuses on top of day 3', () async {
      final clock = _Clock(DateTime(2026, 9, 1));
      final coins = _coins();
      final provider = await _provider(clock: clock, coins: coins);

      await _practiceConsecutive(provider, clock, 7);
      expect(coins.coins, 20 + 50);
      expect(provider.claimedMilestones, [3, 7]);
      expect(provider.pendingMilestone?.day, 7);

      final current = clock.value;
      clock.value = DateTime(current.year, current.month, current.day + 1);
      await _practiceConsecutive(provider, clock, 7);
      expect(provider.currentStreak, 14);
      expect(coins.coins, 20 + 50 + 100);
      expect(provider.claimedMilestones, [3, 7, 14]);
      expect(provider.pendingMilestone?.day, 14);
    });

    test('a streak reset lets the child earn the day-3 bonus again', () async {
      final clock = _Clock(DateTime(2026, 9, 1));
      final coins = _coins();
      final provider = await _provider(clock: clock, coins: coins);

      await _practiceConsecutive(provider, clock, 3);
      expect(coins.coins, 20);

      clock.value = DateTime(2026, 9, 5);
      await _practiceConsecutive(provider, clock, 3);

      expect(provider.currentStreak, 3);
      expect(coins.coins, 40);
      expect(provider.claimedMilestones, [3]);
    });

    test('claimed milestones survive a reload and still block a re-award',
        () async {
      final clock = _Clock(DateTime(2026, 9, 1));
      final coins = _coins();
      final first = await _provider(
        userId: 'child_1',
        clock: clock,
        coins: coins,
      );
      await _practiceConsecutive(first, clock, 3);
      expect(coins.coins, 20);

      final reloaded = await _provider(
        userId: 'child_1',
        clock: clock,
        coins: coins,
      );
      expect(reloaded.claimedMilestones, [3]);

      final recorded = await reloaded.recordPractice();
      expect(recorded, isFalse);
      expect(coins.coins, 20);
    });

    test('consumePendingMilestone returns the reward once', () async {
      final clock = _Clock(DateTime(2026, 9, 1));
      final provider = await _provider(clock: clock, coins: _coins());

      await _practiceConsecutive(provider, clock, 3);
      final first = provider.consumePendingMilestone();
      expect(first?.day, 3);
      expect(first?.coins, 20);
      expect(provider.pendingMilestone, isNull);
      expect(provider.consumePendingMilestone(), isNull);
    });

    test('non-milestone days do not add bonus coins', () async {
      final clock = _Clock(DateTime(2026, 9, 1));
      final coins = _coins();
      final provider = await _provider(clock: clock, coins: coins);

      await _practiceConsecutive(provider, clock, 2);

      expect(provider.currentStreak, 2);
      expect(coins.coins, 0);
      expect(provider.pendingMilestone, isNull);
      expect(provider.claimedMilestones, isEmpty);
    });
  });

  group('DailyStreakProvider cloud sync', () {
    test(
        'recordPractice does not push to the cloud without a parentUid '
        '(guest / local profile)', () async {
      final sync = _RecordingChildProfileSyncService();
      final clock = _Clock(DateTime(2026, 9, 15));
      final provider = await _provider(
        userId: 'child_1',
        clock: clock,
        syncService: sync,
      );

      await provider.recordPractice();

      expect(sync.callCount, 0);
    });

    test('recordPractice pushes the new streak once a parentUid is set',
        () async {
      final sync = _RecordingChildProfileSyncService();
      final clock = _Clock(DateTime(2026, 9, 15));
      final provider = await _provider(
        userId: 'child_1',
        parentUid: 'parent_1',
        clock: clock,
        syncService: sync,
      );

      await provider.recordPractice();

      expect(sync.callCount, 1);
      expect(sync.lastParentUid, 'parent_1');
      expect(sync.lastProfileId, 'child_1');
      expect(sync.lastStreak?.currentStreak, 1);
      expect(sync.lastStreak?.lastPracticeDate, DateTime(2026, 9, 15));
    });

    test('same-day practice does not push to the cloud again', () async {
      final sync = _RecordingChildProfileSyncService();
      final clock = _Clock(DateTime(2026, 9, 15, 8));
      final provider = await _provider(
        userId: 'child_1',
        parentUid: 'parent_1',
        clock: clock,
        syncService: sync,
      );

      await provider.recordPractice();
      clock.value = DateTime(2026, 9, 15, 22);
      await provider.recordPractice();

      expect(sync.callCount, 1);
    });
  });

  group('DailyStreakProvider practice reminders', () {
    test('a newly recorded practice cancels nags and schedules tomorrow',
        () async {
      final notifications = _RecordingNotificationService();
      final clock = _Clock(DateTime(2026, 9, 15, 10));
      final provider = await _provider(
        clock: clock,
        notifications: notifications,
      );

      final recorded = await provider.recordPractice();

      expect(recorded, isTrue);
      expect(notifications.cancelAllCount, 1);
      expect(notifications.scheduleCount, 1);
      expect(notifications.lastHour, NotificationService.defaultReminderHour);
      expect(
        notifications.lastMinute,
        NotificationService.defaultReminderMinute,
      );
      expect(notifications.lastSkipToday, isTrue);
      expect(notifications.srsScheduleCount, 0);
    });

    test('same-day practice does not reschedule reminders', () async {
      final notifications = _RecordingNotificationService();
      final clock = _Clock(DateTime(2026, 9, 15, 8));
      final provider = await _provider(
        clock: clock,
        notifications: notifications,
      );

      await provider.recordPractice();
      clock.value = DateTime(2026, 9, 15, 22);
      await provider.recordPractice();

      expect(notifications.cancelAllCount, 1);
      expect(notifications.scheduleCount, 1);
    });
  });
}
