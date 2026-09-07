import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/level_data.dart';

/// Result of [MapUnlockCelebrationService.resolvePendingUnlock] — describes a
/// map level that has been unlocked but not yet celebrated for the learner.
@immutable
class MapUnlockResult {
  const MapUnlockResult({
    required this.newLevel,
    required this.previousLevel,
    required this.levelIndex,
  });

  /// The highest unlocked level number (1-based) that should be celebrated.
  final int newLevel;

  /// The level number that was previously acknowledged.
  final int previousLevel;

  /// Zero-based index of [newLevel] in the level list — handy for scrolling /
  /// focusing the map on the freshly unlocked marker.
  final int levelIndex;

  @override
  bool operator ==(Object other) =>
      other is MapUnlockResult &&
      other.newLevel == newLevel &&
      other.previousLevel == previousLevel &&
      other.levelIndex == levelIndex;

  @override
  int get hashCode => Object.hash(newLevel, previousLevel, levelIndex);

  @override
  String toString() =>
      'MapUnlockResult(newLevel: $newLevel, previousLevel: $previousLevel, '
      'levelIndex: $levelIndex)';
}

/// Tracks which map level the learner has already seen a "new level unlocked"
/// celebration for, so the celebration fires exactly once per newly unlocked
/// level and never loops on subsequent map loads.
///
/// Persistence is namespaced per profile id (`user_<id>_...`) to match the rest
/// of the per-child progress state (see CLAUDE.md §2.3). Level 1 is unlocked
/// from the start, so [firstLevel] is both the default and the floor.
class MapUnlockCelebrationService {
  MapUnlockCelebrationService({SharedPreferences? prefs}) : _prefs = prefs;

  final SharedPreferences? _prefs;

  /// Level 1 is always unlocked and never triggers a celebration.
  static const int firstLevel = 1;

  Future<SharedPreferences> get _prefsInstance async =>
      _prefs ?? await SharedPreferences.getInstance();

  String _key(String userId) => 'user_${userId}_highest_acknowledged_level';

  /// The highest map level the learner has already celebrated unlocking.
  /// Defaults to [firstLevel] and never returns a value below it.
  Future<int> highestAcknowledgedLevel(String userId) async {
    try {
      final prefs = await _prefsInstance;
      final value = prefs.getInt(_key(userId)) ?? firstLevel;
      return value < firstLevel ? firstLevel : value;
    } catch (e) {
      debugPrint('MapUnlockCelebrationService.highestAcknowledgedLevel: $e');
      return firstLevel;
    }
  }

  /// Persists [level] as the highest acknowledged level. Monotonic — values that
  /// would move the marker backwards (e.g. a stale caller, a profile switch) are
  /// ignored so a celebration is never replayed.
  Future<void> setHighestAcknowledgedLevel(String userId, int level) async {
    try {
      final prefs = await _prefsInstance;
      final current = prefs.getInt(_key(userId)) ?? firstLevel;
      if (level <= current) return;
      await prefs.setInt(_key(userId), level);
    } catch (e) {
      debugPrint('MapUnlockCelebrationService.setHighestAcknowledgedLevel: $e');
    }
  }

  /// Number of levels currently unlocked for the learner. Unlocking is
  /// sequential from the start of the list, so this doubles as the highest
  /// unlocked level number (1-based). A gap (locked level followed by an
  /// unlocked one) stops the count defensively.
  int highestUnlockedLevel(List<LevelData> levels) {
    var count = 0;
    for (final level in levels) {
      if (!level.isUnlocked) break;
      count++;
    }
    return count;
  }

  /// Resolves whether an unlock celebration is due for [userId] given the
  /// current [levels] (which must already have their `isUnlocked` flags
  /// applied). Returns `null` when nothing new is unlocked.
  Future<MapUnlockResult?> resolvePendingUnlock(
    String userId,
    List<LevelData> levels,
  ) async {
    final unlocked = highestUnlockedLevel(levels);
    final acknowledged = await highestAcknowledgedLevel(userId);
    if (unlocked <= acknowledged) return null;
    return MapUnlockResult(
      newLevel: unlocked,
      previousLevel: acknowledged,
      levelIndex: unlocked - 1,
    );
  }
}
