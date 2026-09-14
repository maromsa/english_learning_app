import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/sticker_album.dart';

/// Local persistence for the Digital Sticker Album (owned stickers + canvas
/// placements).
///
/// State is **per-child**: the key is namespaced by profile id
/// (`user_<id>_sticker_album`), matching `ShopCustomizationService` /
/// `LocalUserDataService`. A signed-out guest falls back to a stable
/// `guest_` prefix so their picks survive until they create a profile.
///
/// Firebase-agnostic by design (CLAUDE.md §2.1) — an optional
/// [SharedPreferences] can be injected in tests. Cloud mirroring is a
/// follow-up, matching `ShopCustomizationService`'s local-only v1.
class StickerAlbumService {
  StickerAlbumService({SharedPreferences? prefs}) : _injectedPrefs = prefs;

  final SharedPreferences? _injectedPrefs;
  SharedPreferences? _prefs;

  Future<SharedPreferences> get _sharedPrefs async =>
      _injectedPrefs ?? (_prefs ??= await SharedPreferences.getInstance());

  static const String _guestPrefix = 'guest';

  String _key(String? userId) =>
      'user_${(userId == null || userId.isEmpty) ? _guestPrefix : userId}'
      '_sticker_album';

  /// Loads the persisted album for [userId], or an empty album if nothing
  /// has been saved yet or the stored value can't be parsed.
  Future<StickerAlbum> load(String? userId) async {
    try {
      final prefs = await _sharedPrefs;
      final raw = prefs.getString(_key(userId));
      if (raw == null || raw.isEmpty) return StickerAlbum.empty();
      final decoded = jsonDecode(raw);
      if (decoded is! Map<String, dynamic>) return StickerAlbum.empty();
      return StickerAlbum.fromJson(decoded);
    } catch (e) {
      debugPrint('Error loading sticker album: $e');
      return StickerAlbum.empty();
    }
  }

  /// Persists [album] for [userId]. Best-effort: a write failure is logged
  /// and swallowed rather than thrown, matching the rest of the local
  /// persistence layer.
  Future<void> save(String? userId, StickerAlbum album) async {
    try {
      final prefs = await _sharedPrefs;
      await prefs.setString(_key(userId), jsonEncode(album.toJson()));
    } catch (e) {
      debugPrint('Error saving sticker album: $e');
    }
  }
}
