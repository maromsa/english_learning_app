import 'package:flutter/foundation.dart';
import '../models/product.dart';

class ShopProvider with ChangeNotifier {
  final List<Product> _products = [
    Product(
      id: 'magic_hat',
      name: 'Magic Hat',
      price: 50,
      assetImagePath: 'assets/images/magic_hat.jpg',
    ),
    Product(
      id: 'super_shoes',
      name: 'Super Shoes',
      price: 100,
      assetImagePath: 'assets/images/super_shoes.jpg',
    ),
    Product(
      id: 'power_sword',
      name: 'Power Sword',
      price: 200,
      assetImagePath: 'assets/images/power_sword.jpg',
    ),

  ];


  List<Product> get products => [..._products];

  final List<String> _purchasedItemIds = [];

  List<String> get purchasedItemIds => [..._purchasedItemIds];

  void loadPurchasedItems() {
    // לדוגמה טוען מהאחסון המקומי
    _purchasedItemIds.addAll([]);
    notifyListeners();
  }

  bool isPurchased(String productId) {
    return _purchasedItemIds.contains(productId);
  }

  bool canBuy(int coins, int price) {
    return coins >= price;
  }

  void purchase(String productId) {
    if (!_purchasedItemIds.contains(productId)) {
      _purchasedItemIds.add(productId);
      notifyListeners();
    }
  }


}
