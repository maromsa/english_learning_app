import 'package:english_learning_app/models/child_profile.dart';
import 'package:english_learning_app/services/child_profile_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('ChildProfileService', () {
    late SharedPreferences prefs;
    late ChildProfileService service;

    setUp(() async {
      SharedPreferences.setMockInitialValues({});
      prefs = await SharedPreferences.getInstance();
      service = ChildProfileService(prefs: prefs);
    });

    test('creates and loads profiles', () async {
      final profile = await service.createProfile(
        displayName: 'Noa',
        avatarColor: ChildProfile.defaultAvatarColors.first,
      );

      final loaded = await service.getProfileById(profile.id);
      expect(loaded?.displayName, 'Noa');
    });

    test('setActiveProfile persists active id', () async {
      final profile = await service.createProfile(
        displayName: 'Tom',
        avatarColor: ChildProfile.defaultAvatarColors[1],
      );

      await service.setActiveProfile(profile.id);
      final active = await service.getActiveProfile();
      expect(active?.id, profile.id);
    });

    test('migrates legacy local users once', () async {
      SharedPreferences.setMockInitialValues({
        'local_users': '[{"id":"legacy1","name":"Legacy","age":6,"isActive":true}]',
        'active_local_user_id': 'legacy1',
      });
      prefs = await SharedPreferences.getInstance();
      service = ChildProfileService(prefs: prefs);

      final profiles = await service.getAllProfiles();
      expect(profiles, hasLength(1));
      expect(profiles.first.displayName, 'Legacy');
      expect((await service.getActiveProfile())?.id, 'legacy1');
      expect(prefs.getBool('child_profiles_migrated_from_local_users'), true);
    });

    test('updateProgressSnapshot marks profile pending sync', () async {
      final profile = await service.createProfile(
        displayName: 'Maya',
        avatarColor: ChildProfile.defaultAvatarColors[2],
      );

      await service.updateProgressSnapshot(
        profileId: profile.id,
        totalStars: 10,
        dailyStreak: 4,
      );

      final updated = await service.getProfileById(profile.id);
      expect(updated?.totalStars, 10);
      expect(updated?.dailyStreak, 4);
      expect(updated?.pendingSync, true);
    });

    test('deleteProfile removes profile and active id', () async {
      final profile = await service.createProfile(
        displayName: 'Delete Me',
        avatarColor: ChildProfile.defaultAvatarColors[3],
      );
      await service.setActiveProfile(profile.id);

      final deleted = await service.deleteProfile(profile.id);
      expect(deleted, true);
      expect(await service.getActiveProfile(), isNull);
    });
  });
}
