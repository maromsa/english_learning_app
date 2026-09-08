import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:english_learning_app/models/child_profile.dart';
import 'package:english_learning_app/services/child_profile_service.dart';
import 'package:english_learning_app/services/child_profile_sync_service.dart';
import 'package:english_learning_app/services/shop_customization_service.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('ChildProfileSyncService', () {
    late FakeFirebaseFirestore firestore;
    late SharedPreferences prefs;
    late ChildProfileService profileService;
    late ShopCustomizationService shopService;
    late ChildProfileSyncService syncService;

    setUp(() async {
      SharedPreferences.setMockInitialValues({});
      prefs = await SharedPreferences.getInstance();
      firestore = FakeFirebaseFirestore();
      profileService = ChildProfileService(prefs: prefs);
      shopService = ShopCustomizationService(prefs: prefs);
      syncService = ChildProfileSyncService(
        firestore: firestore,
        profileService: profileService,
        shopCustomizationService: shopService,
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

    group('shop customization sync', () {
      test('uploads unlocked + equipped shop fields to the cloud doc',
          () async {
        const parentUid = 'shopParent1';
        final profile = await profileService.createProfile(
          displayName: 'Buyer',
          avatarColor: ChildProfile.defaultAvatarColors.first,
        );
        await profileService.updateProgressSnapshot(
          profileId: profile.id,
          unlockedThemes: const ['theme_space'],
          unlockedSounds: const ['sound_funny'],
          equippedTheme: 'theme_space',
          equippedSound: 'sound_funny',
        );

        final updated = await profileService.getProfileById(profile.id);
        await syncService.syncProfileToCloud(parentUid, updated!);

        final doc = await firestore
            .collection('users')
            .doc(parentUid)
            .collection('childProfiles')
            .doc(profile.id)
            .get();
        expect(doc.data()?['unlockedThemes'], ['theme_space']);
        expect(doc.data()?['unlockedSounds'], ['sound_funny']);
        expect(doc.data()?['equippedTheme'], 'theme_space');
      });

      test('syncFromCloud unions unlocked ids and writes them to the device',
          () async {
        const parentUid = 'shopParent2';
        const profileId = 'kid1';

        // Local profile already owns the space theme...
        await profileService.saveProfile(
          ChildProfile(
            id: profileId,
            displayName: 'Kid',
            avatarColor: ChildProfile.defaultAvatarColors.first,
            unlockedThemes: const ['theme_space'],
            equippedTheme: 'theme_space',
            updatedAt: DateTime(2024, 5, 1),
            pendingSync: false,
          ),
        );
        await shopService.saveUnlockedThemeIds(profileId, {'theme_space'});

        // ...the cloud copy owns the gold theme instead.
        await firestore
            .collection('users')
            .doc(parentUid)
            .collection('childProfiles')
            .doc(profileId)
            .set({
          'id': profileId,
          'displayName': 'Kid',
          'avatarColor': ChildProfile.defaultAvatarColors.first,
          'unlockedThemes': ['theme_gold'],
          'equippedTheme': 'theme_gold',
          'updatedAt': Timestamp.fromDate(DateTime(2024, 6, 1)),
        });

        await syncService.syncFromCloud(parentUid);

        final merged = await profileService.getProfileById(profileId);
        expect(
          merged!.unlockedThemes,
          containsAll(<String>['theme_space', 'theme_gold']),
        );
        // Cloud doc is newer → its equipped choice wins.
        expect(merged.equippedTheme, 'theme_gold');

        // The device store now reflects both unlocks.
        final onDevice = await shopService.getUnlockedThemeIds(profileId);
        expect(onDevice, containsAll(<String>['theme_space', 'theme_gold']));
      });

      test('equipped id follows the newer updatedAt when local is newer',
          () async {
        const parentUid = 'shopParent3';
        const profileId = 'kid2';

        await profileService.saveProfile(
          ChildProfile(
            id: profileId,
            displayName: 'Kid2',
            avatarColor: ChildProfile.defaultAvatarColors.first,
            unlockedThemes: const ['theme_space', 'theme_gold'],
            equippedTheme: 'theme_gold',
            updatedAt: DateTime(2024, 7, 1),
            pendingSync: true,
          ),
        );

        await firestore
            .collection('users')
            .doc(parentUid)
            .collection('childProfiles')
            .doc(profileId)
            .set({
          'id': profileId,
          'displayName': 'Kid2',
          'avatarColor': ChildProfile.defaultAvatarColors.first,
          'unlockedThemes': ['theme_space'],
          'equippedTheme': 'theme_space',
          'updatedAt': Timestamp.fromDate(DateTime(2024, 6, 1)),
        });

        await syncService.syncFromCloud(parentUid);

        final merged = await profileService.getProfileById(profileId);
        expect(merged!.equippedTheme, 'theme_gold'); // local newer
        expect(
          merged.unlockedThemes,
          containsAll(<String>['theme_space', 'theme_gold']),
        );
      });
    });
  });
}
