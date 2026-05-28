import '../models/level_data.dart';
import 'level_progress_service.dart';

/// Shared logic for which map levels are unlocked for a learner.
class LevelUnlockService {
  LevelUnlockService({LevelProgressService? levelProgressService})
      : _levelProgressService = levelProgressService ?? LevelProgressService();

  final LevelProgressService _levelProgressService;

  Future<void> applyUnlockStatuses(
    List<LevelData> levels, {
    required String userId,
    bool isLocalUser = true,
  }) async {
    if (levels.isEmpty) {
      return;
    }

    levels.first.isUnlocked = true;
    for (var i = 1; i < levels.length; i++) {
      final previousLevel = levels[i - 1];
      final isPreviousCompleted = await _levelProgressService.isLevelCompleted(
        userId,
        previousLevel.id,
        previousLevel.words.length,
        isLocalUser: isLocalUser,
      );
      levels[i].isUnlocked = isPreviousCompleted;
    }
  }

  List<LevelData> unlockedLevels(List<LevelData> levels) =>
      levels.where((level) => level.isUnlocked).toList(growable: false);
}
