// test/providers/coin_provider_test.dart
import 'package:english_learning_app/models/shop_item.dart';
import 'package:english_learning_app/providers/coin_provider.dart';
import 'package:english_learning_app/services/daily_reward_service.dart';
import 'package:english_learning_app/services/streak_shield_service.dart';
import 'package:english_learning_app/services/user_data_service.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  group('CoinProvider', () {
    late CoinProvider coinProvider;

    setUp(() {
      SharedPreferences.setMockInitialValues({});
      coinProvider = CoinProvider(
        userDataService: UserDataService(firestore: FakeFirebaseFirestore()),
      );
    });

    test('initial coins should be 0', () {
      expect(coinProvider.coins, 0);
    });

    test('levelCoins should be 0 initially', () {
      expect(coinProvider.levelCoins, 0);
    });

    test('addCoins should increase coins', () async {
      await coinProvider.addCoins(10);
      expect(coinProvider.coins, 10);
    });

    test('addCoins multiple times should accumulate', () async {
      await coinProvider.addCoins(10);
      await coinProvider.addCoins(5);
      expect(coinProvider.coins, 15);
    });

    test('addCoins should ignore non-positive amounts', () async {
      await coinProvider.addCoins(0);
      await coinProvider.addCoins(-5);
      expect(coinProvider.coins, 0);
    });

    test('setCoins should set coins to specific value', () async {
      await coinProvider.setCoins(100);
      expect(coinProvider.coins, 100);
    });

    test('setCoins should clamp negative values to zero', () async {
      await coinProvider.setCoins(-25);
      expect(coinProvider.coins, 0);
    });

    test('spendCoins should decrease coins when sufficient', () async {
      await coinProvider.setCoins(100);
      final result = await coinProvider.spendCoins(30);
      expect(result, true);
      expect(coinProvider.coins, 70);
    });

    test('spendCoins should return false when insufficient', () async {
      await coinProvider.setCoins(10);
      final result = await coinProvider.spendCoins(30);
      expect(result, false);
      expect(coinProvider.coins, 10);
    });

    test('spendCoins should reject non-positive amounts', () async {
      await coinProvider.setCoins(20);
      final zeroResult = await coinProvider.spendCoins(0);
      final negativeResult = await coinProvider.spendCoins(-5);
      expect(zeroResult, false);
      expect(negativeResult, false);
      expect(coinProvider.coins, 20);
    });

    test('startLevel should track level start coins', () async {
      await coinProvider.setCoins(50);
      await coinProvider.startLevel('test_level');
      await coinProvider.addCoins(20);
      expect(coinProvider.levelCoins, 20);
      expect(coinProvider.coins, 70);
    });

    test('loadCoins should load coins from SharedPreferences', () async {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setInt('totalCoins', 75);

      final newProvider = CoinProvider(
        userDataService: UserDataService(firestore: FakeFirebaseFirestore()),
      );
      await newProvider.loadCoins();
      expect(newProvider.coins, 75);
    });

    group('claimDailyPracticeReward', () {
      test('adds exactly 50 coins and returns true on the first claim today',
          () async {
        final claimed = await coinProvider.claimDailyPracticeReward();

        expect(claimed, isTrue);
        expect(coinProvider.coins, CoinProvider.dailyPracticeRewardCoins);
        expect(CoinProvider.dailyPracticeRewardCoins, 50);
      });

      test('the first claim of the day also starts the daily streak at 1',
          () async {
        expect(coinProvider.dailyStreak, 0);

        await coinProvider.claimDailyPracticeReward();

        expect(coinProvider.dailyStreak, 1);
      });

      test('a consecutive-day claim advances the daily streak', () async {
        final yesterday = DateTime(2024, 1, 1);
        final today = DateTime(2024, 1, 2);
        SharedPreferences.setMockInitialValues({
          'daily_reward_last_claim': yesterday.millisecondsSinceEpoch,
          'daily_reward_streak': 4,
        });
        final provider = CoinProvider(
          userDataService: UserDataService(firestore: FakeFirebaseFirestore()),
          dailyRewardService: DailyRewardService(now: () => today),
        );
        await provider.loadCoins();
        expect(provider.dailyStreak, 4);

        final claimed = await provider.claimDailyPracticeReward();

        expect(claimed, isTrue);
        expect(provider.dailyStreak, 5);
      });

      test('a claim after a missed day resets the daily streak to 1', () async {
        final threeDaysAgo = DateTime(2024, 1, 1);
        final today = DateTime(2024, 1, 4);
        SharedPreferences.setMockInitialValues({
          'daily_reward_last_claim': threeDaysAgo.millisecondsSinceEpoch,
          'daily_reward_streak': 9,
        });
        final provider = CoinProvider(
          userDataService: UserDataService(firestore: FakeFirebaseFirestore()),
          dailyRewardService: DailyRewardService(now: () => today),
        );
        await provider.loadCoins();
        expect(provider.dailyStreak, 9);

        await provider.claimDailyPracticeReward();

        expect(provider.dailyStreak, 1);
      });

      test('a rejected same-day re-claim leaves the streak untouched', () async {
        await coinProvider.claimDailyPracticeReward();
        expect(coinProvider.dailyStreak, 1);

        expect(await coinProvider.claimDailyPracticeReward(), isFalse);
        expect(coinProvider.dailyStreak, 1);
      });

      test('loadCoins surfaces a persisted daily streak', () async {
        SharedPreferences.setMockInitialValues({'daily_reward_streak': 6});
        final provider = CoinProvider(
          userDataService: UserDataService(firestore: FakeFirebaseFirestore()),
        );

        await provider.loadCoins();

        expect(provider.dailyStreak, 6);
      });

      test('returns false and adds no coins on a second claim the same day',
          () async {
        expect(await coinProvider.claimDailyPracticeReward(), isTrue);
        expect(coinProvider.coins, 50);

        expect(await coinProvider.claimDailyPracticeReward(), isFalse);
        expect(coinProvider.coins, 50);
      });

      test('persists the claim date so a fresh provider sees it as claimed',
          () async {
        await coinProvider.claimDailyPracticeReward();

        final reloaded = CoinProvider(
          userDataService: UserDataService(firestore: FakeFirebaseFirestore()),
        );
        await reloaded.loadCoins();

        expect(await reloaded.claimDailyPracticeReward(), isFalse);
        // Coins loaded from prefs (50), unchanged by the rejected re-claim.
        expect(reloaded.coins, 50);
      });
    });

    group('streak shield purchase', () {
      final shieldItem = ShopItem.defaultCatalog
          .firstWhere((i) => i.id == ShopItem.streakShieldId);

      CoinProvider buildProvider(StreakShieldService shield) => CoinProvider(
            userDataService: UserDataService(firestore: FakeFirebaseFirestore()),
            streakShieldService: shield,
          );

      test('costs exactly 150 coins and grants the shield natively', () async {
        final shield = StreakShieldService();
        final provider = buildProvider(shield);
        await provider.setCoins(200);

        final ok = await provider.purchaseItem(shieldItem);

        expect(ok, isTrue);
        expect(shieldItem.cost, 150);
        expect(provider.coins, 50);
        expect(shield.hasShield, isTrue);
      });

      test('does not enter the cosmetic purchasedItems list', () async {
        final shield = StreakShieldService();
        final provider = buildProvider(shield);
        await provider.setCoins(200);

        await provider.purchaseItem(shieldItem);

        expect(provider.ownedShopItemsCount, 0);
        // "owned" for the shield means "currently holding one".
        expect(provider.isOwned(ShopItem.streakShieldId), isTrue);
      });

      test('a second purchase is rejected while one is held (no double charge)',
          () async {
        final shield = StreakShieldService();
        final provider = buildProvider(shield);
        await provider.setCoins(400);

        expect(await provider.purchaseItem(shieldItem), isTrue);
        expect(provider.coins, 250);

        expect(await provider.purchaseItem(shieldItem), isFalse);
        expect(provider.coins, 250);
      });

      test('is rejected when the child cannot afford it', () async {
        final shield = StreakShieldService();
        final provider = buildProvider(shield);
        await provider.setCoins(100);

        expect(await provider.purchaseItem(shieldItem), isFalse);
        expect(provider.coins, 100);
        expect(shield.hasShield, isFalse);
      });

      test('a bought shield absorbs a missed day instead of resetting the streak',
          () async {
        final threeDaysAgo = DateTime(2024, 1, 1);
        final today = DateTime(2024, 1, 4);
        SharedPreferences.setMockInitialValues({
          'daily_reward_last_claim': threeDaysAgo.millisecondsSinceEpoch,
          'daily_reward_streak': 8,
        });
        final shield = StreakShieldService();
        final provider = CoinProvider(
          userDataService: UserDataService(firestore: FakeFirebaseFirestore()),
          streakShieldService: shield,
          dailyRewardService: DailyRewardService(
            now: () => today,
            shieldService: shield,
          ),
        );
        await provider.setCoins(200);
        await provider.loadCoins();
        expect(provider.dailyStreak, 8);

        await provider.purchaseItem(shieldItem);
        expect(shield.hasShield, isTrue);

        await provider.claimDailyPracticeReward();

        // Shield consumed to bridge the gap: streak advances 8 -> 9 rather
        // than resetting to 1.
        expect(provider.dailyStreak, 9);
        expect(shield.hasShield, isFalse);
      });
    });
  });
}
