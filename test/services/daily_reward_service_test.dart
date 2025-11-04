import 'dart:math' as math;

import 'package:english_learning_app/services/daily_reward_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _FixedRandom extends math.Random {
  _FixedRandom(this.fixedValue);

  final int fixedValue;

  @override
  int nextInt(int max) => max <= 0 ? 0 : math.min(fixedValue, max - 1);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('DailyRewardService', () {
    late DateTime currentDate;
    late DailyRewardService service;

    setUp(() {
      SharedPreferences.setMockInitialValues({});
      currentDate = DateTime(2024, 1, 1);
      service = DailyRewardService(
        now: () => currentDate,
        random: _FixedRandom(0),
      );
    });

    test('first claim grants reward and streak 1', () async {
      final result = await service.claimReward();
      expect(result.claimed, true);
      expect(result.streak, 1);
      expect(result.reward, greaterThanOrEqualTo(DailyRewardService.minReward));
    });

    test('second claim on same day returns already claimed', () async {
      await service.claimReward();
      final result = await service.claimReward();
      expect(result.claimed, false);
      expect(result.reward, 0);
      expect(result.streak, 1);
    });

    test('consecutive day increases streak and reward', () async {
      await service.claimReward();
      currentDate = currentDate.add(const Duration(days: 1));
      final result = await service.claimReward();
      expect(result.claimed, true);
      expect(result.streak, 2);
      expect(result.reward, greaterThan(DailyRewardService.minReward));
    });

    test('missing a day resets streak', () async {
      await service.claimReward();
      currentDate = currentDate.add(const Duration(days: 2));
      final result = await service.claimReward();
      expect(result.claimed, true);
      expect(result.streak, 1);
    });
  });
}
