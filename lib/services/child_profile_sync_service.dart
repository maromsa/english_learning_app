import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';

import '../models/child_profile.dart';
import '../models/daily_streak.dart';
import '../models/equipped_avatar.dart';
import 'avatar_inventory_service.dart';
import 'child_profile_service.dart';
import 'daily_streak_service.dart';
import 'shop_customization_service.dart';

/// Syncs child profiles between local storage and Firestore.
///
/// Cloud path: `users/{parentUid}/childProfiles/{profileId}`
class ChildProfileSyncService {
  ChildProfileSyncService({
    FirebaseFirestore? firestore,
    ChildProfileService? profileService,
    ShopCustomizationService? shopCustomizationService,
    DailyStreakService? dailyStreakService,
    AvatarInventoryService? avatarInventoryService,
  })  : _firestore = firestore ?? FirebaseFirestore.instance,
        _profileService = profileService ?? ChildProfileService(),
        _shopCustomizationService =
            shopCustomizationService ?? ShopCustomizationService(),
        _dailyStreakService = dailyStreakService ?? DailyStreakService(),
        _avatarInventoryService =
            avatarInventoryService ?? AvatarInventoryService();

  final FirebaseFirestore _firestore;
  final ChildProfileService _profileService;
  final ShopCustomizationService _shopCustomizationService;
  final DailyStreakService _dailyStreakService;
  final AvatarInventoryService _avatarInventoryService;

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
        if (profile.equippedAvatar != null &&
            profile.equippedAvatar!.toJson().isNotEmpty)
          'equippedAvatar': profile.equippedAvatar!.toJson(),
        'updatedAt': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      debugPrint('ChildProfileSyncService: leaderboard publish failed: $e');
    }
  }

  /// Pushes just the equipped-avatar slots for [profileId] to both the
  /// private profile document and the public leaderboard entry.
  ///
  /// Used by [EquippedAvatarProvider] on every equip/unequip (debounced) so
  /// the leaderboard reflects what a child is wearing without requiring a
  /// full profile sync. A merge write, so it never clobbers other fields —
  /// safe to call even if the leaderboard entry hasn't been published yet
  /// (in which case Firestore rules reject the create until the required
  /// fields exist, and this is a best-effort, non-fatal no-op like every
  /// other sync path in this service).
  Future<bool> updateEquippedAvatar(
    String parentUid,
    String profileId,
    EquippedAvatar equipped,
  ) async {
    try {
      final payload = <String, dynamic>{
        'equippedAvatar': equipped.toJson(),
        'updatedAt': FieldValue.serverTimestamp(),
      };
      await _profileDoc(parentUid, profileId)
          .set(payload, SetOptions(merge: true));
      await _leaderboardDoc(parentUid, profileId)
          .set(payload, SetOptions(merge: true));
      return true;
    } catch (e) {
      debugPrint('ChildProfileSyncService.updateEquippedAvatar failed: $e');
      return false;
    }
  }

  /// Pushes the practice [DailyStreak] for [profileId] onto the private
  /// profile document. A merge write, so it never clobbers coins, shop
  /// unlocks, or the integer login-claim `dailyStreak`. Not published to
  /// the leaderboard — that entry keeps a privacy-safe int streak.
  ///
  /// Used by [DailyStreakProvider] after a successful [recordPractice].
  /// Guests / local profiles have no parentUid and skip this path.
  Future<bool> updatePracticeStreak(
    String parentUid,
    String profileId,
    DailyStreak streak,
  ) async {
    try {
      await _profileDoc(parentUid, profileId).set(
        {
          // Practice streak is a map. The integer login-claim
          // `dailyStreak` is left untouched by this merge write so the
          // leaderboard / profile-switcher summary cannot be clobbered
          // by a practice day.
          'practiceStreak': streak.toJson(),
          'updatedAt': FieldValue.serverTimestamp(),
        },
        SetOptions(merge: true),
      );
      return true;
    } catch (e) {
      debugPrint('ChildProfileSyncService.updatePracticeStreak failed: $e');
      return false;
    }
  }

  /// Pushes the Avatar Economy unlock set for [profileId] onto the private
  /// profile document. A merge write using [FieldValue.arrayUnion] so a
  /// concurrent purchase on another device is never dropped. Not published
  /// to the leaderboard (privacy contract — inventory stays private).
  ///
  /// Used by [AvatarInventoryProvider] after a successful purchase.
  Future<bool> updateUnlockedItems(
    String parentUid,
    String profileId,
    Set<String> itemIds,
  ) async {
    try {
      final ids = itemIds.where((id) => id.isNotEmpty).toList();
      await _profileDoc(parentUid, profileId).set(
        {
          if (ids.isNotEmpty) 'unlockedItems': FieldValue.arrayUnion(ids),
          'updatedAt': FieldValue.serverTimestamp(),
        },
        SetOptions(merge: true),
      );
      return true;
    } catch (e) {
      debugPrint('ChildProfileSyncService.updateUnlockedItems failed: $e');
      return false;
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

        // Whichever side wins the profile-level pick, shop purchases,
        // practice streaks, and avatar inventory are merged field-by-field
        // so an unlock / practice day on the losing side is never lost
        // (CLAUDE.md §2.3: lists union, stats take the higher value).
        final base = keepLocal
            ? localProfile
            : cloudProfile.copyWith(pendingSync: false);
        merged[cloudProfile.id] = _mergeCloudFields(
          base: base,
          local: localProfile,
          cloud: cloudProfile,
        );
      }

      await _profileService.saveProfiles(merged.values.toList());
      // Reflect merged unlocks / streak back onto each profile's device
      // store so a cloud-only purchase or practice day is usable here.
      for (final profile in merged.values) {
        await _writeShopStateToDevice(profile);
        await _writePracticeStreakToDevice(profile);
        await _writeInventoryToDevice(profile);
      }
      await syncPendingToCloud(parentUid);
    } catch (e, stackTrace) {
      debugPrint('ChildProfileSyncService.syncFromCloud failed: $e');
      debugPrint('$stackTrace');
    }
  }

  /// Returns [base] with shop, practice-streak, and inventory fields replaced
  /// by a loss-proof merge of [local] and [cloud]: unlocked lists are
  /// unioned; equipped ids come from whichever profile has the newer
  /// `updatedAt`; practice streaks take the higher count (claimed
  /// milestones union).
  ChildProfile _mergeCloudFields({
    required ChildProfile base,
    required ChildProfile local,
    required ChildProfile cloud,
  }) {
    final themes = <String>{...local.unlockedThemes, ...cloud.unlockedThemes};
    final sounds = <String>{...local.unlockedSounds, ...cloud.unlockedSounds};
    final items = <String>{...local.unlockedItems, ...cloud.unlockedItems};
    final practice =
        DailyStreak.merge(local.practiceStreak, cloud.practiceStreak);

    final localUpdated = local.updatedAt ?? local.createdAt;
    final cloudUpdated = cloud.updatedAt ?? cloud.createdAt;
    final cloudIsNewer = localUpdated == null ||
        (cloudUpdated != null && cloudUpdated.isAfter(localUpdated));
    final preferred = cloudIsNewer ? cloud : local;
    final other = cloudIsNewer ? local : cloud;

    // If the union grew past what `base` carried, the winning side is missing
    // an unlock / milestone the other side had — mark it dirty so the merged
    // set is re-uploaded and the cloud converges on the next push.
    final grewBeyondBase = themes.length > base.unlockedThemes.length ||
        sounds.length > base.unlockedSounds.length ||
        items.length > base.unlockedItems.length ||
        practice.claimedMilestones.length >
            base.practiceStreak.claimedMilestones.length ||
        practice.currentStreak > base.practiceStreak.currentStreak;

    return base.copyWith(
      unlockedThemes: themes.toList(),
      unlockedSounds: sounds.toList(),
      unlockedItems: items.toList(),
      practiceStreak: practice,
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

  Future<void> _writePracticeStreakToDevice(ChildProfile profile) async {
    if (profile.practiceStreak == const DailyStreak()) return;
    try {
      await _dailyStreakService.applyMergedSnapshot(
        profile.id,
        profile.practiceStreak,
      );
    } catch (e) {
      debugPrint(
        'ChildProfileSyncService: practice streak write-back failed: $e',
      );
    }
  }

  Future<void> _writeInventoryToDevice(ChildProfile profile) async {
    if (profile.unlockedItems.isEmpty) return;
    try {
      await _avatarInventoryService.applyMergedSnapshot(
        profile.id,
        unlockedItemIds: profile.unlockedItems.toSet(),
      );
    } catch (e) {
      debugPrint(
        'ChildProfileSyncService: avatar inventory write-back failed: $e',
      );
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
