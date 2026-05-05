import 'package:english_learning_app/models/word_data.dart';
import 'package:english_learning_app/services/word_mastery_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('WordMasteryService', () {
    late SharedPreferences prefs;
    late WordMasteryService service;

    setUp(() async {
      SharedPreferences.setMockInitialValues(<String, Object>{});
      prefs = await SharedPreferences.getInstance();
      service = WordMasteryService(prefs: prefs);
    });

    test('returns default entry when no data exists', () async {
      final entry = await service.getMastery(
        userId: 'user1',
        levelId: 'level1',
        word: 'Apple',
      );

      expect(entry.masteryLevel, 0.0);
      expect(entry.lastReviewed, isNull);
    });

    test('recordSuccessfulReview increases mastery and sets lastReviewed',
        () async {
      final before = await service.getMastery(
        userId: 'user1',
        levelId: 'level1',
        word: 'Apple',
      );
      expect(before.masteryLevel, 0.0);

      final after = await service.recordSuccessfulReview(
        userId: 'user1',
        levelId: 'level1',
        word: 'Apple',
        delta: 0.5,
      );

      expect(after.masteryLevel, closeTo(0.5, 0.0001));
      expect(after.lastReviewed, isNotNull);
    });

    test('setMastery clamps values into range and persists', () async {
      final entry = await service.setMastery(
        userId: 'user1',
        levelId: 'level1',
        word: 'Banana',
        masteryLevel: 2.0,
      );

      expect(entry.masteryLevel, 1.0);

      final loaded = await service.getMastery(
        userId: 'user1',
        levelId: 'level1',
        word: 'Banana',
      );
      expect(loaded.masteryLevel, 1.0);
    });

    test('applyToWord merges mastery into WordData', () async {
      final base = WordData(
        word: 'Cat',
        searchHint: 'cute cat',
        isCompleted: true,
      );

      final mastery = await service.setMastery(
        userId: 'user1',
        levelId: 'level1',
        word: 'Cat',
        masteryLevel: 0.8,
      );

      final merged = service.applyToWord(base, mastery);

      expect(merged.word, 'Cat');
      expect(merged.searchHint, 'cute cat');
      expect(merged.isCompleted, true);
      expect(merged.masteryLevel, closeTo(0.8, 0.0001));
      expect(merged.lastReviewed, isNotNull);
    });
  });
}

