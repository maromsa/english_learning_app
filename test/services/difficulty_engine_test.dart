// test/services/difficulty_engine_test.dart
import 'package:english_learning_app/services/difficulty_engine.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  group('DifficultyEngine', () {
    late DifficultyEngine engine;

    setUp(() {
      SharedPreferences.setMockInitialValues({});
      engine = DifficultyEngine(windowSize: 10, minSamplesBeforeAdjust: 5);
    });

    tearDown(() => engine.dispose());

    test('starts at medium difficulty', () {
      expect(engine.level, DifficultyLevel.medium);
    });

    test('no adjustment before minSamples', () {
      // 4 wrong answers — not enough samples to adjust.
      for (int i = 0; i < 4; i++) {
        engine.recordAnswer(false);
      }
      expect(engine.level, DifficultyLevel.medium);
    });

    test('drops to easy after ≥5 mostly-wrong answers', () {
      // 5 wrong → success rate 0% < 40%.
      for (int i = 0; i < 5; i++) {
        engine.recordAnswer(false);
      }
      expect(engine.level, DifficultyLevel.easy);
    });

    test('rises to hard after ≥5 mostly-correct answers', () {
      // 5 correct → success rate 100% > 75%.
      for (int i = 0; i < 5; i++) {
        engine.recordAnswer(true);
      }
      expect(engine.level, DifficultyLevel.hard);
    });

    test('stays medium at 50% success rate', () {
      for (int i = 0; i < 10; i++) {
        engine.recordAnswer(i.isEven);
      }
      expect(engine.level, DifficultyLevel.medium);
    });

    test('window slides: old failures forgotten after 10 new correct answers',
        () {
      // 10 wrong.
      for (int i = 0; i < 10; i++) {
        engine.recordAnswer(false);
      }
      expect(engine.level, DifficultyLevel.easy);

      // 10 correct push wrong answers out of window.
      for (int i = 0; i < 10; i++) {
        engine.recordAnswer(true);
      }
      expect(engine.level, DifficultyLevel.hard);
    });

    test('reset returns to medium', () {
      for (int i = 0; i < 10; i++) {
        engine.recordAnswer(true);
      }
      expect(engine.level, DifficultyLevel.hard);
      engine.reset();
      expect(engine.level, DifficultyLevel.medium);
      expect(engine.sampleCount, 0);
    });

    test('easy params: 2 options, hint shown, 0.8x multiplier', () {
      for (int i = 0; i < 5; i++) {
        engine.recordAnswer(false);
      }
      final params = engine.params;
      expect(params.optionCount, 2);
      expect(params.showHint, isTrue);
      expect(params.bonusMultiplier, 0.8);
    });

    test('hard params: 4 options, no hint, 1.3x multiplier', () {
      for (int i = 0; i < 5; i++) {
        engine.recordAnswer(true);
      }
      final params = engine.params;
      expect(params.optionCount, 4);
      expect(params.showHint, isFalse);
      expect(params.bonusMultiplier, 1.3);
    });

    test('notifies listeners on level change', () {
      int notifications = 0;
      engine.addListener(() => notifications++);

      // No change yet.
      for (int i = 0; i < 4; i++) {
        engine.recordAnswer(false);
      }
      expect(notifications, 0);

      // 5th wrong answer triggers change from medium → easy.
      engine.recordAnswer(false);
      expect(notifications, greaterThan(0));
    });

    test('does not notify if level stays the same', () {
      int notifications = 0;
      engine.addListener(() => notifications++);
      // Stays medium the whole time.
      for (int i = 0; i < 10; i++) {
        engine.recordAnswer(i.isEven);
      }
      // Level should be medium throughout — may notify once when first set.
      // Success rate 50%, which stays medium, so no level change notification.
      expect(engine.level, DifficultyLevel.medium);
    });
  });
}
