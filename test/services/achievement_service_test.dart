// test/services/achievement_service_test.dart
import 'package:flutter_test/flutter_test.dart';
import 'package:english_learning_app/services/achievement_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  group('AchievementService', () {
    late AchievementService achievementService;

    setUp(() {
      SharedPreferences.setMockInitialValues({});
      achievementService = AchievementService();
    });

    test('should have initial achievements', () {
      expect(achievementService.achievements.length, greaterThan(0));
    });

    test('should have first_correct achievement', () {
      final achievement = achievementService.achievements.firstWhere(
        (a) => a.id == 'first_correct',
      );
      expect(achievement.name, 'צעד ראשון');
      expect(achievement.isUnlocked, false);
    });

    test('isUnlocked should return false for new achievements', () {
      expect(achievementService.isUnlocked('first_correct'), false);
    });

    test('unlockAchievement should unlock achievement', () async {
      // Create a fresh service instance
      SharedPreferences.setMockInitialValues({});
      final testService = AchievementService();
      await testService.loadAchievements();
      
      // Verify it's locked initially
      expect(testService.isUnlocked('first_correct'), false);
      
      // Unlock it
      testService.unlockAchievement('first_correct');
      
      // Check the achievement directly (unlockAchievement sets isUnlocked synchronously)
      final achievement = testService.achievements.firstWhere(
        (a) => a.id == 'first_correct',
      );
      expect(achievement.isUnlocked, true);
      
      // Also verify via isUnlocked method
      expect(testService.isUnlocked('first_correct'), true);
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

    test('checkForAchievements should unlock add_word when wordAdded is true', () {
      achievementService.checkForAchievements(streak: 0, wordAdded: true);
      expect(achievementService.isUnlocked('add_word'), true);
    });
  });
}
