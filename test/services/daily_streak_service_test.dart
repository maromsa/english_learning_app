import 'package:english_learning_app/models/daily_streak.dart';
import 'package:english_learning_app/services/daily_streak_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  group('DailyStreakService', () {
    test('load returns empty when nothing has been saved', () async {
      final service = DailyStreakService(
        prefs: await SharedPreferences.getInstance(),
      );
      expect(await service.load('child_1'), DailyStreak.empty());
    });

    test('save then load round-trips the streak', () async {
      final service = DailyStreakService(
        prefs: await SharedPreferences.getInstance(),
      );
      const streak = DailyStreak(
        currentStreak: 3,
        lastPracticeDate: null,
      );
      final withDate = streak.copyWith(
        lastPracticeDate: DateTime(2026, 9, 15),
      );
      await service.save('child_1', withDate);

      final loaded = await service.load('child_1');
      expect(loaded.currentStreak, 3);
      expect(loaded.lastPracticeDate, DateTime(2026, 9, 15));
    });

    test('two profiles keep separate streaks', () async {
      final service = DailyStreakService(
        prefs: await SharedPreferences.getInstance(),
      );
      await service.save(
        'child_a',
        DailyStreak(
          currentStreak: 5,
          lastPracticeDate: DateTime(2026, 9, 15),
        ),
      );

      expect(await service.load('child_b'), DailyStreak.empty());
    });

    test('null userId uses the guest namespace', () async {
      final service = DailyStreakService(
        prefs: await SharedPreferences.getInstance(),
      );
      await service.save(
        null,
        DailyStreak(
          currentStreak: 2,
          lastPracticeDate: DateTime(2026, 9, 14),
        ),
      );

      final loaded = await service.load(null);
      expect(loaded.currentStreak, 2);
      expect(
          (await SharedPreferences.getInstance()).containsKey(
            'user_guest_daily_streak',
          ),
          isTrue);
    });
  });
}
