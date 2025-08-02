// lib/providers/shop_provider.dart
import 'package:flutter/foundation.dart';

class ShopProvider with ChangeNotifier {
  final List<String> _purchasedItems = [];

  List<String> get purchasedItems => _purchasedItems;

  void loadPurchasedItems() {
    // טען פריטים שנרכשו (לדוגמה, מה-SharedPreferences)
    _purchasedItems.addAll(['item1', 'item2']);
    notifyListeners();
  }

  void purchaseItem(String item) {
    if (!_purchasedItems.contains(item)) {
      _purchasedItems.add(item);
      notifyListeners();
    }
  }
}
