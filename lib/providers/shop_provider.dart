import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/product.dart';

class ShopProvider with ChangeNotifier {
  final List<Product> _products = [
    // Accessories
    Product(
      id: 'magic_hat',
      name: 'כובע קסמים',
      englishName: 'Magic Hat',
      price: 50,
      assetImagePath: 'assets/images/words/magic_hat.png',
      category: ProductCategory.accessories,
      rarity: ProductRarity.common,
      description: 'כובע קסום שמעניק לך כוחות מיוחדים!',
      specialEffect: 'מגביר את המזל שלך',
    ),
    Product(
      id: 'super_shoes',
      name: 'נעלי-על',
      englishName: 'Super Shoes',
      price: 100,
      assetImagePath: 'assets/images/super_shoes.jpg',
      category: ProductCategory.powerUps,
      rarity: ProductRarity.rare,
      description: 'נעליים מהירות שיעזרו לך להגיע מהר יותר!',
      specialEffect: 'מגביר את המהירות',
    ),
    Product(
      id: 'power_sword',
      name: 'חרב כוח',
      englishName: 'Power Sword',
      price: 200,
      assetImagePath: 'assets/images/words/power_sword.png',
      category: ProductCategory.powerUps,
      rarity: ProductRarity.epic,
      description: 'חרב עוצמתית עם כוחות קסומים!',
      specialEffect: 'מגביר את הכוח שלך',
    ),
    // Magical Items
    Product(
      id: 'magic_wand',
      name: 'שרביט קסמים',
      englishName: 'Magic Wand',
      price: 150,
      assetImagePath: 'assets/images/words/magic_wand.png',
      category: ProductCategory.magical,
      rarity: ProductRarity.rare,
      description: 'שרביט קסום שיעזור לך ללמוד מילים חדשות!',
      specialEffect: 'מקל על הלמידה',
    ),
    Product(
      id: 'spell_book',
      name: 'ספר קסמים',
      englishName: 'Spell Book',
      price: 180,
      assetImagePath: 'assets/images/words/spell_book.png',
      category: ProductCategory.magical,
      rarity: ProductRarity.epic,
      description: 'ספר עתיק מלא בקסמים ומילים חדשות!',
      specialEffect: 'פותח מילים חדשות',
    ),
    Product(
      id: 'crystal_ball',
      name: 'כדור קריסטל',
      englishName: 'Crystal Ball',
      price: 120,
      assetImagePath: 'assets/images/words/crystal_ball.png',
      category: ProductCategory.magical,
      rarity: ProductRarity.rare,
      description: 'כדור קסום שמראה לך את העתיד!',
      specialEffect: 'מגלה רמזים',
    ),
    Product(
      id: 'magic_amulet',
      name: 'קמע קסום',
      englishName: 'Magic Amulet',
      price: 250,
      assetImagePath: 'assets/images/words/magic_amulet.png',
      category: ProductCategory.magical,
      rarity: ProductRarity.legendary,
      description: 'קמע עתיק עם כוחות חזקים מאוד!',
      specialEffect: 'מגן עליך ומגביר את כל הכוחות',
    ),
    Product(
      id: 'potion',
      name: 'שיקוי קסמים',
      englishName: 'Magic Potion',
      price: 80,
      assetImagePath: 'assets/images/words/potion.png',
      category: ProductCategory.magical,
      rarity: ProductRarity.common,
      description: 'שיקוי קסום שמחזק את הזיכרון!',
      specialEffect: 'משפר את הזיכרון',
    ),
    // Power Ups
    Product(
      id: 'hero_shield',
      name: 'מגן גיבור',
      englishName: 'Hero Shield',
      price: 220,
      assetImagePath: 'assets/images/words/hero_shield.png',
      category: ProductCategory.powerUps,
      rarity: ProductRarity.epic,
      description: 'מגן חזק שמגן עליך מכל הסכנות!',
      specialEffect: 'מגן מפני שגיאות',
    ),
    Product(
      id: 'dragon_armor',
      name: 'שריון דרקון',
      englishName: 'Dragon Armor',
      price: 300,
      assetImagePath: 'assets/images/words/dragon_armor.png',
      category: ProductCategory.powerUps,
      rarity: ProductRarity.legendary,
      description: 'שריון חזק מאוד עשוי מקשקשי דרקון!',
      specialEffect: 'מגביר את כל הכוחות שלך',
    ),
    Product(
      id: 'energy_gauntlet',
      name: 'כפפת אנרגיה',
      englishName: 'Energy Gauntlet',
      price: 160,
      assetImagePath: 'assets/images/words/energy_gauntlet.png',
      category: ProductCategory.powerUps,
      rarity: ProductRarity.rare,
      description: 'כפפה מיוחדת שמגבירה את האנרגיה שלך!',
      specialEffect: 'מגביר אנרגיה',
    ),
    // Special Items
    Product(
      id: 'flying_broom',
      name: 'מטאטא מעופף',
      englishName: 'Flying Broom',
      price: 280,
      assetImagePath: 'assets/images/words/flying_broom.png',
      category: ProductCategory.special,
      rarity: ProductRarity.epic,
      description: 'מטאטא קסום שמאפשר לך לעוף!',
      specialEffect: 'מאפשר לך לעוף בין רמות',
    ),
    Product(
      id: 'treasure_map',
      name: 'מפת אוצר',
      englishName: 'Treasure Map',
      price: 140,
      assetImagePath: 'assets/images/words/treasure_map.png',
      category: ProductCategory.special,
      rarity: ProductRarity.rare,
      description: 'מפה קסומה שמובילה לאוצרות נסתרים!',
      specialEffect: 'מגלה אוצרות נסתרים',
    ),
  ];

  List<Product> get products => [..._products];

  List<Product> getProductsByCategory(ProductCategory category) {
    return _products.where((p) => p.category == category).toList();
  }

  List<ProductCategory> get categories {
    return ProductCategory.values;
  }

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
