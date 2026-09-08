import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/customization_item.dart';

/// Local persistence for Magic Shop cosmetic customization (map themes and
/// victory sounds).
///
/// State is **per-child**: every key is namespaced by profile id
/// (`user_<id>_...`), matching `CoinProvider` / `LocalUserDataService`. A
/// signed-out guest falls back to a stable `guest_` prefix so their picks
/// survive until they create a profile.
///
/// Firebase-agnostic by design (CLAUDE.md §2.1) — an optional [SharedPreferences]
/// can be injected in tests.
class ShopCustomizationService {
  ShopCustomizationService({SharedPreferences? prefs}) : _injectedPrefs = prefs;

  final SharedPreferences? _injectedPrefs;
  SharedPreferences? _prefs;

  Future<SharedPreferences> get _sharedPrefs async =>
      _injectedPrefs ?? (_prefs ??= await SharedPreferences.getInstance());

  static const String _guestPrefix = 'guest';

  String _prefix(String? userId) =>
      'user_${(userId == null || userId.isEmpty) ? _guestPrefix : userId}';

  String _unlockedThemesKey(String? userId) =>
      '${_prefix(userId)}_unlocked_themes';
  String _unlockedSoundsKey(String? userId) =>
      '${_prefix(userId)}_unlocked_sounds';
  String _equippedThemeKey(String? userId) =>
      '${_prefix(userId)}_equipped_theme';
  String _equippedSoundKey(String? userId) =>
      '${_prefix(userId)}_equipped_sound';

  List<String> _decodeList(String? raw) {
    if (raw == null || raw.isEmpty) return const [];
    return raw.split(',').where((e) => e.isNotEmpty).toList();
  }

  /// Ids of themes the child has bought. The free default is implicit — it is
  /// never written here — so callers should union with
  /// [CustomizationItem.defaultThemeId].
  Future<Set<String>> getUnlockedThemeIds(String? userId) async {
    try {
      final prefs = await _sharedPrefs;
      return _decodeList(prefs.getString(_unlockedThemesKey(userId))).toSet();
    } catch (e) {
      debugPrint('Error loading unlocked themes: $e');
      return <String>{};
    }
  }

  Future<Set<String>> getUnlockedSoundIds(String? userId) async {
    try {
      final prefs = await _sharedPrefs;
      return _decodeList(prefs.getString(_unlockedSoundsKey(userId))).toSet();
    } catch (e) {
      debugPrint('Error loading unlocked sounds: $e');
      return <String>{};
    }
  }

  Future<void> saveUnlockedThemeIds(String? userId, Set<String> ids) async {
    try {
      final prefs = await _sharedPrefs;
      await prefs.setString(_unlockedThemesKey(userId), ids.join(','));
    } catch (e) {
      debugPrint('Error saving unlocked themes: $e');
    }
  }

  Future<void> saveUnlockedSoundIds(String? userId, Set<String> ids) async {
    try {
      final prefs = await _sharedPrefs;
      await prefs.setString(_unlockedSoundsKey(userId), ids.join(','));
    } catch (e) {
      debugPrint('Error saving unlocked sounds: $e');
    }
  }

  /// Equipped theme id, or [CustomizationItem.defaultThemeId] when unset.
  Future<String> getEquippedThemeId(String? userId) async {
    try {
      final prefs = await _sharedPrefs;
      return prefs.getString(_equippedThemeKey(userId)) ??
          CustomizationItem.defaultThemeId;
    } catch (e) {
      debugPrint('Error loading equipped theme: $e');
      return CustomizationItem.defaultThemeId;
    }
  }

  Future<String> getEquippedSoundId(String? userId) async {
    try {
      final prefs = await _sharedPrefs;
      return prefs.getString(_equippedSoundKey(userId)) ??
          CustomizationItem.defaultSoundId;
    } catch (e) {
      debugPrint('Error loading equipped sound: $e');
      return CustomizationItem.defaultSoundId;
    }
  }

  Future<void> saveEquippedThemeId(String? userId, String id) async {
    try {
      final prefs = await _sharedPrefs;
      await prefs.setString(_equippedThemeKey(userId), id);
    } catch (e) {
      debugPrint('Error saving equipped theme: $e');
    }
  }

  Future<void> saveEquippedSoundId(String? userId, String id) async {
    try {
      final prefs = await _sharedPrefs;
      await prefs.setString(_equippedSoundKey(userId), id);
    } catch (e) {
      debugPrint('Error saving equipped sound: $e');
    }
  }

  // ── Cloud-sync bridge ──────────────────────────────────────────────────────

  /// The full customization state for [userId] in one read — used by
  /// `ChildProfileSyncService` to build the cloud snapshot.
  Future<ShopCustomizationSnapshot> readSnapshot(String? userId) async {
    return ShopCustomizationSnapshot(
      unlockedThemeIds: await getUnlockedThemeIds(userId),
      unlockedSoundIds: await getUnlockedSoundIds(userId),
      equippedThemeId: await getEquippedThemeId(userId),
      equippedSoundId: await getEquippedSoundId(userId),
    );
  }

  /// Applies a snapshot pulled from the cloud onto the device store for
  /// [userId], **unioning** unlocked ids with whatever is already there so a
  /// locally-purchased item can never be dropped by a stale cloud copy.
  /// Equipped ids are overwritten only when non-null and non-empty.
  Future<void> applyMergedSnapshot(
    String? userId, {
    Set<String> unlockedThemeIds = const {},
    Set<String> unlockedSoundIds = const {},
    String? equippedThemeId,
    String? equippedSoundId,
  }) async {
    final themes = {...await getUnlockedThemeIds(userId), ...unlockedThemeIds};
    final sounds = {...await getUnlockedSoundIds(userId), ...unlockedSoundIds};
    await saveUnlockedThemeIds(userId, themes);
    await saveUnlockedSoundIds(userId, sounds);
    if (equippedThemeId != null && equippedThemeId.isNotEmpty) {
      await saveEquippedThemeId(userId, equippedThemeId);
    }
    if (equippedSoundId != null && equippedSoundId.isNotEmpty) {
      await saveEquippedSoundId(userId, equippedSoundId);
    }
  }
}

/// Immutable view of a child's shop customization state for cloud sync.
class ShopCustomizationSnapshot {
  const ShopCustomizationSnapshot({
    required this.unlockedThemeIds,
    required this.unlockedSoundIds,
    required this.equippedThemeId,
    required this.equippedSoundId,
  });

  final Set<String> unlockedThemeIds;
  final Set<String> unlockedSoundIds;
  final String equippedThemeId;
  final String equippedSoundId;
}
