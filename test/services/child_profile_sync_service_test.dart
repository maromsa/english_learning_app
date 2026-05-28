import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:english_learning_app/models/child_profile.dart';
import 'package:english_learning_app/services/child_profile_service.dart';
import 'package:english_learning_app/services/child_profile_sync_service.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('ChildProfileSyncService', () {
    late FakeFirebaseFirestore firestore;
    late SharedPreferences prefs;
    late ChildProfileService profileService;
    late ChildProfileSyncService syncService;

    setUp(() async {
      SharedPreferences.setMockInitialValues({});
      prefs = await SharedPreferences.getInstance();
      firestore = FakeFirebaseFirestore();
      profileService = ChildProfileService(prefs: prefs);
      syncService = ChildProfileSyncService(
        firestore: firestore,
        profileService: profileService,
      );
    });

    test('syncProfileToCloud writes profile document', () async {
      const parentUid = 'parent123';
      final profile = await profileService.createProfile(
        displayName: 'Noa',
        avatarColor: ChildProfile.defaultAvatarColors.first,
      );

      final ok = await syncService.syncProfileToCloud(parentUid, profile);
      expect(ok, true);

      final doc = await firestore
          .collection('users')
          .doc(parentUid)
          .collection('childProfiles')
          .doc(profile.id)
          .get();
      expect(doc.exists, true);
      expect(doc.data()?['displayName'], 'Noa');
    });

    test('syncFromCloud merges remote profiles into local storage', () async {
      const parentUid = 'parent456';
      await firestore
          .collection('users')
          .doc(parentUid)
          .collection('childProfiles')
          .doc('remote1')
          .set({
        'id': 'remote1',
        'displayName': 'Cloud Kid',
        'avatarColor': ChildProfile.defaultAvatarColors.first,
        'totalStars': 7,
        'dailyStreak': 2,
        'completedWordsCount': 12,
        'achievements': {'first_correct': true},
        'coins': 50,
        'updatedAt': Timestamp.fromDate(DateTime(2024, 6, 1)),
      });

      await syncService.syncFromCloud(parentUid);
      final profiles = await profileService.getAllProfiles();
      expect(profiles, hasLength(1));
      expect(profiles.first.displayName, 'Cloud Kid');
      expect(profiles.first.totalStars, 7);
      expect(profiles.first.pendingSync, false);
    });

    test('syncPendingToCloud uploads local pending profiles', () async {
      const parentUid = 'parent789';
      final profile = await profileService.createProfile(
        displayName: 'Pending',
        avatarColor: ChildProfile.defaultAvatarColors[2],
      );

      await syncService.syncPendingToCloud(parentUid);
      final synced = await profileService.getProfileById(profile.id);
      expect(synced?.pendingSync, false);
    });
  });
}
