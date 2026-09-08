import 'package:flutter/foundation.dart';

import '../models/customization_item.dart';
import '../services/shop_customization_service.dart';
import '../services/sound_service.dart';
import 'coin_provider.dart';

/// Reactive owner of Magic Shop cosmetic customization: which map themes and
/// victory sounds a child has unlocked, and which one of each is equipped.
///
/// Coins are never mutated here — [buy] delegates the debit to [CoinProvider],
/// the single source of truth for the balance. Persistence is per-child and
/// local-only (see [ShopCustomizationService]); cloud mirroring is a follow-up.
class ShopCustomizationProvider with ChangeNotifier {
  ShopCustomizationProvider({
    ShopCustomizationService? service,
    SoundService? soundService,
  })  : _service = service ?? ShopCustomizationService(),
        _soundService = soundService ?? SoundService();

  final ShopCustomizationService _service;
  final SoundService _soundService;

  String? _userId;
  bool _disposed = false;

  final Set<String> _unlockedThemeIds = {CustomizationItem.defaultThemeId};
  final Set<String> _unlockedSoundIds = {CustomizationItem.defaultSoundId};
  String _equippedThemeId = CustomizationItem.defaultThemeId;
  String _equippedSoundId = CustomizationItem.defaultSoundId;

  void _notify() {
    if (!_disposed) notifyListeners();
  }

  String get equippedThemeId => _equippedThemeId;
  String get equippedSoundId => _equippedSoundId;

  /// Palette the MapScreen sky should paint with right now.
  MapThemePalette get equippedMapPalette =>
      CustomizationItem.byId(_equippedThemeId)?.palette ??
      CustomizationItem.defaultPalette;

  bool isOwned(CustomizationItem item) {
    if (item.isDefault) return true;
    return item.kind == CustomizationKind.theme
        ? _unlockedThemeIds.contains(item.id)
        : _unlockedSoundIds.contains(item.id);
  }

  bool isEquipped(CustomizationItem item) =>
      item.kind == CustomizationKind.theme
          ? _equippedThemeId == item.id
          : _equippedSoundId == item.id;

  /// Points persistence at [userId]'s namespace. [isLocalUser] is accepted for
  /// call-site symmetry with [CoinProvider.setUserId]; local and Firebase
  /// children are keyed identically here (local-only v1).
  void setUserId(String? userId, {bool isLocalUser = false}) {
    _userId = userId;
  }

  /// Loads unlocked + equipped state for the current profile. Best-effort: a
  /// read failure leaves the safe defaults in place.
  Future<void> load() async {
    try {
      final themes = await _service.getUnlockedThemeIds(_userId);
      final sounds = await _service.getUnlockedSoundIds(_userId);
      _unlockedThemeIds
        ..clear()
        ..add(CustomizationItem.defaultThemeId)
        ..addAll(themes);
      _unlockedSoundIds
        ..clear()
        ..add(CustomizationItem.defaultSoundId)
        ..addAll(sounds);

      final themeId = await _service.getEquippedThemeId(_userId);
      final soundId = await _service.getEquippedSoundId(_userId);
      // Guard against a stale equipped id (e.g. catalog changed) — fall back
      // to the default rather than render nothing.
      _equippedThemeId = _unlockedThemeIds.contains(themeId)
          ? themeId
          : CustomizationItem.defaultThemeId;
      _equippedSoundId = _unlockedSoundIds.contains(soundId)
          ? soundId
          : CustomizationItem.defaultSoundId;
      _applyEquippedSound();
      _notify();
    } catch (e) {
      debugPrint('Error loading shop customization: $e');
    }
  }

  /// Buys [item] with coins from [coinProvider] and auto-equips it.
  ///
  /// Returns `true` if the child now owns the item (already-owned is a no-op
  /// success), `false` if they can't afford it or the debit failed.
  Future<bool> buy(CustomizationItem item, CoinProvider coinProvider) async {
    if (isOwned(item)) return true;
    if (coinProvider.coins < item.cost) return false;

    final paid = await coinProvider.spendCoins(item.cost);
    if (!paid) return false;

    if (item.kind == CustomizationKind.theme) {
      _unlockedThemeIds.add(item.id);
      await _service.saveUnlockedThemeIds(_userId, _unlockedThemeIds);
    } else {
      _unlockedSoundIds.add(item.id);
      await _service.saveUnlockedSoundIds(_userId, _unlockedSoundIds);
    }
    await _equip(item);
    return true;
  }

  /// Equips an already-owned [item]. Returns `false` if it isn't owned.
  Future<bool> equip(CustomizationItem item) async {
    if (!isOwned(item)) return false;
    await _equip(item);
    return true;
  }

  Future<void> _equip(CustomizationItem item) async {
    if (item.kind == CustomizationKind.theme) {
      _equippedThemeId = item.id;
      await _service.saveEquippedThemeId(_userId, item.id);
    } else {
      _equippedSoundId = item.id;
      await _service.saveEquippedSoundId(_userId, item.id);
      _applyEquippedSound();
    }
    _notify();
  }

  /// Pushes the equipped victory sound into [SoundService] so the next
  /// level-complete fanfare uses it. Default sound clears the override.
  void _applyEquippedSound() {
    final sound = CustomizationItem.byId(_equippedSoundId);
    _soundService.victorySoundAsset =
        (sound == null || sound.id == CustomizationItem.defaultSoundId)
            ? null
            : sound.soundAsset;
  }

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }
}
