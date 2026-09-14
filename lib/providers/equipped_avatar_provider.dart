import 'dart:async';

import 'package:flutter/foundation.dart';

import '../models/avatar_item.dart';
import '../models/equipped_avatar.dart';
import '../services/child_profile_sync_service.dart';
import '../services/equipped_avatar_service.dart';

/// How long to wait after the last equip/unequip before pushing the new
/// [EquippedAvatar] to Firestore. Collapses rapid taps (e.g. a child trying
/// on several hats in a row) into a single cloud write instead of spamming
/// the database — see [_scheduleCloudSync].
const Duration _defaultCloudSyncDebounce = Duration(milliseconds: 500);

/// Reactive owner of Avatar Customization: which [AvatarItem] is equipped in
/// each slot.
///
/// This follows the same `ChangeNotifier` shape as [ShopCustomizationProvider]
/// / [StickerAlbumProvider] (see CLAUDE.md §2.1 — state lives in
/// `ChangeNotifier` providers wired through `main.dart`'s `MultiProvider`;
/// this app does not use Riverpod). Persistence is per-child and local-first
/// (see [EquippedAvatarService]) — local storage is always the source of
/// truth and is written synchronously with every equip/unequip.
///
/// On top of that, when the active profile belongs to a signed-in parent
/// account (see [setParentUid]), every equip/unequip also schedules a
/// debounced push to [ChildProfileSyncService] so the leaderboard can show
/// what a child is wearing. Guests and local (non-cloud) profiles have no
/// [parentUid], so they simply skip the cloud step — matching
/// [CoinProvider]'s `isLocalUser` gate.
class EquippedAvatarProvider with ChangeNotifier {
  EquippedAvatarProvider({
    EquippedAvatar? initial,
    EquippedAvatarService? service,
    ChildProfileSyncService? syncService,
    Duration cloudSyncDebounce = _defaultCloudSyncDebounce,
  })  : _equipped = initial ?? EquippedAvatar.empty(),
        _service = service ?? EquippedAvatarService(),
        _syncService = syncService ?? ChildProfileSyncService(),
        _cloudSyncDebounce = cloudSyncDebounce;

  final EquippedAvatarService _service;
  final ChildProfileSyncService _syncService;
  final Duration _cloudSyncDebounce;
  EquippedAvatar _equipped;
  String? _userId;
  String? _parentUid;
  Timer? _cloudSyncTimer;
  bool _disposed = false;

  EquippedAvatar get equipped => _equipped;

  void _notify() {
    if (!_disposed) notifyListeners();
  }

  /// Points local persistence at [userId]'s namespace (guest when null).
  void setUserId(String? userId) {
    _userId = userId;
  }

  /// Points cloud sync at the signed-in parent's Firestore account, or
  /// `null` for guests / local (non-cloud) profiles — which then stay
  /// local-only, matching `CoinProvider`'s `isLocalUser` gate. Should be set
  /// alongside [setUserId] whenever the active profile changes.
  void setParentUid(String? parentUid) {
    _parentUid = parentUid;
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
    _scheduleCloudSync();
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
    _scheduleCloudSync();
  }

  /// Restarts the debounce timer so a burst of equip/unequip calls collapses
  /// into a single Firestore write, fired [_cloudSyncDebounce] after the
  /// last change. No-op for guests / local profiles (no [_parentUid]).
  void _scheduleCloudSync() {
    if (_parentUid == null || _userId == null || _userId!.isEmpty) return;
    _cloudSyncTimer?.cancel();
    _cloudSyncTimer = Timer(_cloudSyncDebounce, () {
      unawaited(_pushToCloud());
    });
  }

  /// Publishes the current [_equipped] state to Firestore (private profile
  /// doc + public leaderboard entry) via [ChildProfileSyncService]. Failures
  /// are non-fatal: local persistence already succeeded, and this is a
  /// best-effort mirror like every other cloud sync path in the app.
  Future<void> _pushToCloud() async {
    final parentUid = _parentUid;
    final userId = _userId;
    if (parentUid == null || userId == null || userId.isEmpty) return;
    try {
      await _syncService.updateEquippedAvatar(parentUid, userId, _equipped);
    } catch (e) {
      debugPrint('Error syncing equipped avatar to the cloud: $e');
    }
  }

  /// Test-only escape hatch: cancels the pending debounce timer (if any) and
  /// pushes immediately, so tests don't have to wait out the real debounce
  /// window.
  @visibleForTesting
  Future<void> flushCloudSync() async {
    _cloudSyncTimer?.cancel();
    _cloudSyncTimer = null;
    await _pushToCloud();
  }

  @override
  void dispose() {
    _disposed = true;
    _cloudSyncTimer?.cancel();
    super.dispose();
  }
}
