import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/daily_mission.dart';

class DailyMissionProvider with ChangeNotifier {
  DailyMissionProvider();

  static const String _prefDateKey = 'daily_missions_date';
  static const String _prefMissionsKey = 'daily_missions_payload';

  bool _initialized = false;
  List<DailyMission> _missions = <DailyMission>[];

  bool get isInitialized => _initialized;
  List<DailyMission> get missions => List<DailyMission>.unmodifiable(_missions);

  Future<void> initialize() async {
    final prefs = await SharedPreferences.getInstance();
    final String todayKey = _todayKey();
    final String? storedDate = prefs.getString(_prefDateKey);

    if (storedDate == todayKey) {
      final List<String>? storedMissions = prefs.getStringList(
        _prefMissionsKey,
      );
      if (storedMissions != null && storedMissions.isNotEmpty) {
        _missions = storedMissions
            .map((json) => DailyMission.fromJson(json))
            .toList(growable: false);
      } else {
        _missions = _buildDefaultMissions();
        await _persist(prefs, todayKey);
      }
    } else {
      _missions = _buildDefaultMissions();
      await _persist(prefs, todayKey);
    }

    _initialized = true;
    notifyListeners();
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
    notifyListeners();
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
    notifyListeners();
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

    mission.rewardClaimed = true;
    await rewardCallback(mission.reward);
    await _persist();
    notifyListeners();
    return true;
  }

  Future<void> refreshMissions() async {
    _missions = _buildDailyMissions();
    await _persist();
    notifyListeners();
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
  ];

  /// Builds today's mission set: one mission per type, chosen randomly from the
  /// catalog.  Camera competes with quizPlay for its slot — it appears ~50 % of
  /// the time so the experience stays fresh without being overwhelming.
  List<DailyMission> _buildDailyMissions() {
    final rng = math.Random();

    // Pick one speakPractice mission
    final speakPool = _missionCatalog
        .where((m) => m.type == DailyMissionType.speakPractice)
        .toList();
    final speak = speakPool[rng.nextInt(speakPool.length)];

    // Pick one lightningRound mission
    final lightningPool = _missionCatalog
        .where((m) => m.type == DailyMissionType.lightningRound)
        .toList();
    final lightning = lightningPool[rng.nextInt(lightningPool.length)];

    // Third slot: camera (50 %) or quizPlay (50 %)
    final DailyMission third;
    if (rng.nextBool()) {
      final cameraPool = _missionCatalog
          .where((m) => m.type == DailyMissionType.camera)
          .toList();
      third = cameraPool[rng.nextInt(cameraPool.length)];
    } else {
      final quizPool = _missionCatalog
          .where((m) => m.type == DailyMissionType.quizPlay)
          .toList();
      third = quizPool[rng.nextInt(quizPool.length)];
    }

    // Return fresh copies so progress always starts at 0
    return [speak, lightning, third]
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

  Future<void> _persist([
    SharedPreferences? existingPrefs,
    String? overrideDate,
  ]) async {
    final prefs = existingPrefs ?? await SharedPreferences.getInstance();
    final String todayKey = overrideDate ?? _todayKey();

    final List<String> serialized = _missions
        .map((mission) => mission.toJson())
        .toList(growable: false);
    await prefs.setString(_prefDateKey, todayKey);
    await prefs.setStringList(_prefMissionsKey, serialized);
  }

  String _todayKey() {
    final DateTime now = DateTime.now();
    return '${now.year.toString().padLeft(4, '0')}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';
  }
}
