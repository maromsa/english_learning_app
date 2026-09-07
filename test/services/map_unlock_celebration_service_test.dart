import 'package:english_learning_app/models/level_data.dart';
import 'package:english_learning_app/models/word_data.dart';
import 'package:english_learning_app/services/map_unlock_celebration_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  List<LevelData> buildLevels(int count, {required int unlockedCount}) {
    return List<LevelData>.generate(
      count,
      (i) => LevelData(
        id: 'level_$i',
        name: 'Level ${i + 1}',
        words: [WordData(word: 'w$i')],
        isUnlocked: i < unlockedCount,
      ),
    );
  }

  late MapUnlockCelebrationService service;
  const userId = 'child_1';

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    service = MapUnlockCelebrationService();
  });

  group('highestAcknowledgedLevel', () {
    test('defaults to level 1 when nothing is persisted', () async {
      expect(await service.highestAcknowledgedLevel(userId), 1);
    });

    test('never returns a value below the first level', () async {
      SharedPreferences.setMockInitialValues({
        'user_${userId}_highest_acknowledged_level': 0,
      });
      expect(await service.highestAcknowledgedLevel(userId), 1);
    });
  });

  group('highestUnlockedLevel', () {
    test('counts the leading run of unlocked levels', () {
      final levels = buildLevels(6, unlockedCount: 3);
      expect(service.highestUnlockedLevel(levels), 3);
    });

    test('stops at the first locked level even if a later one is unlocked', () {
      final levels = buildLevels(4, unlockedCount: 1)
        ..[3].isUnlocked = true; // gap: [unlocked, locked, locked, unlocked]
      expect(service.highestUnlockedLevel(levels), 1);
    });

    test('is 0 for an empty list', () {
      expect(service.highestUnlockedLevel(const []), 0);
    });
  });

  group('setHighestAcknowledgedLevel', () {
    test('persists a forward move', () async {
      await service.setHighestAcknowledgedLevel(userId, 3);
      expect(await service.highestAcknowledgedLevel(userId), 3);
    });

    test('ignores a backward / equal move (never replays a celebration)',
        () async {
      await service.setHighestAcknowledgedLevel(userId, 4);
      await service.setHighestAcknowledgedLevel(userId, 2);
      await service.setHighestAcknowledgedLevel(userId, 4);
      expect(await service.highestAcknowledgedLevel(userId), 4);
    });

    test('is namespaced per profile id', () async {
      await service.setHighestAcknowledgedLevel('child_a', 5);
      expect(await service.highestAcknowledgedLevel('child_a'), 5);
      expect(await service.highestAcknowledgedLevel('child_b'), 1);
    });
  });

  group('resolvePendingUnlock', () {
    test('fires when actual unlocked > acknowledged', () async {
      final levels = buildLevels(5, unlockedCount: 3);

      final result = await service.resolvePendingUnlock(userId, levels);

      expect(result, isNotNull);
      expect(result!.newLevel, 3);
      expect(result.previousLevel, 1);
      expect(result.levelIndex, 2);
    });

    test('does not fire when unlocked == acknowledged', () async {
      await service.setHighestAcknowledgedLevel(userId, 3);
      final levels = buildLevels(5, unlockedCount: 3);

      expect(await service.resolvePendingUnlock(userId, levels), isNull);
    });

    test('does not fire for the always-unlocked first level', () async {
      final levels = buildLevels(5, unlockedCount: 1);
      expect(await service.resolvePendingUnlock(userId, levels), isNull);
    });

    test('acknowledging the unlock stops it from firing again (no loop)',
        () async {
      final levels = buildLevels(5, unlockedCount: 4);

      final first = await service.resolvePendingUnlock(userId, levels);
      expect(first, isNotNull);
      await service.setHighestAcknowledgedLevel(userId, first!.newLevel);

      // Same map state, checked again — nothing pending now.
      expect(await service.resolvePendingUnlock(userId, levels), isNull);

      // Another level unlocks later — fires once more, then settles.
      levels[4].isUnlocked = true;
      final second = await service.resolvePendingUnlock(userId, levels);
      expect(second!.newLevel, 5);
      await service.setHighestAcknowledgedLevel(userId, second.newLevel);
      expect(await service.resolvePendingUnlock(userId, levels), isNull);
    });
  });
}
