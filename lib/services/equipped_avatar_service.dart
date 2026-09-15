import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/equipped_avatar.dart';

/// Local persistence for Avatar Customization (which [AvatarItem] is
/// equipped in each slot).
///
/// State is **per-child**: the key is namespaced by profile id
/// (`user_<id>_equipped_avatar`), matching `ShopCustomizationService` /
/// `StickerAlbumService`. A signed-out guest falls back to a stable
/// `guest_` prefix so their picks survive until they create a profile.
///
/// Firebase-agnostic by design (CLAUDE.md §2.1) — an optional
/// [SharedPreferences] can be injected in tests. Cloud mirroring is a
/// follow-up, matching `StickerAlbumService`'s local-only v1.
class EquippedAvatarService {
  EquippedAvatarService({SharedPreferences? prefs}) : _injectedPrefs = prefs;

  final SharedPreferences? _injectedPrefs;
  SharedPreferences? _prefs;

  Future<SharedPreferences> get _sharedPrefs async =>
      _injectedPrefs ?? (_prefs ??= await SharedPreferences.getInstance());

  static const String _guestPrefix = 'guest';

  String _key(String? userId) =>
      'user_${(userId == null || userId.isEmpty) ? _guestPrefix : userId}'
      '_equipped_avatar';

  /// Loads the persisted equipped avatar for [userId], or an empty one if
  /// nothing has been saved yet or the stored value can't be parsed.
  Future<EquippedAvatar> load(String? userId) async {
    try {
      final prefs = await _sharedPrefs;
      final raw = prefs.getString(_key(userId));
      if (raw == null || raw.isEmpty) return EquippedAvatar.empty();
      final decoded = jsonDecode(raw);
      if (decoded is! Map<String, dynamic>) return EquippedAvatar.empty();
      return EquippedAvatar.fromJson(decoded);
    } catch (e) {
      debugPrint('Error loading equipped avatar: $e');
      return EquippedAvatar.empty();
    }
  }

  /// Persists [equipped] for [userId]. Best-effort: a write failure is
  /// logged and swallowed rather than thrown, matching the rest of the
  /// local persistence layer.
  Future<void> save(String? userId, EquippedAvatar equipped) async {
    try {
      final prefs = await _sharedPrefs;
      await prefs.setString(_key(userId), jsonEncode(equipped.toJson()));
    } catch (e) {
      debugPrint('Error saving equipped avatar: $e');
    }
  }
}
