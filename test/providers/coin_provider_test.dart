// test/providers/coin_provider_test.dart
import 'package:flutter_test/flutter_test.dart';
import 'package:english_learning_app/providers/coin_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  group('CoinProvider', () {
    late CoinProvider coinProvider;

    setUp(() {
      SharedPreferences.setMockInitialValues({});
      coinProvider = CoinProvider();
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
      coinProvider.startLevel();
      await coinProvider.addCoins(20);
      expect(coinProvider.levelCoins, 20);
      expect(coinProvider.coins, 70);
    });

    test('loadCoins should load coins from SharedPreferences', () async {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setInt('totalCoins', 75);

      final newProvider = CoinProvider();
      await newProvider.loadCoins();
      expect(newProvider.coins, 75);
    });
  });
}
