// lib/services/achievement_service.dart
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/achievement.dart';
import '../providers/coin_provider.dart';
import '../providers/spark_overlay_controller.dart';
import '../services/user_data_service.dart';

class AchievementService with ChangeNotifier {
  AchievementService({
    UserDataService? userDataService,
    CoinProvider? coinProvider,
    SparkOverlayController? sparkOverlayController,
  })  : _userDataService = userDataService ?? UserDataService(),
        _coinProvider = coinProvider,
        _sparkOverlayController = sparkOverlayController {
    loadAchievements();
    _coinProvider?.addListener(_onCoinsOrOwnedChanged);
  }

  final UserDataService _userDataService;
  final CoinProvider? _coinProvider;
  final SparkOverlayController? _sparkOverlayController;
  String? _currentUserId;
  bool _listenerAttached = true;

  /// Set the current user ID for cloud sync
  void setUserId(String? userId) {
    _currentUserId = userId;
  }

  List<Achievement> achievements = [
    Achievement(
      id: 'first_correct',
      title: 'First Word Learned',
      description: 'ענית נכון על המילה הראשונה שלך!',
      icon: Icons.flag,
    ),
    Achievement(
      id: 'streak_5',
      title: 'Quiz Streak',
      description: 'הגעת לרצף של 5 תשובות נכונות',
      icon: Icons.whatshot,
      requirementValue: 5,
    ),
    Achievement(
      id: 'coin_collector',
      title: 'Coin Collector',
      description: 'אספת 500 מטבעות',
      icon: Icons.monetization_on,
      requirementValue: 500,
    ),
    Achievement(
      id: 'map_builder',
      title: 'Map Builder',
      description: 'פתחת 10 פריטים במפה התלת-מימדית',
      icon: Icons.map,
      requirementValue: 10,
    ),
    Achievement(
      id: 'level_1_complete',
      title: 'בוגר שלב 1',
      description: 'סיימת את כל המילים בשלב הראשון',
      icon: Icons.school,
    ),
    Achievement(
      id: 'add_word',
      title: 'יוצר קטן',
      description: 'הוספת מילה חדשה בעצמך!',
      icon: Icons.camera_alt,
    ),
  ];

  void _onCoinsOrOwnedChanged() {
    final provider = _coinProvider;
    if (provider == null) return;
    final coins = provider.coins;
    final ownedCount = provider.ownedShopItemsCount;

    if (coins >= 500 && !isUnlocked('coin_collector')) {
      unlockAchievement('coin_collector');
    }
    if (ownedCount >= 10 && !isUnlocked('map_builder')) {
      unlockAchievement('map_builder');
    }
  }

  /// Call when the user answers correctly (e.g. from Home or Image Quiz).
  /// [streak] is the current correct-answer streak; [wordAdded] if they added a word.
  void checkForAchievements({
    required int streak,
    bool wordAdded = false,
    String? levelName,
  }) {
    if (!isUnlocked('first_correct')) {
      unlockAchievement('first_correct');
    }
    if (streak >= 5 && !isUnlocked('streak_5')) {
      unlockAchievement('streak_5');
    }
    if (levelName == 'שלב 1: פירות' && !isUnlocked('level_1_complete')) {
      // Future: unlock when all words in level completed
    }
    if (wordAdded && !isUnlocked('add_word')) {
      unlockAchievement('add_word');
    }
  }

  Achievement? _findAchievement(String id) {
    for (final achievement in achievements) {
      if (achievement.id == id) {
        return achievement;
      }
    }
    debugPrint('Requested achievement "$id" was not found.');
    return null;
  }

  bool isUnlocked(String id) {
    final achievement = _findAchievement(id);
    return achievement?.isUnlocked ?? false;
  }

  Future<void> unlockAchievement(String id) async {
    final achievement = _findAchievement(id);
    if (achievement == null) return;
    if (achievement.isUnlocked) return;

    achievement.isUnlocked = true;
    await _saveAchievement(id, true);
    debugPrint('Achievement Unlocked: ${achievement.title}');

    _sparkOverlayController?.markCelebrating();
    notifyListeners();
    _achievementUnlockedCallback?.call(achievement);
  }

  Function(Achievement)? _achievementUnlockedCallback;

  void setAchievementUnlockedCallback(Function(Achievement) callback) {
    _achievementUnlockedCallback = callback;
  }

  Future<void> _saveAchievement(String id, bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('achievement_$id', value);
    if (_currentUserId != null && value) {
      await _userDataService.unlockAchievement(_currentUserId!, id);
    }
  }

  Future<void> loadAchievements() async {
    final prefs = await SharedPreferences.getInstance();
    for (final achievement in achievements) {
      achievement.isUnlocked =
          prefs.getBool('achievement_${achievement.id}') ?? false;
    }
    notifyListeners();
  }

  /// Call when disposing the service (e.g. in tests) to avoid leaking listener.
  void disposeListener() {
    if (_listenerAttached) {
      _coinProvider?.removeListener(_onCoinsOrOwnedChanged);
      _listenerAttached = false;
    }
  }
}
