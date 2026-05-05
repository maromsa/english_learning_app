import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'map_bridge_service.dart';
import 'word_mastery_service.dart';

/// Service for managing level progress - tracks which words are completed in
/// each level and coordinates mastery + map bridge events.
class LevelProgressService {
  LevelProgressService({
    WordMasteryService? wordMasteryService,
    MapBridgeService? mapBridgeService,
  })  : _wordMasteryService = wordMasteryService ?? WordMasteryService(),
        _mapBridgeService = mapBridgeService ?? MapBridgeService.instance;

  final WordMasteryService _wordMasteryService;
  final MapBridgeService _mapBridgeService;

  /// Get completed words for a specific level and user
  Future<Set<String>> getCompletedWords(String userId, String levelId,
      {bool isLocalUser = false}) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final key = isLocalUser
          ? 'local_user_${userId}_level_${levelId}_completed_words'
          : 'user_${userId}_level_${levelId}_completed_words';
      final wordsJson = prefs.getString(key);
      if (wordsJson == null || wordsJson.isEmpty) {
        debugPrint('No completed words found for level $levelId (key: $key)');
        return <String>{};
      }
      final List<dynamic> wordsList = jsonDecode(wordsJson);
      final words = wordsList.map((w) => w as String).toSet();
      debugPrint(
          'Loaded completed words for level $levelId: $words (key: $key)');
      return words;
    } catch (e) {
      debugPrint('Error loading completed words for level $levelId: $e');
      return <String>{};
    }
  }

  /// Mark a word as completed in a level.
  ///
  /// This keeps the existing completion persistence intact and additionally:
  /// - Records a strong mastery review signal for the word.
  /// - Emits a bridge event so that the 3D map can react (e.g. spawn an asset).
  Future<void> markWordCompleted(
    String userId,
    String levelId,
    String word, {
    bool isLocalUser = false,
  }) async {
    try {
      final completedWords =
          await getCompletedWords(userId, levelId, isLocalUser: isLocalUser);
      completedWords.add(word);
      await _saveCompletedWords(
        userId,
        levelId,
        completedWords,
        isLocalUser: isLocalUser,
      );

      // Record mastery and notify the map bridge; failures here should never
      // break core progress persistence.
      try {
        final masteryEntry = await _wordMasteryService.recordSuccessfulReview(
          userId: userId,
          levelId: levelId,
          word: word,
        );
        _mapBridgeService.emitWordMastered(
          WordMasteredEvent(
            userId: userId,
            levelId: levelId,
            word: word,
            masteryLevel: masteryEntry.masteryLevel,
          ),
        );
      } catch (error, stackTrace) {
        debugPrint(
          'LevelProgressService: non-fatal error updating mastery/bridge for '
          'level=$levelId, word=$word: $error',
        );
        debugPrint('$stackTrace');
      }
    } catch (e) {
      debugPrint('Error marking word as completed: $e');
    }
  }

  /// Check if a word is completed
  Future<bool> isWordCompleted(String userId, String levelId, String word,
      {bool isLocalUser = false}) async {
    final completedWords =
        await getCompletedWords(userId, levelId, isLocalUser: isLocalUser);
    return completedWords.contains(word);
  }

  /// Get completion percentage for a level
  Future<double> getCompletionPercentage(
      String userId, String levelId, int totalWords,
      {bool isLocalUser = false}) async {
    if (totalWords == 0) return 0.0;
    final completedWords =
        await getCompletedWords(userId, levelId, isLocalUser: isLocalUser);
    return (completedWords.length / totalWords).clamp(0.0, 1.0);
  }

  /// Check if level is fully completed (all words done)
  Future<bool> isLevelCompleted(String userId, String levelId, int totalWords,
      {bool isLocalUser = false}) async {
    final completedWords =
        await getCompletedWords(userId, levelId, isLocalUser: isLocalUser);
    return completedWords.length >= totalWords;
  }

  /// Save completed words for a level
  Future<void> _saveCompletedWords(
      String userId, String levelId, Set<String> words,
      {bool isLocalUser = false}) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final key = isLocalUser
          ? 'local_user_${userId}_level_${levelId}_completed_words'
          : 'user_${userId}_level_${levelId}_completed_words';
      final wordsJson = jsonEncode(words.toList());
      await prefs.setString(key, wordsJson);
      debugPrint(
          'Saved completed words for level $levelId: $words (key: $key)');
    } catch (e) {
      debugPrint('Error saving completed words: $e');
      rethrow;
    }
  }

  /// Reset progress for a level (for testing/debugging)
  Future<void> resetLevelProgress(String userId, String levelId,
      {bool isLocalUser = false}) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final key = isLocalUser
          ? 'local_user_${userId}_level_${levelId}_completed_words'
          : 'user_${userId}_level_${levelId}_completed_words';
      await prefs.remove(key);
    } catch (e) {
      debugPrint('Error resetting level progress: $e');
    }
  }

  /// Get all completed levels for a user
  Future<List<String>> getCompletedLevels(String userId,
      {bool isLocalUser = false}) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final prefix =
          isLocalUser ? 'local_user_${userId}_level_' : 'user_${userId}_level_';
      final suffix = '_completed_words';
      final keys = prefs
          .getKeys()
          .where((key) => key.startsWith(prefix) && key.endsWith(suffix));
      return keys.map((key) {
        final levelId = key.replaceFirst(prefix, '').replaceFirst(suffix, '');
        return levelId;
      }).toList();
    } catch (e) {
      debugPrint('Error getting completed levels: $e');
      return [];
    }
  }
}
