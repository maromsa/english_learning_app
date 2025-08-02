// lib/models/shop_item.dart
class ShopItem {
  final String id;
  final String name;
  final String imageUrl;
  final int cost;
  bool isPurchased;

  ShopItem({
    required this.id,
    required this.name,
    required this.imageUrl,
    required this.cost,
    this.isPurchased = false,
  });
}
