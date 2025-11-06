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
      final List<String>? storedMissions = prefs.getStringList(_prefMissionsKey);
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

    final int newProgress = (mission.progress + amount).clamp(0, mission.target);
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

    final int newProgress = (mission.progress + amount).clamp(0, mission.target);
    if (newProgress == mission.progress) {
      return;
    }

    mission.progress = newProgress;
    await _persist();
    notifyListeners();
  }

  Future<bool> claimReward(String missionId, Future<void> Function(int reward) rewardCallback) async {
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
    _missions = _buildDefaultMissions();
    await _persist();
    notifyListeners();
  }

  List<DailyMission> _buildDefaultMissions() {
    return <DailyMission>[
      DailyMission(
        id: 'mission_speak_confidence',
        title: 'דברו עם ביטחון',
        description: 'הצליחו באמירת 3 מילים בקול כדי לחזק את ההגייה.',
        target: 3,
        reward: 25,
        type: DailyMissionType.speakPractice,
      ),
      DailyMission(
        id: 'mission_lightning_duo',
        title: 'ריצת ברק',
        description: 'סיימו 2 סבבי Lightning כדי לחמם את הזיכרון המילולי.',
        target: 2,
        reward: 35,
        type: DailyMissionType.lightningRound,
      ),
      DailyMission(
        id: 'mission_quiz_master',
        title: 'אלוף החידונים',
        description: 'שחקו סשן אחד של משחק החידון בתמונות.',
        target: 1,
        reward: 20,
        type: DailyMissionType.quizPlay,
      ),
    ];
  }

  Future<void> _persist([SharedPreferences? existingPrefs, String? overrideDate]) async {
    final prefs = existingPrefs ?? await SharedPreferences.getInstance();
    final String todayKey = overrideDate ?? _todayKey();

    final List<String> serialized = _missions.map((mission) => mission.toJson()).toList(growable: false);
    await prefs.setString(_prefDateKey, todayKey);
    await prefs.setStringList(_prefMissionsKey, serialized);
  }

  String _todayKey() {
    final DateTime now = DateTime.now();
    return '${now.year.toString().padLeft(4, '0')}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';
  }
}
