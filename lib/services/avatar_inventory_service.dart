import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/avatar_inventory.dart';

/// Local persistence for the Avatar Economy: which [AvatarItem] ids a child
/// has purchased/unlocked (see [AvatarInventory]).
///
/// State is **per-child**: the key is namespaced by profile id
/// (`user_<id>_avatar_inventory`), matching `EquippedAvatarService` /
/// `ShopCustomizationService`. A signed-out guest falls back to a stable
/// `guest` prefix so their purchases survive until they create a profile.
///
/// Firebase-agnostic by design (CLAUDE.md §2.1) — an optional
/// [SharedPreferences] can be injected in tests. Cloud mirroring lives in
/// [ChildProfileSyncService]; this service stays the local source of truth.
class AvatarInventoryService {
  AvatarInventoryService({SharedPreferences? prefs}) : _injectedPrefs = prefs;

  final SharedPreferences? _injectedPrefs;
  SharedPreferences? _prefs;

  Future<SharedPreferences> get _sharedPrefs async =>
      _injectedPrefs ?? (_prefs ??= await SharedPreferences.getInstance());

  static const String _guestPrefix = 'guest';

  String _key(String? userId) =>
      'user_${(userId == null || userId.isEmpty) ? _guestPrefix : userId}'
      '_avatar_inventory';

  /// Loads the persisted inventory for [userId], or an empty one if nothing
  /// has been saved yet or the stored value can't be parsed.
  Future<AvatarInventory> load(String? userId) async {
    try {
      final prefs = await _sharedPrefs;
      final raw = prefs.getString(_key(userId));
      if (raw == null || raw.isEmpty) return AvatarInventory.empty();
      final decoded = jsonDecode(raw);
      if (decoded is! Map<String, dynamic>) return AvatarInventory.empty();
      return AvatarInventory.fromJson(decoded);
    } catch (e) {
      debugPrint('Error loading avatar inventory: $e');
      return AvatarInventory.empty();
    }
  }

  /// Persists [inventory] for [userId]. Best-effort: a write failure is
  /// logged and swallowed rather than thrown, matching the rest of the
  /// local persistence layer.
  Future<void> save(String? userId, AvatarInventory inventory) async {
    try {
      final prefs = await _sharedPrefs;
      await prefs.setString(_key(userId), jsonEncode(inventory.toJson()));
    } catch (e) {
      debugPrint('Error saving avatar inventory: $e');
    }
  }

  /// Applies unlocked ids pulled from the cloud onto the device store for
  /// [userId], **unioning** with whatever is already there so a locally-
  /// purchased item can never be dropped by a stale cloud copy.
  Future<void> applyMergedSnapshot(
    String? userId, {
    required Set<String> unlockedItemIds,
  }) async {
    final local = await load(userId);
    await save(
      userId,
      AvatarInventory(
        unlockedItemIds: {...local.unlockedItemIds, ...unlockedItemIds},
      ),
    );
  }
}
