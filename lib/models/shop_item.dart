/// Data model for a purchasable shop item (sticker, upgrade, or accessory).
class ShopItem {
  final String id;
  final String name;
  final String imageUrl;
  final int cost;
  final ShopItemType type;

  const ShopItem({
    required this.id,
    required this.name,
    required this.imageUrl,
    required this.cost,
    this.type = ShopItemType.sticker,
  });

  /// Default catalog of shop items (stickers and upgrades) for the grid.
  static List<ShopItem> get defaultCatalog => [
        // Stickers / accessories
        const ShopItem(
          id: 'magic_hat',
          name: 'כובע קסמים',
          imageUrl: 'assets/images/words/magic_hat.png',
          cost: 50,
          type: ShopItemType.sticker,
        ),
        const ShopItem(
          id: 'magic_wand',
          name: 'שרביט קסמים',
          imageUrl: 'assets/images/words/magic_wand.png',
          cost: 150,
          type: ShopItemType.sticker,
        ),
        const ShopItem(
          id: 'spell_book',
          name: 'ספר קסמים',
          imageUrl: 'assets/images/words/spell_book.png',
          cost: 180,
          type: ShopItemType.sticker,
        ),
        const ShopItem(
          id: 'crystal_ball',
          name: 'כדור קריסטל',
          imageUrl: 'assets/images/words/crystal_ball.png',
          cost: 120,
          type: ShopItemType.sticker,
        ),
        const ShopItem(
          id: 'potion',
          name: 'שיקוי קסמים',
          imageUrl: 'assets/images/words/potion.png',
          cost: 80,
          type: ShopItemType.sticker,
        ),
        const ShopItem(
          id: 'magic_amulet',
          name: 'קמע קסום',
          imageUrl: 'assets/images/words/magic_amulet.png',
          cost: 250,
          type: ShopItemType.upgrade,
        ),
        const ShopItem(
          id: 'power_sword',
          name: 'חרב כוח',
          imageUrl: 'assets/images/words/power_sword.png',
          cost: 200,
          type: ShopItemType.upgrade,
        ),
        const ShopItem(
          id: 'hero_shield',
          name: 'מגן גיבור',
          imageUrl: 'assets/images/words/hero_shield.png',
          cost: 220,
          type: ShopItemType.upgrade,
        ),
        const ShopItem(
          id: 'dragon_armor',
          name: 'שריון דרקון',
          imageUrl: 'assets/images/words/dragon_armor.png',
          cost: 300,
          type: ShopItemType.upgrade,
        ),
        const ShopItem(
          id: 'flying_broom',
          name: 'מטאטא מעופף',
          imageUrl: 'assets/images/words/flying_broom.png',
          cost: 280,
          type: ShopItemType.sticker,
        ),
        const ShopItem(
          id: 'treasure_map',
          name: 'מפת אוצר',
          imageUrl: 'assets/images/words/treasure_map.png',
          cost: 140,
          type: ShopItemType.sticker,
        ),
        const ShopItem(
          id: 'energy_gauntlet',
          name: 'כפפת אנרגיה',
          imageUrl: 'assets/images/words/energy_gauntlet.png',
          cost: 160,
          type: ShopItemType.upgrade,
        ),
      ];
}

enum ShopItemType {
  sticker,
  upgrade,
}
