import 'package:english_learning_app/providers/coin_provider.dart';
import 'package:english_learning_app/providers/daily_mission_provider.dart';
import 'package:english_learning_app/services/user_data_service.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  group('DailyMissionProvider.claimReward', () {
    late DailyMissionProvider provider;
    late CoinProvider coinProvider;

    setUp(() async {
      SharedPreferences.setMockInitialValues({});
      provider = DailyMissionProvider();
      coinProvider = CoinProvider(
        userDataService: UserDataService(firestore: FakeFirebaseFirestore()),
      );
      await provider.initialize();
    });

    test('double claim awards coins only once', () async {
      final mission = provider.missions.first;
      mission.progress = mission.target;
      expect(mission.isClaimable, isTrue);
      final initialCoins = coinProvider.coins;

      final first = provider.claimReward(
        mission.id,
        (reward) => coinProvider.addCoins(reward),
      );
      final second = provider.claimReward(
        mission.id,
        (reward) => coinProvider.addCoins(reward),
      );

      final results = await Future.wait([first, second]);
      expect(results.where((claimed) => claimed).length, 1);
      expect(coinProvider.coins, initialCoins + mission.reward);
    });
  });
}
