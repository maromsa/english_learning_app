import 'package:english_learning_app/models/child_profile.dart';
import 'package:english_learning_app/services/child_profile_service.dart';
import 'package:english_learning_app/services/child_profile_sync_service.dart';
import 'package:english_learning_app/services/leaderboard_service.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Leaderboard publish + read flow', () {
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

    test('syncProfileToCloud publishes a minimal leaderboard entry', () async {
      const parentUid = 'parent123';
      final profile = await profileService.createProfile(
        displayName: 'Noa',
        avatarColor: ChildProfile.defaultAvatarColors.first,
      );

      final ok = await syncService.syncProfileToCloud(parentUid, profile);
      expect(ok, true);

      final entry = await firestore
          .collection('leaderboard')
          .doc('${parentUid}_${profile.id}')
          .get();
      expect(entry.exists, true);

      final data = entry.data()!;
      expect(data['displayName'], 'Noa');
      expect(data['profileId'], profile.id);
      expect(data['coins'], profile.coins);
      expect(data['dailyStreak'], profile.dailyStreak);
      // Privacy: only the whitelisted fields may be published.
      expect(
        data.keys.toSet().difference({
          'profileId',
          'displayName',
          'coins',
          'dailyStreak',
          'avatarColor',
          'updatedAt',
        }),
        isEmpty,
      );
      expect(data.containsKey('avatarUrl'), isFalse);
    });

    test('deleteFromCloud removes the leaderboard entry too', () async {
      const parentUid = 'parent123';
      final profile = await profileService.createProfile(
        displayName: 'Noa',
        avatarColor: ChildProfile.defaultAvatarColors.first,
      );
      await syncService.syncProfileToCloud(parentUid, profile);

      await syncService.deleteFromCloud(parentUid, profile.id);

      final entry = await firestore
          .collection('leaderboard')
          .doc('${parentUid}_${profile.id}')
          .get();
      expect(entry.exists, false);
    });

    test('LeaderboardService reads entries from the leaderboard collection',
        () async {
      await firestore.collection('leaderboard').doc('uidA_p1').set({
        'profileId': 'p1',
        'displayName': 'Alice',
        'coins': 200,
        'dailyStreak': 5,
        'avatarColor': ChildProfile.defaultAvatarColors.first,
      });
      await firestore.collection('leaderboard').doc('uidB_p2').set({
        'profileId': 'p2',
        'displayName': 'Ben',
        'coins': 350,
        'dailyStreak': 2,
        'avatarColor': ChildProfile.defaultAvatarColors.first,
      });

      final service = LeaderboardService(
        firestore: firestore,
        profileService: profileService,
      );
      final result = await service.fetchLeaderboard();

      expect(result.entries, hasLength(2));
      expect(result.entries.first.displayName, 'Ben');
      expect(result.entries.first.rank, 1);
      expect(result.entries.last.displayName, 'Alice');
      expect(result.entries.last.rank, 2);
    });
  });
}
