import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import '../models/level_data.dart';

class LevelRepository {
  LevelRepository({AssetBundle? bundle}) : _bundle = bundle ?? rootBundle;

  final AssetBundle _bundle;

  Future<List<LevelData>> loadLevels({
    String assetPath = 'assets/data/levels.json',
  }) async {
    try {
      final raw = await _bundle.loadString(assetPath);
      final decoded = jsonDecode(raw) as Map<String, dynamic>;
      final levels = (decoded['levels'] as List<dynamic>? ?? [])
          .whereType<Map<String, dynamic>>()
          .map(LevelData.fromJson)
          .toList();
      return levels;
    } catch (e, stack) {
      debugPrint('Failed to load levels from $assetPath: $e');
      debugPrint('$stack');
      return const <LevelData>[];
    }
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
