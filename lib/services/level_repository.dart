import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import '../models/level_data.dart';
import '../models/word_data.dart';

class LevelRepository {
  LevelRepository({AssetBundle? bundle}) : _bundle = bundle ?? rootBundle;

  final AssetBundle _bundle;
  Map<String, List<WordData>> _wordsByLevelId = <String, List<WordData>>{};

  /// Loads level metadata. When [lazyWords] is true, [LevelData.words] are empty
  /// until [loadWordsForLevel] is called — faster map startup.
  Future<List<LevelData>> loadLevels({
    String assetPath = 'assets/data/levels.json',
    bool lazyWords = false,
  }) async {
    try {
      final raw = await _bundle.loadString(assetPath);
      final decoded = jsonDecode(raw) as Map<String, dynamic>;
      final levelMaps = (decoded['levels'] as List<dynamic>? ?? [])
          .whereType<Map<String, dynamic>>()
          .toList();

      _wordsByLevelId = <String, List<WordData>>{};
      final levels = <LevelData>[];

      for (final json in levelMaps) {
        final id = json['id'] as String?;
        if (id == null || id.isEmpty) {
          continue;
        }

        final wordsJson = (json['words'] as List<dynamic>? ?? [])
            .whereType<Map<String, dynamic>>()
            .map(WordData.fromJson)
            .toList();
        _wordsByLevelId[id] = wordsJson;

        if (lazyWords) {
          final summaryJson = Map<String, dynamic>.from(json)..['words'] = [];
          levels.add(LevelData.fromJson(summaryJson));
        } else {
          levels.add(LevelData.fromJson(json));
        }
      }

      return levels;
    } catch (e, stack) {
      debugPrint('Failed to load levels from $assetPath: $e');
      debugPrint('$stack');
      return const <LevelData>[];
    }
  }

  /// Hydrates words for a level previously loaded with [lazyWords].
  Future<List<WordData>> loadWordsForLevel(String levelId) async {
    return List<WordData>.from(
      _wordsByLevelId[levelId] ?? const <WordData>[],
    );
  }

  /// True when [levelId] is the last level in its chapter.
  ///
  /// Placeholder until P-09 adds chapter metadata to [levels.json].
  Future<bool> isLastOfChapter(String levelId) async {
    final levels = await loadLevels();
    if (levels.isEmpty || !levels.any((l) => l.id == levelId)) {
      return false;
    }
    // P-09: group by chapterId and return true for the final level in each chapter.
    return false;
  }
}
