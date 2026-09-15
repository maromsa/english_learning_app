// test/providers/daily_streak_provider_test.dart
//
// Unit tests for DailyStreakProvider: calendar-day math (same day / next
// day / skipped day), persistence, profile namespacing, and notifyListeners.

import 'package:english_learning_app/models/daily_streak.dart';
import 'package:english_learning_app/providers/daily_streak_provider.dart';
import 'package:english_learning_app/services/daily_streak_service.dart';
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

Future<DailyStreakProvider> _provider({
  String? userId,
  required _Clock clock,
  DailyStreakService? service,
}) async {
  final provider = DailyStreakProvider(
    service: service ??
        DailyStreakService(prefs: await SharedPreferences.getInstance()),
    now: () => clock.value,
  );
  provider.setUserId(userId);
  await provider.load();
  return provider;
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
}
