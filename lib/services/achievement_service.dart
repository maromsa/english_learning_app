// lib/services/achievement_service.dart
//
// Achievement catalog + unlock logic.
//
// Catalog size: 28 achievements across 7 categories.
// Each achievement is persisted to SharedPreferences and optionally synced to
// Firestore via UserDataService.

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
  bool _disposed = false;

  void _notify() {
    if (!_disposed) notifyListeners();
  }

  void setUserId(String? userId) {
    if (_userId == userId) return;
    _currentUserId = userId;
    loadAchievements();
  }

  String? get _userId => _currentUserId;

  // ---------------------------------------------------------------------------
  // Catalog — 28 achievements
  // ---------------------------------------------------------------------------

  List<Achievement> achievements = [
    // ── First Steps ────────────────────────────────────────────────────────────
    Achievement(
      id: 'first_correct',
      title: 'First Word Learned',
      description: 'ענית נכון על המילה הראשונה שלך!',
      icon: Icons.flag,
      category: AchievementCategory.firstSteps,
      coinReward: 20,
    ),
    Achievement(
      id: 'add_word',
      title: 'יוצר קטן',
      description: 'הוספת מילה חדשה בעצמך!',
      icon: Icons.camera_alt,
      category: AchievementCategory.firstSteps,
      coinReward: 30,
    ),
    Achievement(
      id: 'first_story',
      title: 'מספר סיפורים',
      description: 'קראת את הסיפור הראשון שלך עם ספארק!',
      icon: Icons.auto_stories,
      category: AchievementCategory.firstSteps,
      coinReward: 25,
    ),
    Achievement(
      id: 'first_lightning',
      title: 'ניצוץ ראשון',
      description: 'סיימת את סבב ריצת הברק הראשון שלך!',
      icon: Icons.bolt,
      category: AchievementCategory.firstSteps,
      coinReward: 20,
    ),

    // ── Learning ───────────────────────────────────────────────────────────────
    Achievement(
      id: 'level_1_complete',
      title: 'בוגר שלב 1',
      description: 'סיימת את כל המילים בשלב הראשון',
      icon: Icons.school,
      category: AchievementCategory.learning,
      coinReward: 50,
    ),
    Achievement(
      id: 'words_10',
      title: 'עשר מילים',
      description: 'למדת 10 מילים שונות',
      icon: Icons.book,
      requirementValue: 10,
      category: AchievementCategory.learning,
      coinReward: 30,
    ),
    Achievement(
      id: 'words_25',
      title: 'עשרים וחמש מילים',
      description: 'למדת 25 מילים — ממש יפה!',
      icon: Icons.menu_book,
      requirementValue: 25,
      category: AchievementCategory.learning,
      coinReward: 60,
    ),
    Achievement(
      id: 'words_50',
      title: 'חמישים מילים',
      description: 'חמישים מילים באנגלית — אלוף!',
      icon: Icons.workspace_premium,
      requirementValue: 50,
      category: AchievementCategory.learning,
      coinReward: 100,
    ),
    Achievement(
      id: 'srs_mastered_10',
      title: 'שולט על 10 מילים',
      description: '10 מילים הגיעו לשליטה מלאה בחזרה המדורגת',
      icon: Icons.stars,
      requirementValue: 10,
      category: AchievementCategory.learning,
      coinReward: 75,
    ),
    Achievement(
      id: 'srs_mastered_25',
      title: 'שולט על 25 מילים',
      description: '25 מילים עברו לזיכרון לטווח ארוך!',
      icon: Icons.military_tech,
      requirementValue: 25,
      category: AchievementCategory.learning,
      coinReward: 150,
    ),

    // ── Streak ─────────────────────────────────────────────────────────────────
    Achievement(
      id: 'streak_5',
      title: 'Quiz Streak',
      description: 'הגעת לרצף של 5 תשובות נכונות',
      icon: Icons.whatshot,
      requirementValue: 5,
      category: AchievementCategory.streak,
      coinReward: 25,
    ),
    Achievement(
      id: 'streak_10',
      title: 'עשרה ברצף',
      description: 'עשר תשובות נכונות ברצף — מדהים!',
      icon: Icons.local_fire_department,
      requirementValue: 10,
      category: AchievementCategory.streak,
      coinReward: 50,
    ),
    Achievement(
      id: 'daily_streak_3',
      title: 'שלושה ימים ברצף',
      description: 'למדת 3 ימים רצופים!',
      icon: Icons.calendar_today,
      requirementValue: 3,
      category: AchievementCategory.streak,
      coinReward: 40,
    ),
    Achievement(
      id: 'daily_streak_7',
      title: 'שבוע שלם',
      description: 'שבוע ימים רצופים של למידה — מצוין!',
      icon: Icons.date_range,
      requirementValue: 7,
      category: AchievementCategory.streak,
      coinReward: 100,
    ),
    Achievement(
      id: 'daily_streak_30',
      title: 'חודש שלם',
      description: '30 ימים רצופים — לגמרי גאון!',
      icon: Icons.emoji_events,
      requirementValue: 30,
      category: AchievementCategory.streak,
      coinReward: 300,
    ),

    // ── Pronunciation ──────────────────────────────────────────────────────────
    Achievement(
      id: 'first_3star_pronunciation',
      title: 'הגייה מושלמת',
      description: 'קיבלת 3 כוכבים על הגייה!',
      icon: Icons.record_voice_over,
      category: AchievementCategory.pronunciation,
      coinReward: 30,
    ),
    Achievement(
      id: 'pronunciation_5',
      title: 'חמש הגיות מושלמות',
      description: '5 מילים עם 3 כוכבים הגייה',
      icon: Icons.mic,
      requirementValue: 5,
      category: AchievementCategory.pronunciation,
      coinReward: 50,
    ),
    Achievement(
      id: 'pronunciation_20',
      title: 'אלוף ההגייה',
      description: '20 מילים עם 3 כוכבים הגייה — ממש כמו אנגלי!',
      icon: Icons.spatial_audio,
      requirementValue: 20,
      category: AchievementCategory.pronunciation,
      coinReward: 120,
    ),

    // ── Explorer ────────────────────────────────────────────────────────────────
    Achievement(
      id: 'camera_explorer',
      title: 'חוקר תמונות',
      description: 'צלמת עצם לראשונה וה-AI זיהה אותו!',
      icon: Icons.photo_camera,
      category: AchievementCategory.explorer,
      coinReward: 30,
    ),
    Achievement(
      id: 'camera_5',
      title: 'צלם מהיר',
      description: 'צלמת 5 עצמים שה-AI זיהה נכון',
      icon: Icons.camera_enhance,
      requirementValue: 5,
      category: AchievementCategory.explorer,
      coinReward: 50,
    ),
    Achievement(
      id: 'story_3',
      title: 'אוהב סיפורים',
      description: 'קראת 3 סיפורים שונים עם ספארק',
      icon: Icons.library_books,
      requirementValue: 3,
      category: AchievementCategory.explorer,
      coinReward: 60,
    ),

    // ── Collector ───────────────────────────────────────────────────────────────
    Achievement(
      id: 'coin_collector',
      title: 'Coin Collector',
      description: 'אספת 500 מטבעות',
      icon: Icons.monetization_on,
      requirementValue: 500,
      category: AchievementCategory.collector,
      coinReward: 0, // no coin reward for coin achievements
    ),
    Achievement(
      id: 'rich_kid',
      title: 'ילד עשיר',
      description: 'אספת 2000 מטבעות סה"כ',
      icon: Icons.savings,
      requirementValue: 2000,
      category: AchievementCategory.collector,
      coinReward: 0,
    ),
    Achievement(
      id: 'map_builder',
      title: 'Map Builder',
      description: 'פתחת 10 פריטים במפה התלת-מימדית',
      icon: Icons.map,
      requirementValue: 10,
      category: AchievementCategory.collector,
      coinReward: 40,
    ),
    Achievement(
      id: 'shop_first',
      title: 'קניון ראשון',
      description: 'קנית פריט ראשון בחנות!',
      icon: Icons.shopping_bag,
      category: AchievementCategory.collector,
      coinReward: 15,
    ),

    // ── Dedication ──────────────────────────────────────────────────────────────
    Achievement(
      id: 'missions_complete_day',
      title: 'משימות יום',
      description: 'השלמת את כל המשימות היומיות!',
      icon: Icons.task_alt,
      category: AchievementCategory.dedication,
      coinReward: 50,
    ),
    Achievement(
      id: 'missions_complete_week',
      title: 'שבוע מושלם',
      description: 'השלמת את כל המשימות היומיות 7 ימים ברצף!',
      icon: Icons.verified,
      requirementValue: 7,
      category: AchievementCategory.dedication,
      coinReward: 200,
    ),
    Achievement(
      id: 'all_modes_tried',
      title: 'חוקר כולל',
      description: 'ניסית את כל מצבי המשחק (Lightning, Quiz, Camera, Story)!',
      icon: Icons.explore,
      category: AchievementCategory.dedication,
      coinReward: 75,
    ),
  ];

  // ---------------------------------------------------------------------------
  // Auto-check triggers
  // ---------------------------------------------------------------------------

  void _onCoinsOrOwnedChanged() {
    final provider = _coinProvider;
    if (provider == null) return;
    final coins = provider.coins;
    final ownedCount = provider.ownedShopItemsCount;

    if (coins >= 500 && !isUnlocked('coin_collector')) {
      unawaited(unlockAchievement('coin_collector'));
    }
    if (coins >= 2000 && !isUnlocked('rich_kid')) {
      unawaited(unlockAchievement('rich_kid'));
    }
    if (ownedCount >= 10 && !isUnlocked('map_builder')) {
      unawaited(unlockAchievement('map_builder'));
    }
    if (ownedCount >= 1 && !isUnlocked('shop_first')) {
      unawaited(unlockAchievement('shop_first'));
    }
  }

  /// Check achievements triggered by an answered question / word event.
  ///
  /// Call from Lightning, ImageQuiz, and Home screens after each answer.
  Future<void> checkForAchievements({
    required int streak,
    bool wordAdded = false,
    String? levelName,
    int dailyStreak = 0,
    int wordsLearned = 0,
    int masteredWords = 0,
    int pronunciationStars = 0,
    int perfectPronunciationCount = 0,
    bool cameraSuccess = false,
    int cameraSuccessCount = 0,
    bool storyRead = false,
    int storiesRead = 0,
    bool lightningCompleted = false,
    bool allMissionsCompleted = false,
    int allMissionsStreak = 0,
    bool triedAllModes = false,
  }) async {
    // First steps
    if (!isUnlocked('first_correct')) {
      await unlockAchievement('first_correct');
    }
    if (wordAdded && !isUnlocked('add_word')) {
      await unlockAchievement('add_word');
    }
    if (lightningCompleted && !isUnlocked('first_lightning')) {
      await unlockAchievement('first_lightning');
    }
    if (storyRead && !isUnlocked('first_story')) {
      await unlockAchievement('first_story');
    }

    // Streak — quiz
    if (streak >= 5 && !isUnlocked('streak_5')) {
      await unlockAchievement('streak_5');
    }
    if (streak >= 10 && !isUnlocked('streak_10')) {
      await unlockAchievement('streak_10');
    }

    // Streak — daily
    if (dailyStreak >= 3 && !isUnlocked('daily_streak_3')) {
      await unlockAchievement('daily_streak_3');
    }
    if (dailyStreak >= 7 && !isUnlocked('daily_streak_7')) {
      await unlockAchievement('daily_streak_7');
    }
    if (dailyStreak >= 30 && !isUnlocked('daily_streak_30')) {
      await unlockAchievement('daily_streak_30');
    }

    // Learning — words practiced
    if (wordsLearned >= 10 && !isUnlocked('words_10')) {
      await unlockAchievement('words_10');
    }
    if (wordsLearned >= 25 && !isUnlocked('words_25')) {
      await unlockAchievement('words_25');
    }
    if (wordsLearned >= 50 && !isUnlocked('words_50')) {
      await unlockAchievement('words_50');
    }

    // Learning — SRS mastered
    if (masteredWords >= 10 && !isUnlocked('srs_mastered_10')) {
      await unlockAchievement('srs_mastered_10');
    }
    if (masteredWords >= 25 && !isUnlocked('srs_mastered_25')) {
      await unlockAchievement('srs_mastered_25');
    }

    // Level completion
    if (levelName != null && !isUnlocked('level_1_complete')) {
      await unlockAchievement('level_1_complete');
    }

    // Pronunciation
    if (pronunciationStars >= 3 && !isUnlocked('first_3star_pronunciation')) {
      await unlockAchievement('first_3star_pronunciation');
    }
    if (perfectPronunciationCount >= 5 && !isUnlocked('pronunciation_5')) {
      await unlockAchievement('pronunciation_5');
    }
    if (perfectPronunciationCount >= 20 && !isUnlocked('pronunciation_20')) {
      await unlockAchievement('pronunciation_20');
    }

    // Explorer — camera
    if (cameraSuccess && !isUnlocked('camera_explorer')) {
      await unlockAchievement('camera_explorer');
    }
    if (cameraSuccessCount >= 5 && !isUnlocked('camera_5')) {
      await unlockAchievement('camera_5');
    }

    // Explorer — story
    if (storiesRead >= 3 && !isUnlocked('story_3')) {
      await unlockAchievement('story_3');
    }

    // Dedication
    if (allMissionsCompleted && !isUnlocked('missions_complete_day')) {
      await unlockAchievement('missions_complete_day');
    }
    if (allMissionsStreak >= 7 && !isUnlocked('missions_complete_week')) {
      await unlockAchievement('missions_complete_week');
    }
    if (triedAllModes && !isUnlocked('all_modes_tried')) {
      await unlockAchievement('all_modes_tried');
    }
  }

  // ---------------------------------------------------------------------------
  // Quick single-event triggers (convenience wrappers)
  // ---------------------------------------------------------------------------

  Future<void> onStoryRead({int storiesRead = 1}) =>
      checkForAchievements(streak: 0, storyRead: true, storiesRead: storiesRead);

  Future<void> onLightningCompleted({required int streak, int dailyStreak = 0,
      int wordsLearned = 0, int masteredWords = 0}) =>
      checkForAchievements(
        streak: streak,
        lightningCompleted: true,
        dailyStreak: dailyStreak,
        wordsLearned: wordsLearned,
        masteredWords: masteredWords,
      );

  Future<void> onCameraSuccess({required int totalSuccessCount}) =>
      checkForAchievements(
        streak: 0,
        cameraSuccess: true,
        cameraSuccessCount: totalSuccessCount,
      );

  Future<void> onPronunciationScore({
    required int stars,
    required int totalPerfectCount,
  }) =>
      checkForAchievements(
        streak: 0,
        pronunciationStars: stars,
        perfectPronunciationCount: totalPerfectCount,
      );

  Future<void> onAllMissionsCompleted({int missionStreakDays = 1}) =>
      checkForAchievements(
        streak: 0,
        allMissionsCompleted: true,
        allMissionsStreak: missionStreakDays,
      );

  /// Call once when the user first starts a game mode.
  /// [mode] should be one of: 'lightning', 'quiz', 'camera', 'story'.
  /// Persists the visited set and unlocks 'all_modes_tried' when all 4 are seen.
  Future<void> markModeTried(String mode) async {
    if (isUnlocked('all_modes_tried')) return;

    const allModes = {'lightning', 'quiz', 'camera', 'story'};
    final prefs = await SharedPreferences.getInstance();
    final prefKey = _currentUserId != null
        ? 'user_${_currentUserId}_modes_tried'
        : 'modes_tried';

    final raw = prefs.getString(prefKey) ?? '';
    final tried = raw.isEmpty ? <String>{} : raw.split(',').toSet();
    tried.add(mode);
    await prefs.setString(prefKey, tried.join(','));

    if (tried.containsAll(allModes)) {
      await checkForAchievements(streak: 0, triedAllModes: true);
    }
  }

  /// Call once each time the user earns a 3-star pronunciation.
  /// Persists a cumulative count and checks pronunciation achievements.
  Future<void> recordPronunciationPerfect({required int stars}) async {
    final prefs = await SharedPreferences.getInstance();
    final prefKey = _currentUserId != null
        ? 'user_${_currentUserId}_pronunciation_perfect'
        : 'pronunciation_perfect';

    final count = (prefs.getInt(prefKey) ?? 0) + 1;
    await prefs.setInt(prefKey, count);

    await onPronunciationScore(stars: stars, totalPerfectCount: count);
  }

  /// Call once each time the user completes a story.
  /// Persists a cumulative count per-user and checks story achievements.
  Future<void> recordStoryRead() async {
    final prefs = await SharedPreferences.getInstance();
    final prefKey = _currentUserId != null
        ? 'user_${_currentUserId}_stories_read'
        : 'stories_read';

    final count = (prefs.getInt(prefKey) ?? 0) + 1;
    await prefs.setInt(prefKey, count);

    await checkForAchievements(streak: 0, storyRead: true, storiesRead: count);
  }

  /// Call once each time the user successfully identifies an object with the camera.
  /// Persists a cumulative count per-user and checks camera achievements.
  Future<void> recordCameraSuccess() async {
    final prefs = await SharedPreferences.getInstance();
    final prefKey = _currentUserId != null
        ? 'user_${_currentUserId}_camera_success_count'
        : 'camera_success_count';

    final count = (prefs.getInt(prefKey) ?? 0) + 1;
    await prefs.setInt(prefKey, count);

    await onCameraSuccess(totalSuccessCount: count);
  }

  // ---------------------------------------------------------------------------
  // Core unlock + persist
  // ---------------------------------------------------------------------------

  Achievement? _findAchievement(String id) {
    for (final achievement in achievements) {
      if (achievement.id == id) return achievement;
    }
    debugPrint('AchievementService: achievement "$id" not found');
    return null;
  }

  bool isUnlocked(String id) => _findAchievement(id)?.isUnlocked ?? false;

  Future<void> unlockAchievement(String id) async {
    final achievement = _findAchievement(id);
    if (achievement == null || achievement.isUnlocked) return;

    achievement.isUnlocked = true;
    await _saveAchievement(id, true);
    debugPrint('Achievement Unlocked: ${achievement.title}');

    // Grant coin reward if any.
    if (achievement.coinReward > 0) {
      _coinProvider?.addCoins(achievement.coinReward);
    }

    _sparkOverlayController?.markCelebrating();
    _notify();
    _achievementUnlockedCallback?.call(achievement);
  }

  Function(Achievement)? _achievementUnlockedCallback;

  void setAchievementUnlockedCallback(Function(Achievement) callback) {
    _achievementUnlockedCallback = callback;
  }

  void clearAchievementUnlockedCallback() {
    _achievementUnlockedCallback = null;
  }

  // ---------------------------------------------------------------------------
  // Persistence
  // ---------------------------------------------------------------------------

  String _achievementKey(String id) {
    if (_currentUserId != null) {
      return 'user_${_currentUserId}_achievement_$id';
    }
    return 'achievement_$id';
  }

  Future<void> _saveAchievement(String id, bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_achievementKey(id), value);
    if (_currentUserId != null && value) {
      await _userDataService.unlockAchievement(_currentUserId!, id);
    }
  }

  Future<void> loadAchievements() async {
    final prefs = await SharedPreferences.getInstance();
    for (final achievement in achievements) {
      achievement.isUnlocked =
          prefs.getBool(_achievementKey(achievement.id)) ??
              prefs.getBool('achievement_${achievement.id}') ??
              false;
    }
    _notify();
  }

  // ---------------------------------------------------------------------------
  // Helpers
  // ---------------------------------------------------------------------------

  /// Returns achievements grouped by category (for trophy room display).
  Map<AchievementCategory, List<Achievement>> get byCategory {
    final map = <AchievementCategory, List<Achievement>>{};
    for (final a in achievements) {
      map.putIfAbsent(a.category, () => []).add(a);
    }
    return map;
  }

  int get unlockedCount => achievements.where((a) => a.isUnlocked).length;
  int get totalCount => achievements.length;

  void disposeListener() {
    if (_listenerAttached) {
      _coinProvider?.removeListener(_onCoinsOrOwnedChanged);
      _listenerAttached = false;
    }
  }

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }
}

// ignore: avoid_void_async
void unawaited(Future<void> future) {}
