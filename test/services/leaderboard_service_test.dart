import 'package:english_learning_app/models/child_profile.dart';
import 'package:english_learning_app/services/child_profile_service.dart';
import 'package:english_learning_app/services/leaderboard_service.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('LeaderboardService', () {
    late FakeFirebaseFirestore firestore;
    late ChildProfileService profileService;
    late LeaderboardService leaderboardService;

    setUp(() async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      firestore = FakeFirebaseFirestore();
      profileService = ChildProfileService(prefs: prefs);
      leaderboardService = LeaderboardService(
        firestore: firestore,
        profileService: profileService,
      );
    });

    Future<void> seedCloudProfile({
      required String parentUid,
      required String profileId,
      required String name,
      required int coins,
      required int dailyStreak,
    }) async {
      await firestore
          .collection('users')
          .doc(parentUid)
          .collection('childProfiles')
          .doc(profileId)
          .set({
        'id': profileId,
        'displayName': name,
        'avatarColor': ChildProfile.defaultAvatarColors.first,
        'coins': coins,
        'dailyStreak': dailyStreak,
      });
    }

    test('sorts by coins then streak descending', () async {
      await seedCloudProfile(
        parentUid: 'p1',
        profileId: 'a',
        name: 'Alpha',
        coins: 100,
        dailyStreak: 3,
      );
      await seedCloudProfile(
        parentUid: 'p2',
        profileId: 'b',
        name: 'Bravo',
        coins: 100,
        dailyStreak: 7,
      );
      await seedCloudProfile(
        parentUid: 'p3',
        profileId: 'c',
        name: 'Charlie',
        coins: 200,
        dailyStreak: 1,
      );

      final result = await leaderboardService.fetchLeaderboard();
      expect(result.entries, hasLength(3));
      expect(result.entries[0].displayName, 'Charlie');
      expect(result.entries[1].displayName, 'Bravo');
      expect(result.entries[2].displayName, 'Alpha');
      expect(result.entries[0].rank, 1);
      expect(result.entries[1].currentStreak, 7);
    });

    test('merges local and cloud stats for same profile id', () async {
      const profileId = 'kid1';
      await seedCloudProfile(
        parentUid: 'p1',
        profileId: profileId,
        name: 'Cloud Kid',
        coins: 40,
        dailyStreak: 2,
      );

      await profileService.saveProfile(
        ChildProfile(
          id: profileId,
          displayName: 'Cloud Kid',
          avatarColor: ChildProfile.defaultAvatarColors[1],
          coins: 90,
          dailyStreak: 5,
        ),
      );

      final result = await leaderboardService.fetchLeaderboard(
        currentProfileId: profileId,
      );

      expect(result.entries, hasLength(1));
      expect(result.entries.first.totalCoins, 90);
      expect(result.entries.first.currentStreak, 5);
      expect(result.entries.first.isCurrentUser, isTrue);
    });

    test('returns empty when no profiles exist', () async {
      final result = await leaderboardService.fetchLeaderboard();
      expect(result.entries, isEmpty);
      expect(result.currentUserEntry, isNull);
    });

    test('flags isCurrentUser on ranked entry', () async {
      final profile = await profileService.createProfile(
        displayName: 'Me',
        avatarColor: ChildProfile.defaultAvatarColors.first,
      );
      await profileService.updateProgressSnapshot(
        profileId: profile.id,
        coins: 12,
        dailyStreak: 1,
      );

      final result = await leaderboardService.fetchLeaderboard(
        currentProfileId: profile.id,
      );

      expect(result.entries, hasLength(1));
      expect(result.entries.first.isCurrentUser, isTrue);
      expect(result.currentUserEntry?.rank, 1);
    });
  });
}
