import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/daily_mission.dart';

class DailyMissionProvider with ChangeNotifier {
  DailyMissionProvider();

  static const String _legacyDateKey = 'daily_missions_date';
  static const String _legacyMissionsKey = 'daily_missions_payload';
  static const String _missionStreakKey = 'daily_missions_complete_streak';

  String? _userId;
  bool _initialized = false;
  List<DailyMission> _missions = <DailyMission>[];

  /// Days in a row where all missions were completed.
  int _completionStreakDays = 0;

  bool _disposed = false;

  /// Called once per day the first time all missions are completed.
  /// Receives the current completion streak in days.
  void Function(int streakDays)? onAllCompleted;

  void _notify() {
    if (!_disposed) notifyListeners();
  }

  void setUserId(String? userId) {
    if (_userId == userId) {
      return;
    }
    _userId = userId;
    _initialized = false;
  }

  String get _prefDateKey =>
      _userId == null ? _legacyDateKey : 'user_${_userId}_daily_missions_date';

  String get _prefMissionsKey => _userId == null
      ? _legacyMissionsKey
      : 'user_${_userId}_daily_missions_payload';

  bool get isInitialized => _initialized;
  List<DailyMission> get missions => List<DailyMission>.unmodifiable(_missions);

  /// Days in a row that all missions were completed (for streak bonus).
  int get completionStreakDays => _completionStreakDays;

  /// Bonus multiplier applied to mission rewards when on a completion streak.
  /// 1 day = ×1.0, 3 days = ×1.25, 7+ days = ×1.5.
  double get streakBonusMultiplier {
    if (_completionStreakDays >= 7) return 1.5;
    if (_completionStreakDays >= 3) return 1.25;
    return 1.0;
  }

  bool get allCompleted =>
      _initialized && _missions.every((m) => m.isCompleted);

  Future<void> initialize() async {
    final prefs = await SharedPreferences.getInstance();
    final String todayKey = _todayKey();
    final String? storedDate = prefs.getString(_prefDateKey);

    // ── Load completion-streak ─────────────────────────────────────────────────
    // The streak key stores "YYYY-MM-DD|count". If yesterday's date matches,
    // we preserve the count; otherwise we check if today's missions were already
    // all completed (loaded below) to decide whether to reset or carry forward.
    final String? rawStreak = prefs.getString(_missionStreakKey);
    if (rawStreak != null) {
      final parts = rawStreak.split('|');
      if (parts.length == 2) {
        final storedStreakDate = parts[0];
        final storedCount = int.tryParse(parts[1]) ?? 0;
        final yesterday = _yesterdayKey();
        if (storedStreakDate == todayKey || storedStreakDate == yesterday) {
          _completionStreakDays = storedCount;
        }
        // else: streak broken — stays 0
      }
    }

    if (storedDate == todayKey) {
      final List<String>? storedMissions = prefs.getStringList(
        _prefMissionsKey,
      );
      if (storedMissions != null && storedMissions.isNotEmpty) {
        final parsed = <DailyMission>[];
        for (final json in storedMissions) {
          try {
            parsed.add(DailyMission.fromJson(json));
          } catch (e) {
            debugPrint('DailyMissionProvider: skipping malformed mission: $e');
          }
        }
        _missions = parsed.isEmpty ? _buildDefaultMissions() : parsed;
      } else {
        _missions = _buildDefaultMissions();
        await _persist(prefs, todayKey);
      }
    } else {
      _missions = _buildDefaultMissions();
      await _persist(prefs, todayKey);
    }

    _initialized = true;
    _notify();
  }

  Future<void> incrementByType(DailyMissionType type, {int amount = 1}) async {
    if (!_initialized || amount <= 0) {
      return;
    }

    DailyMission? mission;
    for (final current in _missions) {
      if (current.type == type) {
        mission = current;
        break;
      }
    }

    if (mission == null) {
      return;
    }

    final int newProgress = (mission.progress + amount).clamp(
      0,
      mission.target,
    );
    if (newProgress == mission.progress) {
      return;
    }

    mission.progress = newProgress;
    await _persist();
    await _checkAndBumpStreak();
    _notify();
  }

  Future<void> incrementById(String missionId, {int amount = 1}) async {
    if (!_initialized || amount <= 0) {
      return;
    }

    DailyMission? mission;
    for (final current in _missions) {
      if (current.id == missionId) {
        mission = current;
        break;
      }
    }

    if (mission == null) {
      return;
    }

    final int newProgress = (mission.progress + amount).clamp(
      0,
      mission.target,
    );
    if (newProgress == mission.progress) {
      return;
    }

    mission.progress = newProgress;
    await _persist();
    await _checkAndBumpStreak();
    _notify();
  }

  Future<bool> claimReward(
    String missionId,
    Future<void> Function(int reward) rewardCallback,
  ) async {
    if (!_initialized) {
      return false;
    }

    DailyMission? mission;
    for (final current in _missions) {
      if (current.id == missionId) {
        mission = current;
        break;
      }
    }

    if (mission == null || !mission.isClaimable) {
      return false;
    }

    // Optimistic lock: mark claimed before any await so double-taps exit early.
    mission.rewardClaimed = true;
    _notify();

    try {
      await rewardCallback(mission.reward);
      await _persist();
      return true;
    } catch (e) {
      mission.rewardClaimed = false;
      _notify();
      debugPrint('claimReward failed, rolled back: $e');
      return false;
    }
  }

  Future<void> refreshMissions() async {
    _missions = _buildDailyMissions();
    await _persist();
    _notify();
  }

  // ---------------------------------------------------------------------------
  // Mission catalog — one entry per possible daily mission.
  // Each day a random subset of 3 is drawn (always one from each core type,
  // with camera appearing when it wins its slot against quizPlay/speakPractice).
  // ---------------------------------------------------------------------------

  static final List<DailyMission> _missionCatalog = [
    // ── Speak Practice ───────────────────────────────────────────────────────
    DailyMission(
      id: 'mission_speak_confidence',
      title: 'דברו עם ביטחון',
      description: 'הצליחו באמירת 3 מילים בקול כדי לחזק את ההגייה.',
      target: 3,
      reward: 25,
      type: DailyMissionType.speakPractice,
    ),
    DailyMission(
      id: 'mission_speak_five',
      title: 'חמש מילים בקול',
      description: 'אמרו 5 מילים בקול רם ובצורה נכונה.',
      target: 5,
      reward: 40,
      type: DailyMissionType.speakPractice,
    ),

    // ── Lightning Round ───────────────────────────────────────────────────────
    DailyMission(
      id: 'mission_lightning_duo',
      title: 'ריצת ברק',
      description: 'סיימו 2 סבבי Lightning כדי לחמם את הזיכרון המילולי.',
      target: 2,
      reward: 35,
      type: DailyMissionType.lightningRound,
    ),
    DailyMission(
      id: 'mission_lightning_solo',
      title: 'ניצוץ ברק',
      description: 'השלימו סבב Lightning אחד מלא.',
      target: 1,
      reward: 20,
      type: DailyMissionType.lightningRound,
    ),

    // ── Quiz Play ─────────────────────────────────────────────────────────────
    DailyMission(
      id: 'mission_quiz_master',
      title: 'אלוף החידונים',
      description: 'שחקו סשן אחד של משחק החידון בתמונות.',
      target: 1,
      reward: 20,
      type: DailyMissionType.quizPlay,
    ),
    DailyMission(
      id: 'mission_quiz_trio',
      title: 'שלישיית חידונים',
      description: 'השלימו 3 שאלות חידון נכונות.',
      target: 3,
      reward: 30,
      type: DailyMissionType.quizPlay,
    ),

    // ── Camera ────────────────────────────────────────────────────────────────
    DailyMission(
      id: 'mission_camera_explorer',
      title: 'חוקר תמונות',
      description: 'צלמו עצם שלמדתם — בדקו אם ה-AI מזהה אותו!',
      target: 1,
      reward: 30,
      type: DailyMissionType.camera,
    ),
    DailyMission(
      id: 'mission_camera_triple',
      title: 'צלם מהיר',
      description: 'צלמו 3 עצמים שונים והאמתו אותם דרך המצלמה.',
      target: 3,
      reward: 50,
      type: DailyMissionType.camera,
    ),

    // ── SRS Review (new) ──────────────────────────────────────────────────────
    DailyMission(
      id: 'mission_srs_review_5',
      title: 'חזרה חכמה',
      description: 'בצעו חזרה על 5 מילים שמחכות לסקירה.',
      target: 5,
      reward: 35,
      type: DailyMissionType.srsReview,
    ),
    DailyMission(
      id: 'mission_srs_review_10',
      title: 'זיכרון לטווח ארוך',
      description: 'בצעו חזרה על 10 מילים מהחזרה המדורגת.',
      target: 10,
      reward: 55,
      type: DailyMissionType.srsReview,
    ),

    // ── Story Read (new) ──────────────────────────────────────────────────────
    DailyMission(
      id: 'mission_story_read',
      title: 'שעת סיפור',
      description: 'קראו סיפור אינטראקטיבי אחד עם ספארק.',
      target: 1,
      reward: 30,
      type: DailyMissionType.storyRead,
    ),

    // ── Pronunciation Perfect (new) ───────────────────────────────────────────
    DailyMission(
      id: 'mission_pronunciation_3star',
      title: 'הגייה מושלמת',
      description: 'קיבלו 3 כוכבים על הגייה של מילה אחת.',
      target: 1,
      reward: 25,
      type: DailyMissionType.pronunciationPerfect,
    ),
    DailyMission(
      id: 'mission_pronunciation_3star_triple',
      title: 'שלוש הגיות מושלמות',
      description: 'קיבלו 3 כוכבים על הגייה של 3 מילים שונות.',
      target: 3,
      reward: 50,
      type: DailyMissionType.pronunciationPerfect,
    ),
  ];

  /// Builds today's mission set — 3 missions from different type families.
  ///
  /// Slot assignment:
  ///   1. Always: speakPractice OR pronunciationPerfect (rotate).
  ///   2. Always: lightningRound OR srsReview (rotate).
  ///   3. Rotating: quizPlay / camera / storyRead (equal probability).
  List<DailyMission> _buildDailyMissions() {
    final rng = math.Random();

    // Slot 1: voice practice
    final slot1Pool = _missionCatalog
        .where((m) =>
            m.type == DailyMissionType.speakPractice ||
            m.type == DailyMissionType.pronunciationPerfect)
        .toList();
    final slot1 = slot1Pool[rng.nextInt(slot1Pool.length)];

    // Slot 2: active learning
    final slot2Pool = _missionCatalog
        .where((m) =>
            m.type == DailyMissionType.lightningRound ||
            m.type == DailyMissionType.srsReview)
        .toList();
    final slot2 = slot2Pool[rng.nextInt(slot2Pool.length)];

    // Slot 3: exploratory
    final slot3Roll = rng.nextInt(3); // 0=quiz, 1=camera, 2=story
    final DailyMissionType slot3Type;
    switch (slot3Roll) {
      case 0:
        slot3Type = DailyMissionType.quizPlay;
      case 1:
        slot3Type = DailyMissionType.camera;
      default:
        slot3Type = DailyMissionType.storyRead;
    }
    final slot3Pool =
        _missionCatalog.where((m) => m.type == slot3Type).toList();
    final slot3 = slot3Pool[rng.nextInt(slot3Pool.length)];

    // Return fresh copies so progress always starts at 0.
    return [slot1, slot2, slot3]
        .map(
          (m) => DailyMission(
            id: m.id,
            title: m.title,
            description: m.description,
            target: m.target,
            reward: m.reward,
            type: m.type,
          ),
        )
        .toList(growable: false);
  }

  // Keep the old name as a private alias used during initialize()
  List<DailyMission> _buildDefaultMissions() => _buildDailyMissions();

  /// Bumps the completion streak if all missions just became completed.
  /// Safe to call multiple times — only increments once per day.
  Future<void> _checkAndBumpStreak() async {
    if (!allCompleted) return;
    final prefs = await SharedPreferences.getInstance();
    final todayKey = _todayKey();
    final String? rawStreak = prefs.getString(_missionStreakKey);
    // Already recorded today?
    if (rawStreak != null && rawStreak.startsWith('$todayKey|')) return;

    // Was yesterday in streak?
    final yesterday = _yesterdayKey();
    int newCount = 1;
    if (rawStreak != null) {
      final parts = rawStreak.split('|');
      if (parts.length == 2 && parts[0] == yesterday) {
        newCount = (int.tryParse(parts[1]) ?? 0) + 1;
      }
    }
    _completionStreakDays = newCount;
    await prefs.setString(_missionStreakKey, '$todayKey|$newCount');
    onAllCompleted?.call(newCount);
  }

  Future<void> _persist([
    SharedPreferences? existingPrefs,
    String? overrideDate,
  ]) async {
    final prefs = existingPrefs ?? await SharedPreferences.getInstance();
    final String todayKey = overrideDate ?? _todayKey();

    final List<String> serialized =
        _missions.map((mission) => mission.toJson()).toList(growable: false);
    await prefs.setString(_prefDateKey, todayKey);
    await prefs.setStringList(_prefMissionsKey, serialized);
  }

  String _todayKey() => _dateKey(DateTime.now());

  String _yesterdayKey() =>
      _dateKey(DateTime.now().subtract(const Duration(days: 1)));

  String _dateKey(DateTime d) =>
      '${d.year.toString().padLeft(4, '0')}-'
      '${d.month.toString().padLeft(2, '0')}-'
      '${d.day.toString().padLeft(2, '0')}';

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }

}