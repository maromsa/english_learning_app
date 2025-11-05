import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/product.dart';

class ShopProvider with ChangeNotifier {
  final List<Product> _products = [
    Product(
      id: 'magic_hat',
      name: 'כובע קסמים (Magic Hat)',
      price: 50,
      assetImagePath: 'assets/images/magic_hat.jpg',
    ),
    Product(
      id: 'super_shoes',
      name: 'נעלי-על (Super Shoes)',
      price: 100,
      assetImagePath: 'assets/images/super_shoes.jpg',
    ),
    Product(
      id: 'power_sword',
      name: 'חרב כוח (Power Sword)',
      price: 200,
      assetImagePath: 'assets/images/power_sword.jpg',
    ),
  ];

  List<Product> get products => [..._products];

  final List<String> _purchasedItemIds = [];

  List<String> get purchasedItemIds => [..._purchasedItemIds];

  Future<void> loadPurchasedItems() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final purchasedIds = prefs.getStringList('purchased_items') ?? [];
      _purchasedItemIds.clear();
      _purchasedItemIds.addAll(purchasedIds);
      notifyListeners();
    } catch (e) {
      debugPrint('Error loading purchased items: $e');
    }
  }

  Future<void> _savePurchasedItems() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setStringList('purchased_items', _purchasedItemIds);
    } catch (e) {
      debugPrint('Error saving purchased items: $e');
    }
  }

  bool isPurchased(String productId) {
    return _purchasedItemIds.contains(productId);
  }

  bool canBuy(int coins, int price) {
    return coins >= price;
  }

  Future<void> purchase(String productId) async {
    if (!_purchasedItemIds.contains(productId)) {
      _purchasedItemIds.add(productId);
      notifyListeners();
      await _savePurchasedItems();
    }
  }
}
