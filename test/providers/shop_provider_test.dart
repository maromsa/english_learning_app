// test/providers/shop_provider_test.dart
import 'package:english_learning_app/providers/shop_provider.dart';
import 'package:english_learning_app/services/user_data_service.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  group('ShopProvider', () {
    late ShopProvider shopProvider;

    setUp(() {
      SharedPreferences.setMockInitialValues({});
      shopProvider = ShopProvider(
        userDataService: UserDataService(firestore: FakeFirebaseFirestore()),
      );
    });

    test('should expose a non-empty product catalog', () {
      expect(shopProvider.products, isNotEmpty);
    });

    test('products should include Magic Hat (Hebrew display)', () {
      final magicHat = shopProvider.products.firstWhere(
        (p) => p.id == 'magic_hat',
      );
      expect(magicHat.name, 'כובע קסמים');
      expect(magicHat.price, 50);
    });

    test('isPurchased should return false for new items', () {
      expect(shopProvider.isPurchased('magic_hat'), false);
    });

    test('purchase should add item to purchased list', () async {
      await shopProvider.purchase('magic_hat');
      expect(shopProvider.isPurchased('magic_hat'), true);
    });

    test('purchase should not duplicate items', () async {
      await shopProvider.purchase('magic_hat');
      await shopProvider.purchase('magic_hat');
      expect(shopProvider.purchasedItemIds.length, 1);
    });

    test('canBuy should return true when coins sufficient', () {
      expect(shopProvider.canBuy(100, 50), true);
    });

    test('canBuy should return false when coins insufficient', () {
      expect(shopProvider.canBuy(30, 50), false);
    });

    test('canBuy should return true when coins equal price', () {
      expect(shopProvider.canBuy(50, 50), true);
    });

    test('loadPurchasedItems should load from SharedPreferences', () async {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setStringList('purchased_items', [
        'magic_hat',
        'super_shoes',
      ]);

      final newProvider = ShopProvider(
        userDataService: UserDataService(firestore: FakeFirebaseFirestore()),
      );
      await newProvider.loadPurchasedItems();
      expect(newProvider.isPurchased('magic_hat'), true);
      expect(newProvider.isPurchased('super_shoes'), true);
      expect(newProvider.isPurchased('power_sword'), false);
    });
  });
}
