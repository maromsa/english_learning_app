import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';

import '../models/child_profile.dart';
import 'child_profile_service.dart';
import 'shop_customization_service.dart';

/// Syncs child profiles between local storage and Firestore.
///
/// Cloud path: `users/{parentUid}/childProfiles/{profileId}`
class ChildProfileSyncService {
  ChildProfileSyncService({
    FirebaseFirestore? firestore,
    ChildProfileService? profileService,
    ShopCustomizationService? shopCustomizationService,
  })  : _firestore = firestore ?? FirebaseFirestore.instance,
        _profileService = profileService ?? ChildProfileService(),
        _shopCustomizationService =
            shopCustomizationService ?? ShopCustomizationService();

  final FirebaseFirestore _firestore;
  final ChildProfileService _profileService;
  final ShopCustomizationService _shopCustomizationService;

  CollectionReference<Map<String, dynamic>> _profilesCollection(
    String parentUid,
  ) {
    return _firestore
        .collection('users')
        .doc(parentUid)
        .collection('childProfiles');
  }

  DocumentReference<Map<String, dynamic>> _profileDoc(
    String parentUid,
    String profileId,
  ) {
    return _profilesCollection(parentUid).doc(profileId);
  }

  DocumentReference<Map<String, dynamic>> _leaderboardDoc(
    String parentUid,
    String profileId,
  ) {
    return _firestore.collection('leaderboard').doc('${parentUid}_$profileId');
  }

  /// Publishes a minimal, privacy-safe leaderboard entry.
  ///
  /// Only display name, coins, streak, avatar color and the (non-identifying)
  /// animal-emoji avatar choice are shared — never photos or any other profile
  /// data. Failures are non-fatal: the profile sync itself already succeeded.
  Future<void> _publishLeaderboardEntry(
    String parentUid,
    ChildProfile profile,
  ) async {
    try {
      await _leaderboardDoc(parentUid, profile.id).set({
        'profileId': profile.id,
        'displayName': profile.displayName,
        'coins': profile.coins,
        'dailyStreak': profile.dailyStreak,
        'avatarColor': profile.avatarColor,
        if (profile.avatarId != null && profile.avatarId!.isNotEmpty)
          'avatarId': profile.avatarId,
        'updatedAt': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      debugPrint('ChildProfileSyncService: leaderboard publish failed: $e');
    }
  }

  /// Pull cloud profiles and merge into local storage (newer updatedAt wins).
  Future<void> syncFromCloud(String parentUid) async {
    try {
      final snapshot = await _profilesCollection(parentUid).get();
      if (snapshot.docs.isEmpty) {
        await syncPendingToCloud(parentUid);
        return;
      }

      final localProfiles = await _profileService.getAllProfiles();
      final merged = <String, ChildProfile>{
        for (final profile in localProfiles) profile.id: profile,
      };

      for (final doc in snapshot.docs) {
        final data = doc.data();
        data['id'] = doc.id;
        final cloudProfile = ChildProfile.fromMap(data);
        final localProfile = merged[cloudProfile.id];

        if (localProfile == null) {
          merged[cloudProfile.id] = cloudProfile.copyWith(pendingSync: false);
          continue;
        }

        final localUpdated = localProfile.updatedAt ?? localProfile.createdAt;
        final cloudUpdated = cloudProfile.updatedAt ?? cloudProfile.createdAt;

        final keepLocal = localProfile.pendingSync &&
            localUpdated != null &&
            (cloudUpdated == null || !localUpdated.isBefore(cloudUpdated));

        // Whichever side wins the profile-level pick, shop purchases are
        // merged field-by-field so an unlock on the losing side is never lost
        // (CLAUDE.md §2.3: lists union, equipped scalars follow newer updatedAt).
        final base = keepLocal
            ? localProfile
            : cloudProfile.copyWith(pendingSync: false);
        merged[cloudProfile.id] = _mergeShopFields(
          base: base,
          local: localProfile,
          cloud: cloudProfile,
        );
      }

      await _profileService.saveProfiles(merged.values.toList());
      // Reflect merged unlocks back onto each profile's device store so a
      // cloud-only purchase is usable on this device immediately.
      for (final profile in merged.values) {
        await _writeShopStateToDevice(profile);
      }
      await syncPendingToCloud(parentUid);
    } catch (e, stackTrace) {
      debugPrint('ChildProfileSyncService.syncFromCloud failed: $e');
      debugPrint('$stackTrace');
    }
  }

  /// Returns [base] with shop fields replaced by a loss-proof merge of [local]
  /// and [cloud]: unlocked lists are unioned; equipped ids come from whichever
  /// profile has the newer `updatedAt` (falling back to any non-null value).
  ChildProfile _mergeShopFields({
    required ChildProfile base,
    required ChildProfile local,
    required ChildProfile cloud,
  }) {
    final themes = <String>{...local.unlockedThemes, ...cloud.unlockedThemes};
    final sounds = <String>{...local.unlockedSounds, ...cloud.unlockedSounds};

    final localUpdated = local.updatedAt ?? local.createdAt;
    final cloudUpdated = cloud.updatedAt ?? cloud.createdAt;
    final cloudIsNewer = localUpdated == null ||
        (cloudUpdated != null && cloudUpdated.isAfter(localUpdated));
    final preferred = cloudIsNewer ? cloud : local;
    final other = cloudIsNewer ? local : cloud;

    // If the union grew past what `base` carried, the winning side is missing
    // an unlock the other side had — mark it dirty so the merged set is
    // re-uploaded and the cloud converges on the next push.
    final grewBeyondBase = themes.length > base.unlockedThemes.length ||
        sounds.length > base.unlockedSounds.length;

    return base.copyWith(
      unlockedThemes: themes.toList(),
      unlockedSounds: sounds.toList(),
      equippedTheme: preferred.equippedTheme ?? other.equippedTheme,
      equippedSound: preferred.equippedSound ?? other.equippedSound,
      pendingSync: grewBeyondBase ? true : base.pendingSync,
    );
  }

  /// Persists a profile's (merged) shop state into its per-child device store
  /// so `ShopCustomizationProvider` picks it up on its next load.
  Future<void> _writeShopStateToDevice(ChildProfile profile) async {
    if (profile.unlockedThemes.isEmpty &&
        profile.unlockedSounds.isEmpty &&
        profile.equippedTheme == null &&
        profile.equippedSound == null) {
      return;
    }
    try {
      await _shopCustomizationService.applyMergedSnapshot(
        profile.id,
        unlockedThemeIds: profile.unlockedThemes.toSet(),
        unlockedSoundIds: profile.unlockedSounds.toSet(),
        equippedThemeId: profile.equippedTheme,
        equippedSoundId: profile.equippedSound,
      );
    } catch (e) {
      debugPrint('ChildProfileSyncService: shop state write-back failed: $e');
    }
  }

  /// Push profiles marked [ChildProfile.pendingSync] to Firestore.
  Future<void> syncPendingToCloud(String parentUid) async {
    final pending = await _profileService.profilesPendingSync();
    for (final profile in pending) {
      await syncProfileToCloud(parentUid, profile);
    }
  }

  Future<bool> syncProfileToCloud(
    String parentUid,
    ChildProfile profile,
  ) async {
    try {
      final payload = profile.toMap(forCloud: true);
      payload.remove('pendingSync');
      payload['updatedAt'] = FieldValue.serverTimestamp();
      if (profile.createdAt == null) {
        payload['createdAt'] = FieldValue.serverTimestamp();
      }

      await _profileDoc(parentUid, profile.id)
          .set(payload, SetOptions(merge: true));
      await _profileService.markSynced(profile.id);
      await _publishLeaderboardEntry(parentUid, profile);
      return true;
    } catch (e) {
      debugPrint('ChildProfileSyncService.syncProfileToCloud failed: $e');
      return false;
    }
  }

  Future<bool> deleteFromCloud(String parentUid, String profileId) async {
    try {
      await _profileDoc(parentUid, profileId).delete();
      try {
        await _leaderboardDoc(parentUid, profileId).delete();
      } catch (e) {
        debugPrint('ChildProfileSyncService: leaderboard delete failed: $e');
      }
      return true;
    } catch (e) {
      debugPrint('ChildProfileSyncService.deleteFromCloud failed: $e');
      return false;
    }
  }
}
