// lib/data/avatar_catalog.dart

import '../models/avatar_item.dart';

/// Static, predefined catalog of every [AvatarItem] purchasable in the
/// Avatar Customization store.
///
/// This mirrors `CustomizationItem`'s "static catalog" shape (see
/// `lib/models/customization_item.dart`) rather than being loaded from
/// Firestore — the catalog is small, curated, and ships with the app.
/// Asset paths are placeholders until real art lands; the store UI falls
/// back to icon + color swatches when an asset is missing (§2.2 kid UX:
/// icon + color + audio redundancy).
class AvatarCatalog {
  const AvatarCatalog._();

  static const List<AvatarItem> items = [
    // Hats
    AvatarItem(
      id: 'hat_wizard',
      name: 'כובע קוסם',
      type: AvatarItemType.hat,
      assetPath: 'assets/images/avatar/hat_wizard.png',
      cost: 50,
    ),
    AvatarItem(
      id: 'hat_pirate',
      name: 'כובע פיראט',
      type: AvatarItemType.hat,
      assetPath: 'assets/images/avatar/hat_pirate.png',
      cost: 40,
    ),
    AvatarItem(
      id: 'hat_crown',
      name: 'כתר זהב',
      type: AvatarItemType.hat,
      assetPath: 'assets/images/avatar/hat_crown.png',
      cost: 100,
    ),

    // Shirts
    AvatarItem(
      id: 'shirt_red',
      name: 'חולצה אדומה',
      type: AvatarItemType.shirt,
      assetPath: 'assets/images/avatar/shirt_red.png',
      cost: 20,
    ),
    AvatarItem(
      id: 'shirt_blue',
      name: 'חולצה כחולה',
      type: AvatarItemType.shirt,
      assetPath: 'assets/images/avatar/shirt_blue.png',
      cost: 20,
    ),
    AvatarItem(
      id: 'shirt_superhero',
      name: 'חולצת גיבור על',
      type: AvatarItemType.shirt,
      assetPath: 'assets/images/avatar/shirt_superhero.png',
      cost: 75,
    ),

    // Accessories
    AvatarItem(
      id: 'accessory_glasses',
      name: 'משקפיים',
      type: AvatarItemType.accessory,
      assetPath: 'assets/images/avatar/accessory_glasses.png',
      cost: 15,
    ),
    AvatarItem(
      id: 'accessory_bowtie',
      name: 'עניבת פרפר',
      type: AvatarItemType.accessory,
      assetPath: 'assets/images/avatar/accessory_bowtie.png',
      cost: 25,
    ),
    AvatarItem(
      id: 'accessory_wings',
      name: 'כנפי פיה',
      type: AvatarItemType.accessory,
      assetPath: 'assets/images/avatar/accessory_wings.png',
      cost: 100,
    ),
  ];

  /// Ids of items that every child owns for free from the start (no coin
  /// cost, never persisted as "purchased"). Kept empty for v1 — all items
  /// in [items] currently cost coins — but callers should union this with
  /// unlocked ids the same way `CustomizationItem.defaultThemeId` works, so
  /// future free starter items don't require a persistence migration.
  static const List<String> freeStarterItemIds = [];

  /// Looks up a catalog item by id, or `null` if it's not a known item
  /// (e.g. a stale/removed id read back from storage).
  static AvatarItem? byId(String id) {
    for (final item in items) {
      if (item.id == id) return item;
    }
    return null;
  }
}
