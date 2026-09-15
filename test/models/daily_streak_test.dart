import 'package:english_learning_app/models/daily_streak.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('DailyStreak', () {
    test('empty streak starts at 0 with no last practice date', () {
      final streak = DailyStreak.empty();
      expect(streak.currentStreak, 0);
      expect(streak.lastPracticeDate, isNull);
    });

    test('toJson / fromJson round-trip', () {
      final streak = DailyStreak(
        currentStreak: 4,
        lastPracticeDate: DateTime(2026, 9, 15),
        claimedMilestones: const [3],
      );
      final restored = DailyStreak.fromJson(streak.toJson());
      expect(restored.currentStreak, 4);
      expect(restored.lastPracticeDate, DateTime(2026, 9, 15));
      expect(restored.claimedMilestones, [3]);
    });

    test('toJson omits empty claimedMilestones', () {
      const streak = DailyStreak(currentStreak: 1);
      expect(streak.toJson().containsKey('claimedMilestones'), isFalse);
    });

    test('fromJson defaults missing claimedMilestones to empty', () {
      final restored = DailyStreak.fromJson(const {
        'currentStreak': 3,
        'lastPracticeDate': '2026-09-15',
      });
      expect(restored.claimedMilestones, isEmpty);
    });

    test('toJson omits a null lastPracticeDate', () {
      const streak = DailyStreak(currentStreak: 0);
      final json = streak.toJson();
      expect(json['currentStreak'], 0);
      expect(json.containsKey('lastPracticeDate'), isFalse);
    });

    test('fromJson tolerates a missing or malformed document', () {
      expect(DailyStreak.fromJson(const {}), DailyStreak.empty());
      expect(
        DailyStreak.fromJson(const {
          'currentStreak': 'nope',
          'lastPracticeDate': 3.14,
        }).currentStreak,
        0,
      );
      expect(
        DailyStreak.fromJson(const {'lastPracticeDate': 'not-a-date'})
            .lastPracticeDate,
        isNull,
      );
    });

    test('fromJson accepts millisecond timestamps', () {
      final midnight = DateTime(2026, 9, 14);
      final restored = DailyStreak.fromJson({
        'currentStreak': 2,
        'lastPracticeDate': midnight.millisecondsSinceEpoch,
      });
      expect(restored.currentStreak, 2);
      expect(restored.lastPracticeDate, midnight);
    });

    test('copyWith updates only the given fields', () {
      const streak = DailyStreak(currentStreak: 1);
      final updated = streak.copyWith(
        currentStreak: 2,
        lastPracticeDate: DateTime(2026, 9, 15),
      );
      expect(updated.currentStreak, 2);
      expect(updated.lastPracticeDate, DateTime(2026, 9, 15));
      expect(updated.copyWith().currentStreak, 2);
    });
  });
}
