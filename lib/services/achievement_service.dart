// lib/services/achievement_service.dart
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/achievement.dart';

class AchievementService with ChangeNotifier {
  List<Achievement> achievements = [
    Achievement(id: 'first_correct', name: 'צעד ראשון', description: 'ענית נכון על המילה הראשונה שלך!', icon: Icons.flag),
    Achievement(id: 'streak_5', name: 'ברצף!', description: 'הגעת לרצף של 5 תשובות נכונות', icon: Icons.whatshot),
    Achievement(id: 'level_1_complete', name: 'בוגר שלב 1', description: 'סיימת את כל המילים בשלב הראשון', icon: Icons.school),
    Achievement(id: 'add_word', name: 'יוצר קטן', description: 'הוספת מילה חדשה בעצמך!', icon: Icons.camera_alt),
  ];

  AchievementService() {
    loadAchievements();
  }

  // פונקציה שבודקת אם צריך לפתוח הישגים חדשים
  void checkForAchievements({required int streak, bool wordAdded = false, String? levelName}) {
    // בדוק הישג על תשובה ראשונה
    if (!isUnlocked('first_correct')) {
      unlockAchievement('first_correct');
    }

    // בדוק הישג על רצף
    if (streak >= 5 && !isUnlocked('streak_5')) {
      unlockAchievement('streak_5');
    }

    // בדוק הישג על סיום שלב
    if (levelName == 'שלב 1: פירות' && !isUnlocked('level_1_complete')) {
      // (נוסיף לוגיקה לבדוק שכל המילים הושלמו)
      // unlockAchievement('level_1_complete');
    }

    // בדוק הישג על הוספת מילה
    if (wordAdded && !isUnlocked('add_word')) {
      unlockAchievement('add_word');
    }
  }

  bool isUnlocked(String id) {
    return achievements.firstWhere((a) => a.id == id).isUnlocked;
  }

  void unlockAchievement(String id) async {
    final achievement = achievements.firstWhere((a) => a.id == id);
    if (!achievement.isUnlocked) {
      achievement.isUnlocked = true;
      await _saveAchievement(id, true);
      print("Achievement Unlocked: ${achievement.name}");
      notifyListeners(); // מודיע לאפליקציה על השינוי
      // כאן אפשר להוסיף קריאה להצגת ההודעה למשתמש
    }
  }

  // שמירה וטעינה מהזיכרון
  Future<void> _saveAchievement(String id, bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('achievement_$id', value);
  }

  Future<void> loadAchievements() async {
    final prefs = await SharedPreferences.getInstance();
    for (var achievement in achievements) {
      achievement.isUnlocked = prefs.getBool('achievement_${achievement.id}') ?? false;
    }
    notifyListeners();
  }
}