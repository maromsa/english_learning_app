import 'package:flutter/foundation.dart';

import '../data/avatar_catalog.dart';
import '../models/avatar_inventory.dart';
import '../models/avatar_item.dart';
import '../providers/coin_provider.dart';
import '../services/avatar_inventory_service.dart';

/// Reactive owner of the Avatar Economy: which [AvatarItem]s a child has
/// purchased/unlocked from [AvatarCatalog].
///
/// Coins are never mutated here — [purchaseItem] delegates the debit to
/// [CoinProvider], the single source of truth for the balance (matching
/// `ShopCustomizationProvider.buy`). Persistence is per-child and
/// local-only (see [AvatarInventoryService]); cloud mirroring is a
/// follow-up, matching the sibling customization providers' v1.
class AvatarInventoryProvider with ChangeNotifier {
  AvatarInventoryProvider({
    AvatarInventory? initial,
    AvatarInventoryService? service,
  })  : _inventory = initial ?? AvatarInventory.empty(),
        _service = service ?? AvatarInventoryService();

  final AvatarInventoryService _service;
  AvatarInventory _inventory;
  String? _userId;
  bool _disposed = false;

  AvatarInventory get inventory => _inventory;

  /// Every unlocked id, including the always-free starter items.
  Set<String> get unlockedItemIds => {
        ...AvatarCatalog.freeStarterItemIds,
        ..._inventory.unlockedItemIds,
      };

  void _notify() {
    if (!_disposed) notifyListeners();
  }

  /// Points persistence at [userId]'s namespace (guest when null).
  void setUserId(String? userId) {
    _userId = userId;
  }

  /// Whether [item] is already owned (free starter items always count).
  bool isOwned(AvatarItem item) => unlockedItemIds.contains(item.id);

  /// Loads the persisted inventory for the current profile. Best-effort: a
  /// read failure leaves the previous (or empty) state in place.
  Future<void> load() async {
    try {
      _inventory = await _service.load(_userId);
      _notify();
    } catch (e) {
      debugPrint('Error loading avatar inventory: $e');
    }
  }

  /// Buys [item] with coins from [economy].
  ///
  /// Returns `true` if the child now owns the item (already-owned is a
  /// no-op success), `false` if they can't afford it or the debit failed.
  /// On success, [item]'s cost is deducted, its id is added to the unlocked
  /// set, and the new inventory is persisted.
  Future<bool> purchaseItem(AvatarItem item, CoinProvider economy) async {
    if (isOwned(item)) return true;
    if (economy.coins < item.cost) return false;

    final paid = await economy.spendCoins(item.cost);
    if (!paid) return false;

    _inventory = _inventory.copyWith(
      unlockedItemIds: {..._inventory.unlockedItemIds, item.id},
    );
    await _service.save(_userId, _inventory);
    _notify();
    return true;
  }

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }
}
