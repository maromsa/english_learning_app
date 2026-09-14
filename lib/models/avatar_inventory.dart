// lib/models/avatar_inventory.dart

import '../data/avatar_catalog.dart';

/// The set of [AvatarItem] ids a child has unlocked (owns) in the Avatar
/// Customization store, independent of what's currently equipped (see
/// [EquippedAvatar]).
///
/// Every child implicitly owns [AvatarCatalog.freeStarterItemIds] — those
/// ids are never persisted as "purchased", matching how
/// `CustomizationItem.defaultThemeId` is implicit rather than stored in
/// `ShopCustomizationService`'s unlocked set.
class AvatarInventory {
  const AvatarInventory({this.unlockedItemIds = const {}});

  /// Empty inventory — starter items are added by the provider/service on
  /// top of this, matching `EquippedAvatar.empty()`'s "all slots empty"
  /// convention.
  factory AvatarInventory.empty() => const AvatarInventory();

  final Set<String> unlockedItemIds;

  factory AvatarInventory.fromJson(Map<String, dynamic> json) {
    final raw = json['unlockedItemIds'];
    final ids = raw is List ? raw.whereType<String>().toSet() : <String>{};
    return AvatarInventory(unlockedItemIds: ids);
  }

  Map<String, dynamic> toJson() => {
        'unlockedItemIds': unlockedItemIds.toList(),
      };

  AvatarInventory copyWith({Set<String>? unlockedItemIds}) {
    return AvatarInventory(
      unlockedItemIds: unlockedItemIds ?? this.unlockedItemIds,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is AvatarInventory &&
          other.unlockedItemIds.length == unlockedItemIds.length &&
          other.unlockedItemIds.containsAll(unlockedItemIds));

  @override
  int get hashCode => Object.hashAll(
        unlockedItemIds.toList()..sort(),
      );
}
