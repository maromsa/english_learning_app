import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import '../models/level_data.dart';

class LevelRepository {
  LevelRepository({AssetBundle? bundle}) : _bundle = bundle ?? rootBundle;

  final AssetBundle _bundle;

  Future<List<LevelData>> loadLevels({String assetPath = 'assets/data/levels.json'}) async {
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
}
