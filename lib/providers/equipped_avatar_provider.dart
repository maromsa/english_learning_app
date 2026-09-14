import 'package:flutter/foundation.dart';

import '../models/avatar_item.dart';
import '../models/equipped_avatar.dart';
import '../services/equipped_avatar_service.dart';

/// Reactive owner of Avatar Customization: which [AvatarItem] is equipped in
/// each slot.
///
/// This follows the same `ChangeNotifier` shape as [ShopCustomizationProvider]
/// / [StickerAlbumProvider] (see CLAUDE.md §2.1 — state lives in
/// `ChangeNotifier` providers wired through `main.dart`'s `MultiProvider`;
/// this app does not use Riverpod). Persistence is per-child and local-only
/// (see [EquippedAvatarService]); cloud mirroring is a follow-up, matching
/// the sibling customization providers' v1.
class EquippedAvatarProvider with ChangeNotifier {
  EquippedAvatarProvider(
      {EquippedAvatar? initial, EquippedAvatarService? service})
      : _equipped = initial ?? EquippedAvatar.empty(),
        _service = service ?? EquippedAvatarService();

  final EquippedAvatarService _service;
  EquippedAvatar _equipped;
  String? _userId;
  bool _disposed = false;

  EquippedAvatar get equipped => _equipped;

  void _notify() {
    if (!_disposed) notifyListeners();
  }

  /// Points persistence at [userId]'s namespace (guest when null).
  void setUserId(String? userId) {
    _userId = userId;
  }

  /// Loads the persisted equipped avatar for the current profile.
  /// Best-effort: a read failure leaves the previous (or empty) state in
  /// place.
  Future<void> load() async {
    try {
      _equipped = await _service.load(_userId);
      _notify();
    } catch (e) {
      debugPrint('Error loading equipped avatar: $e');
    }
  }

  /// Equips [item] into its slot (derived from [AvatarItem.type]), replacing
  /// anything already worn there.
  Future<void> equipItem(AvatarItem item) async {
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
    await _service.save(_userId, _equipped);
    _notify();
  }

  /// Clears whatever is equipped in [type]'s slot.
  Future<void> unequipItem(AvatarItemType type) async {
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
    await _service.save(_userId, _equipped);
    _notify();
  }

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }
}
