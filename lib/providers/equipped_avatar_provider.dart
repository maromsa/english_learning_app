import 'package:flutter/foundation.dart';

import '../models/avatar_item.dart';
import '../models/equipped_avatar.dart';

/// Reactive owner of Avatar Customization: which [AvatarItem] is equipped in
/// each slot.
///
/// This follows the same `ChangeNotifier` shape as [ShopCustomizationProvider]
/// / [StickerAlbumProvider] (see CLAUDE.md §2.1 — state lives in
/// `ChangeNotifier` providers wired through `main.dart`'s `MultiProvider`;
/// this app does not use Riverpod). Persistence / cloud sync is a follow-up —
/// this provider is currently in-memory only, matching the v1 scope of the
/// sibling customization providers before their `load()`/service wiring
/// landed.
class EquippedAvatarProvider with ChangeNotifier {
  EquippedAvatarProvider({EquippedAvatar? initial})
      : _equipped = initial ?? EquippedAvatar.empty();

  EquippedAvatar _equipped;
  bool _disposed = false;

  EquippedAvatar get equipped => _equipped;

  void _notify() {
    if (!_disposed) notifyListeners();
  }

  /// Equips [item] into its slot (derived from [AvatarItem.type]), replacing
  /// anything already worn there.
  void equipItem(AvatarItem item) {
    switch (item.type) {
      case AvatarItemType.hat:
        _equipped = _equipped.copyWith(hatId: item.id);
      case AvatarItemType.shirt:
        _equipped = _equipped.copyWith(shirtId: item.id);
      case AvatarItemType.accessory:
        _equipped = _equipped.copyWith(accessoryId: item.id);
      case AvatarItemType.background:
        _equipped = _equipped.copyWith(backgroundId: item.id);
    }
    _notify();
  }

  /// Clears whatever is equipped in [type]'s slot.
  void unequipItem(AvatarItemType type) {
    switch (type) {
      case AvatarItemType.hat:
        _equipped = _equipped.copyWith(clearHat: true);
      case AvatarItemType.shirt:
        _equipped = _equipped.copyWith(clearShirt: true);
      case AvatarItemType.accessory:
        _equipped = _equipped.copyWith(clearAccessory: true);
      case AvatarItemType.background:
        _equipped = _equipped.copyWith(clearBackground: true);
    }
    _notify();
  }

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }
}
