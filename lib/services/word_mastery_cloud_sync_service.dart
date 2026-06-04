import 'package:flutter/foundation.dart';

import '../models/player_data.dart';
import '../models/word_progress_entry.dart';
import 'user_data_service.dart';
import 'word_mastery_service.dart';

/// Mirrors local word mastery / pronunciation scores to Firestore.
///
/// All methods are offline-first: failures are logged and never rethrown.
class WordMasteryCloudSyncService {
  WordMasteryCloudSyncService({
    UserDataService? userDataService,
  }) : _userDataService = userDataService ?? UserDataService();

  final UserDataService _userDataService;

  /// Pushes a single word's progress to Firestore for authenticated users.
  Future<void> pushWordProgress({
    required String userId,
    required String levelId,
    required String word,
    required WordMasteryEntry mastery,
    bool markWordCompleted = false,
  }) async {
    try {
      final progress = WordProgressEntry.fromMastery(
        wordId: word,
        masteryLevel: mastery.masteryLevel,
        bestPronunciationStars: mastery.bestPronunciationStars,
        isCompleted: markWordCompleted,
      );
      await _userDataService.upsertWordProgress(
        userId: userId,
        levelId: levelId,
        word: word,
        progress: progress,
        markWordCompleted: markWordCompleted,
      );
    } catch (error, stackTrace) {
      debugPrint(
        'WordMasteryCloudSyncService: push failed '
        'user=$userId level=$levelId word=$word: $error',
      );
      debugPrint('$stackTrace');
    }
  }

  /// Loads cloud word progress for a level and merges into local storage.
  Future<void> mergeCloudIntoLocal({
    required String userId,
    required String levelId,
    required WordMasteryService wordMasteryService,
    required Future<Set<String>> Function() loadLocalCompletedWords,
    required Future<void> Function(Set<String> words) saveLocalCompletedWords,
  }) async {
    try {
      final cloudLevel =
          await _userDataService.getLevelProgress(userId, levelId);
      if (cloudLevel == null) return;

      final localCompleted = await loadLocalCompletedWords();
      var completedChanged = false;

      for (final entry in cloudLevel.wordProgress.values) {
        if (entry.wordId.isEmpty) continue;

        final localMastery = await wordMasteryService.getMastery(
          userId: userId,
          levelId: levelId,
          word: entry.wordId,
        );

        final shouldUpdateMastery =
            entry.bestPronunciationStars > localMastery.bestPronunciationStars ||
                entry.isMastered && localMastery.masteryLevel < 1.0;

        if (shouldUpdateMastery) {
          if (entry.isMastered || entry.bestPronunciationStars >= 3) {
            await wordMasteryService.setMastery(
              userId: userId,
              levelId: levelId,
              word: entry.wordId,
              masteryLevel: 1.0,
            );
          } else if (entry.bestPronunciationStars > 0) {
            await wordMasteryService.recordPronunciationScore(
              userId: userId,
              levelId: levelId,
              word: entry.wordId,
              stars: entry.bestPronunciationStars,
            );
          }
        }

        if (entry.isCompleted || cloudLevel.wordsCompleted[entry.wordId] == true) {
          if (!localCompleted.contains(entry.wordId)) {
            localCompleted.add(entry.wordId);
            completedChanged = true;
          }
        }
      }

      for (final word in cloudLevel.wordsCompleted.keys) {
        if (cloudLevel.wordsCompleted[word] == true &&
            !localCompleted.contains(word)) {
          localCompleted.add(word);
          completedChanged = true;
        }
      }

      if (completedChanged) {
        await saveLocalCompletedWords(localCompleted);
      }
    } catch (error, stackTrace) {
      debugPrint(
        'WordMasteryCloudSyncService: merge failed '
        'user=$userId level=$levelId: $error',
      );
      debugPrint('$stackTrace');
    }
  }
}
