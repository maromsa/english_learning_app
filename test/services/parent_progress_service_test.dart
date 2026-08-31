import 'dart:convert';

import 'package:english_learning_app/services/level_repository.dart';
import 'package:english_learning_app/services/parent_progress_service.dart';
import 'package:english_learning_app/services/word_mastery_service.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../support/fake_firebase_services.dart';

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
        levelProgressService: fakeLevelProgressService(),
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

    test(
        'reports words due today, and the all-time longest SRS streak even '
        "when that word isn't due", () async {
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
        {"word": "Orange"}
      ]
    },
    {
      "id": "animals",
      "name": "Animals",
      "words": [
        {"word": "Cat"},
        {"word": "Dog"}
      ]
    }
  ]
}
''',
      });

      final wordMasteryService = WordMasteryService(prefs: prefs);
      final now = DateTime.now();

      // "Orange": a single 1-star grade -> streak 0, due since yesterday.
      await wordMasteryService.recordPronunciationScore(
        userId: 'child1',
        levelId: 'fruits',
        word: 'Orange',
        stars: 1,
        reviewedAt: now.subtract(const Duration(days: 2)),
      );

      // "Cat": two 3-star grades in a row -> streak 2, also due by now.
      await wordMasteryService.recordPronunciationScore(
        userId: 'child1',
        levelId: 'animals',
        word: 'Cat',
        stars: 3,
        reviewedAt: now.subtract(const Duration(days: 10)),
      );
      await wordMasteryService.recordPronunciationScore(
        userId: 'child1',
        levelId: 'animals',
        word: 'Cat',
        stars: 3,
        reviewedAt: now.subtract(const Duration(days: 9)),
      );

      // "Dog": five 3-star grades in a row -> streak 5 (30-day interval),
      // graded just now — this is the child's best-ever streak, but it is
      // NOT due for a long time. longestSrsStreak must still report it.
      for (var i = 0; i < 5; i++) {
        await wordMasteryService.recordPronunciationScore(
          userId: 'child1',
          levelId: 'animals',
          word: 'Dog',
          stars: 3,
          reviewedAt: now.subtract(Duration(days: 5 - i)),
        );
      }

      final service = ParentProgressService(
        prefs: prefs,
        levelRepository: LevelRepository(bundle: bundle),
        levelProgressService: fakeLevelProgressService(),
        wordMasteryService: wordMasteryService,
      );

      final stats = await service.loadStats(
        userId: 'child1',
        childName: 'Noa',
        isLocalUser: false,
      );

      // "Dog" isn't in the due list (its 30-day interval hasn't elapsed)...
      expect(stats.wordsDueToday, 2);
      // ...but its streak of 5 still wins as the all-time high.
      expect(stats.longestSrsStreak, 5);
    });

    test('reports zero SRS stats when nothing has ever been graded', () async {
      const assetPath = 'assets/data/levels.json';
      final bundle = _FakeBundle({
        assetPath: '{"levels": []}',
      });

      final service = ParentProgressService(
        prefs: prefs,
        levelRepository: LevelRepository(bundle: bundle),
        levelProgressService: fakeLevelProgressService(),
        wordMasteryService: WordMasteryService(prefs: prefs),
      );

      final stats = await service.loadStats(
        userId: 'child1',
        childName: 'Noa',
        isLocalUser: false,
      );

      expect(stats.wordsDueToday, 0);
      expect(stats.longestSrsStreak, 0);
    });
  });
}
