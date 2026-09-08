// test/providers/shop_customization_provider_test.dart
//
// Unit tests for ShopCustomizationProvider: buying delegates the coin debit to
// CoinProvider, unlocks + auto-equips, and persists; equipping is gated on
// ownership.

import 'package:english_learning_app/models/customization_item.dart';
import 'package:english_learning_app/providers/coin_provider.dart';
import 'package:english_learning_app/providers/shop_customization_provider.dart';
import 'package:english_learning_app/services/shop_customization_service.dart';
import 'package:english_learning_app/services/sound_service.dart';
import 'package:english_learning_app/services/user_data_service.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

Future<CoinProvider> _coins(int amount) async {
  final provider = CoinProvider(
    userDataService: UserDataService(firestore: FakeFirebaseFirestore()),
  );
  await provider.setCoins(amount);
  return provider;
}

Future<ShopCustomizationProvider> _customization() async {
  final provider = ShopCustomizationProvider(
    service: ShopCustomizationService(
      prefs: await SharedPreferences.getInstance(),
    ),
  );
  await provider.load();
  return provider;
}

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
    SoundService().victorySoundAsset = null;
  });

  test('defaults are owned and equipped; extras are not', () async {
    final c = await _customization();
    expect(c.isOwned(CustomizationItem.defaultTheme), isTrue);
    expect(c.isEquipped(CustomizationItem.defaultTheme), isTrue);
    expect(c.isOwned(CustomizationItem.spaceTheme), isFalse);
    expect(c.equippedMapPalette, CustomizationItem.defaultPalette);
  });

  test('buy deducts coins via CoinProvider, unlocks, and auto-equips',
      () async {
    final coins = await _coins(500);
    final c = await _customization();

    final ok = await c.buy(CustomizationItem.spaceTheme, coins);

    expect(ok, isTrue);
    expect(coins.coins, 200); // 500 - 300
    expect(c.isOwned(CustomizationItem.spaceTheme), isTrue);
    expect(c.isEquipped(CustomizationItem.spaceTheme), isTrue);
    expect(
      c.equippedMapPalette,
      CustomizationItem.spaceTheme.palette,
    );
  });

  test('buy fails and charges nothing when the child cannot afford it',
      () async {
    final coins = await _coins(100);
    final c = await _customization();

    final ok = await c.buy(CustomizationItem.spaceTheme, coins);

    expect(ok, isFalse);
    expect(coins.coins, 100);
    expect(c.isOwned(CustomizationItem.spaceTheme), isFalse);
    expect(c.isEquipped(CustomizationItem.defaultTheme), isTrue);
  });

  test('buying a sound pushes its asset into SoundService', () async {
    final coins = await _coins(500);
    final c = await _customization();

    await c.buy(CustomizationItem.funnySound, coins);

    expect(c.isEquipped(CustomizationItem.funnySound), isTrue);
    expect(SoundService().victorySoundAsset,
        CustomizationItem.funnySound.soundAsset);
  });

  test('equip is rejected for an item the child does not own', () async {
    final c = await _customization();

    final ok = await c.equip(CustomizationItem.goldTheme);

    expect(ok, isFalse);
    expect(c.isEquipped(CustomizationItem.defaultTheme), isTrue);
  });

  test('equip switches between two owned themes', () async {
    final coins = await _coins(1000);
    final c = await _customization();
    await c.buy(CustomizationItem.spaceTheme, coins); // auto-equipped
    await c.buy(CustomizationItem.goldTheme, coins); // auto-equipped

    expect(c.isEquipped(CustomizationItem.goldTheme), isTrue);

    final ok = await c.equip(CustomizationItem.spaceTheme);
    expect(ok, isTrue);
    expect(c.isEquipped(CustomizationItem.spaceTheme), isTrue);
  });

  test('state survives a reload from SharedPreferences', () async {
    final coins = await _coins(500);
    final c = await _customization();
    await c.buy(CustomizationItem.spaceTheme, coins);

    final reloaded = await _customization();
    expect(reloaded.isOwned(CustomizationItem.spaceTheme), isTrue);
    expect(reloaded.isEquipped(CustomizationItem.spaceTheme), isTrue);
  });

  test('an equipped id that is no longer owned falls back to default on load',
      () async {
    final prefs = await SharedPreferences.getInstance();
    // Equipped points at the space theme, but it was never added to unlocked.
    await prefs.setString(
        'guest_equipped_theme', CustomizationItem.spaceThemeId);

    final c = await _customization();
    expect(c.equippedThemeId, CustomizationItem.defaultThemeId);
  });
}
