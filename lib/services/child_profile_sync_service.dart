import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';

import '../models/child_profile.dart';
import 'child_profile_service.dart';

/// Syncs child profiles between local storage and Firestore.
///
/// Cloud path: `users/{parentUid}/childProfiles/{profileId}`
class ChildProfileSyncService {
  ChildProfileSyncService({
    FirebaseFirestore? firestore,
    ChildProfileService? profileService,
  })  : _firestore = firestore ?? FirebaseFirestore.instance,
        _profileService = profileService ?? ChildProfileService();

  final FirebaseFirestore _firestore;
  final ChildProfileService _profileService;

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

        if (localProfile.pendingSync &&
            localUpdated != null &&
            (cloudUpdated == null || !localUpdated.isBefore(cloudUpdated))) {
          continue;
        }

        merged[cloudProfile.id] = cloudProfile.copyWith(pendingSync: false);
      }

      await _profileService.saveProfiles(merged.values.toList());
      await syncPendingToCloud(parentUid);
    } catch (e, stackTrace) {
      debugPrint('ChildProfileSyncService.syncFromCloud failed: $e');
      debugPrint('$stackTrace');
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
      String parentUid, ChildProfile profile) async {
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
      return true;
    } catch (e) {
      debugPrint('ChildProfileSyncService.syncProfileToCloud failed: $e');
      return false;
    }
  }

  Future<bool> deleteFromCloud(String parentUid, String profileId) async {
    try {
      await _profileDoc(parentUid, profileId).delete();
      return true;
    } catch (e) {
      debugPrint('ChildProfileSyncService.deleteFromCloud failed: $e');
      return false;
    }
  }
}
