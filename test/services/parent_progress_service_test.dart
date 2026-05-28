import 'dart:convert';

import 'package:english_learning_app/services/level_repository.dart';
import 'package:english_learning_app/services/parent_progress_service.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _FakeBundle extends CachingAssetBundle {
  _FakeBundle(this._responses);

  final Map<String, String> _responses;

  @override
  Future<ByteData> load(String key) async {
    final value = _responses[key];
    if (value == null) {
      throw FlutterError('missing asset: $key');
    }
    final bytes = Uint8List.fromList(value.codeUnits);
    return bytes.buffer.asByteData();
  }

  @override
  Future<String> loadString(String key, {bool cache = true}) async {
    final value = _responses[key];
    if (value == null) {
      throw FlutterError('missing asset: $key');
    }
    return value;
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('ParentProgressService', () {
    late SharedPreferences prefs;

    setUp(() async {
      SharedPreferences.setMockInitialValues({
        'user_child1_daily_reward_streak': 4,
        'user_child1_coins': 120,
        'user_child1_level_fruits_stars': 2,
        'user_child1_level_animals_stars': 1,
        'user_child1_achievement_first_correct': true,
        'user_child1_achievement_streak_5': true,
        'user_child1_daily_missions_payload': [
          jsonEncode({'progress': 3, 'target': 3}),
          jsonEncode({'progress': 1, 'target': 5}),
        ],
        'user_child1_level_fruits_completed_words':
            jsonEncode(['Apple', 'Banana']),
      });
      prefs = await SharedPreferences.getInstance();
    });

    test('aggregates stars, words, streak, coins, missions, achievements',
        () async {
      const assetPath = 'assets/data/levels.json';
      final bundle = _FakeBundle({
        assetPath: '''
{
  "levels": [
    {
      "id": "fruits",
      "name": "Fruits",
      "words": [
        {"word": "Apple"},
        {"word": "Banana"},
        {"word": "Orange"}
      ]
    },
    {
      "id": "animals",
      "name": "Animals",
      "words": [
        {"word": "Cat"}
      ]
    }
  ]
}
''',
      });

      final service = ParentProgressService(
        prefs: prefs,
        levelRepository: LevelRepository(bundle: bundle),
      );

      final stats = await service.loadStats(
        userId: 'child1',
        childName: 'Noa',
        isLocalUser: false,
      );

      expect(stats.childName, 'Noa');
      expect(stats.totalStars, 3);
      expect(stats.dailyStreak, 4);
      expect(stats.wordsPracticed, 2);
      expect(stats.totalWordsInCatalog, 4);
      expect(stats.levelsCompleted, 0);
      expect(stats.totalLevels, 2);
      expect(stats.coins, 120);
      expect(stats.achievementsUnlocked, 2);
      expect(stats.dailyMissionsCompleted, 1);
      expect(stats.dailyMissionsTotal, 2);
    });
  });
}
