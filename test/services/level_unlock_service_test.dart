import 'package:english_learning_app/models/level_data.dart';
import 'package:english_learning_app/models/word_data.dart';
import 'package:english_learning_app/services/level_progress_service.dart';
import 'package:english_learning_app/services/level_unlock_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  test('unlocks first level and next after previous completion', () async {
    final progress = LevelProgressService();
    const userId = 'child_1';

    final levels = [
      LevelData(
        id: 'level_a',
        name: 'A',
        words: [WordData(word: 'One'), WordData(word: 'Two')],
      ),
      LevelData(
        id: 'level_b',
        name: 'B',
        words: [WordData(word: 'Three')],
      ),
    ];

    final unlockService = LevelUnlockService(levelProgressService: progress);
    await unlockService.applyUnlockStatuses(levels, userId: userId);

    expect(levels[0].isUnlocked, isTrue);
    expect(levels[1].isUnlocked, isFalse);

    await progress.markWordCompleted(
      userId,
      'level_a',
      'One',
      isLocalUser: true,
    );
    await progress.markWordCompleted(
      userId,
      'level_a',
      'Two',
      isLocalUser: true,
    );

    await unlockService.applyUnlockStatuses(levels, userId: userId);
    expect(levels[1].isUnlocked, isTrue);

    final unlocked = unlockService.unlockedLevels(levels);
    expect(unlocked.map((l) => l.id), ['level_a', 'level_b']);
  });
}
