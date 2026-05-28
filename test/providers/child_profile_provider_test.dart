import 'package:english_learning_app/models/child_profile.dart';
import 'package:english_learning_app/providers/user_session_provider.dart';
import 'package:english_learning_app/services/child_profile_service.dart';
import 'package:english_learning_app/services/daily_reward_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('ChildProfile switching', () {
    late SharedPreferences prefs;
    late ChildProfileService profileService;
    late UserSessionProvider sessionProvider;
    late ChildProfile childA;
    late ChildProfile childB;

    setUp(() async {
      SharedPreferences.setMockInitialValues({});
      prefs = await SharedPreferences.getInstance();
      profileService = ChildProfileService(prefs: prefs);
      sessionProvider = UserSessionProvider();

      childA = ChildProfile(
        id: 'childA',
        displayName: 'Child A',
        avatarColor: ChildProfile.defaultAvatarColors.first,
        createdAt: DateTime(2024, 1, 1),
      );
      childB = ChildProfile(
        id: 'childB',
        displayName: 'Child B',
        avatarColor: ChildProfile.defaultAvatarColors[1],
        createdAt: DateTime(2024, 1, 2),
      );
      await profileService.saveProfile(childA);
      await profileService.saveProfile(childB);

      await prefs.setInt('user_${childA.id}_daily_reward_streak', 2);
      await prefs.setInt('user_${childB.id}_daily_reward_streak', 5);
    });

    test('active profile and streak are isolated per child', () async {
      await profileService.setActiveProfile(childA.id);
      await sessionProvider.switchToChildProfile(
        profileId: childA.id,
        displayName: childA.displayName,
      );

      final rewardA = DailyRewardService()..setUserId(childA.id);
      expect(await rewardA.getCurrentStreak(), 2);
      expect(sessionProvider.currentUserId, childA.id);

      await profileService.setActiveProfile(childB.id);
      await sessionProvider.switchToChildProfile(
        profileId: childB.id,
        displayName: childB.displayName,
      );

      final rewardB = DailyRewardService()..setUserId(childB.id);
      expect(await rewardB.getCurrentStreak(), 5);
      expect(sessionProvider.currentUserId, childB.id);
      expect((await profileService.getActiveProfile())?.id, childB.id);
    });
  });
}
