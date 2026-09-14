// test/providers/avatar_inventory_provider_test.dart
//
// Unit tests for AvatarInventoryProvider: purchase deducts coins via
// CoinProvider, unlocks the item, persists, and is namespaced per profile
// just like EquippedAvatarProvider / ShopCustomizationProvider.

import 'package:english_learning_app/models/avatar_inventory.dart';
import 'package:english_learning_app/models/avatar_item.dart';
import 'package:english_learning_app/providers/avatar_inventory_provider.dart';
import 'package:english_learning_app/providers/coin_provider.dart';
import 'package:english_learning_app/services/avatar_inventory_service.dart';
import 'package:english_learning_app/services/user_data_service.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

const _hat = AvatarItem(
  id: 'hat_wizard',
  name: 'כובע קוסם',
  type: AvatarItemType.hat,
  assetPath: 'assets/images/avatar/hat_wizard.png',
  cost: 50,
);

const _shirt = AvatarItem(
  id: 'shirt_red',
  name: 'חולצה אדומה',
  type: AvatarItemType.shirt,
  assetPath: 'assets/images/avatar/shirt_red.png',
  cost: 20,
);

/// Records every `save()` call so tests can assert persistence was
/// triggered without depending on `SharedPreferences` internals.
class _RecordingAvatarInventoryService extends AvatarInventoryService {
  _RecordingAvatarInventoryService({required SharedPreferences prefs})
      : super(prefs: prefs);

  int saveCount = 0;
  AvatarInventory? lastSaved;

  @override
  Future<void> save(String? userId, AvatarInventory inventory) async {
    saveCount++;
    lastSaved = inventory;
    await super.save(userId, inventory);
  }
}

Future<CoinProvider> _coins(int amount) async {
  final provider = CoinProvider(
    userDataService: UserDataService(firestore: FakeFirebaseFirestore()),
  );
  await provider.setCoins(amount);
  return provider;
}

Future<AvatarInventoryProvider> _provider({
  String? userId,
  AvatarInventoryService? service,
}) async {
  final provider = AvatarInventoryProvider(
    service: service ??
        AvatarInventoryService(prefs: await SharedPreferences.getInstance()),
  );
  provider.setUserId(userId);
  await provider.load();
  return provider;
}

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  group('AvatarInventoryProvider', () {
    test('initial state owns nothing', () async {
      final provider = await _provider();
      expect(provider.isOwned(_hat), isFalse);
      expect(provider.unlockedItemIds, isEmpty);
    });

    test('purchaseItem deducts coins via CoinProvider and unlocks the item',
        () async {
      final coins = await _coins(100);
      final provider = await _provider();

      final ok = await provider.purchaseItem(_hat, coins);

      expect(ok, isTrue);
      expect(coins.coins, 50); // 100 - 50
      expect(provider.isOwned(_hat), isTrue);
    });

    test(
        'purchaseItem fails and charges nothing when the child cannot '
        'afford it', () async {
      final coins = await _coins(10);
      final provider = await _provider();

      final ok = await provider.purchaseItem(_hat, coins);

      expect(ok, isFalse);
      expect(coins.coins, 10);
      expect(provider.isOwned(_hat), isFalse);
    });

    test(
        'purchasing an already-owned item is a no-op success and charges '
        'nothing', () async {
      final coins = await _coins(100);
      final provider = await _provider();
      await provider.purchaseItem(_hat, coins);

      final ok = await provider.purchaseItem(_hat, coins);

      expect(ok, isTrue);
      expect(coins.coins, 50); // only charged once
    });

    test('purchasing multiple items accumulates the unlocked set', () async {
      final coins = await _coins(100);
      final provider = await _provider();

      await provider.purchaseItem(_hat, coins);
      await provider.purchaseItem(_shirt, coins);

      expect(provider.isOwned(_hat), isTrue);
      expect(provider.isOwned(_shirt), isTrue);
      expect(coins.coins, 30); // 100 - 50 - 20
    });

    test('notifyListeners fires on a successful purchase', () async {
      final coins = await _coins(100);
      final provider = await _provider();
      var notifications = 0;
      provider.addListener(() => notifications++);

      await provider.purchaseItem(_hat, coins);

      expect(notifications, 1);
    });

    test('notifyListeners does not fire on a failed purchase', () async {
      final coins = await _coins(10);
      final provider = await _provider();
      var notifications = 0;
      provider.addListener(() => notifications++);

      await provider.purchaseItem(_hat, coins);

      expect(notifications, 0);
    });

    test('purchaseItem persists the new inventory via the storage service',
        () async {
      final coins = await _coins(100);
      final service = _RecordingAvatarInventoryService(
        prefs: await SharedPreferences.getInstance(),
      );
      final provider = await _provider(service: service);

      await provider.purchaseItem(_hat, coins);

      expect(service.saveCount, 1);
      expect(service.lastSaved?.unlockedItemIds, contains(_hat.id));
    });

    test('state survives a reload from SharedPreferences', () async {
      final coins = await _coins(100);
      final provider = await _provider(userId: 'child_1');
      await provider.purchaseItem(_hat, coins);

      final reloaded = await _provider(userId: 'child_1');

      expect(reloaded.isOwned(_hat), isTrue);
    });

    test('two profiles keep separate inventories', () async {
      final coins = await _coins(100);
      final childA = await _provider(userId: 'child_a');
      await childA.purchaseItem(_hat, coins);

      final childB = await _provider(userId: 'child_b');

      expect(childB.isOwned(_hat), isFalse);
    });

    test('load() restores an empty inventory when nothing was saved yet',
        () async {
      final provider = await _provider(userId: 'brand_new_child');
      expect(provider.unlockedItemIds, isEmpty);
    });
  });
}
