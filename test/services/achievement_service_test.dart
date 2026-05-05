// test/services/achievement_service_test.dart
import 'package:english_learning_app/services/achievement_service.dart';
import 'package:english_learning_app/services/user_data_service.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  group('AchievementService', () {
    late AchievementService achievementService;

    setUp(() {
      SharedPreferences.setMockInitialValues({});
      achievementService = AchievementService(
        userDataService: UserDataService(firestore: FakeFirebaseFirestore()),
      );
    });

    test('should have initial achievements', () {
      expect(achievementService.achievements.length, greaterThan(0));
    });

    test('should have first_correct achievement', () {
      final achievement = achievementService.achievements.firstWhere(
        (a) => a.id == 'first_correct',
      );
      expect(achievement.title, 'First Word Learned');
      expect(achievement.name, achievement.title);
      expect(achievement.isUnlocked, false);
    });

    test('isUnlocked should return false for new achievements', () {
      expect(achievementService.isUnlocked('first_correct'), false);
    });

    test('isUnlocked should safely handle unknown ids', () {
      expect(achievementService.isUnlocked('unknown_achievement'), false);
    });

    test('unlockAchievement should unlock achievement', () async {
      // Create a fresh service instance (no CoinProvider so no listener)
      SharedPreferences.setMockInitialValues({});
      final testService = AchievementService(
        userDataService: UserDataService(firestore: FakeFirebaseFirestore()),
      );
      await testService.loadAchievements();

      // Verify it's locked initially
      expect(testService.isUnlocked('first_correct'), false);

      // Unlock it
      await testService.unlockAchievement('first_correct');

      // Reload so we assert persisted state (avoids race with ctor's loadAchievements)
      await testService.loadAchievements();

      final achievement = testService.achievements.firstWhere(
        (a) => a.id == 'first_correct',
      );
      expect(achievement.isUnlocked, true);
      expect(testService.isUnlocked('first_correct'), true);
    });

    test('unlockAchievement should ignore unknown ids without throwing', () {
      expect(
        () => achievementService.unlockAchievement('unknown_achievement'),
        returnsNormally,
      );
    });

    test('checkForAchievements should unlock first_correct', () {
      achievementService.checkForAchievements(streak: 0);
      expect(achievementService.isUnlocked('first_correct'), true);
    });

    test('checkForAchievements should unlock streak_5 when streak >= 5', () {
      achievementService.checkForAchievements(streak: 5);
      expect(achievementService.isUnlocked('streak_5'), true);
    });

    test('checkForAchievements should not unlock streak_5 when streak < 5', () {
      achievementService.checkForAchievements(streak: 4);
      expect(achievementService.isUnlocked('streak_5'), false);
    });

    test(
      'checkForAchievements should unlock add_word when wordAdded is true',
      () {
        achievementService.checkForAchievements(streak: 0, wordAdded: true);
        expect(achievementService.isUnlocked('add_word'), true);
      },
    );

    test('should have coin_collector and map_builder with requirementValue', () {
      final coinCollector = achievementService.achievements
          .firstWhere((a) => a.id == 'coin_collector');
      final mapBuilder = achievementService.achievements
          .firstWhere((a) => a.id == 'map_builder');
      expect(coinCollector.requirementValue, 500);
      expect(mapBuilder.requirementValue, 10);
    });
  });
}
