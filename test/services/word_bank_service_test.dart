import 'package:english_learning_app/models/learned_word.dart';
import 'package:english_learning_app/services/word_bank_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  group('WordBankService', () {
    test('load returns empty when nothing has been saved', () async {
      final service = WordBankService(
        prefs: await SharedPreferences.getInstance(),
      );
      expect(await service.load('child_1'), isEmpty);
    });

    test('save then load round-trips the bank', () async {
      final service = WordBankService(
        prefs: await SharedPreferences.getInstance(),
      );
      final words = [
        LearnedWord(
          word: 'cat',
          translation: 'חתול',
          dateLearned: DateTime(2026, 9, 16),
        ),
      ];
      await service.save('child_1', words);

      final loaded = await service.load('child_1');
      expect(loaded, hasLength(1));
      expect(loaded.first.word, 'cat');
      expect(loaded.first.translation, 'חתול');
    });

    test('two profiles keep separate banks', () async {
      final service = WordBankService(
        prefs: await SharedPreferences.getInstance(),
      );
      await service.save(
        'child_a',
        [
          LearnedWord(word: 'cat', dateLearned: DateTime(2026, 9, 16)),
        ],
      );

      expect(await service.load('child_b'), isEmpty);
    });

    test('null userId uses the guest namespace', () async {
      final service = WordBankService(
        prefs: await SharedPreferences.getInstance(),
      );
      await service.save(
        null,
        [
          LearnedWord(word: 'sun', dateLearned: DateTime(2026, 9, 16)),
        ],
      );

      final loaded = await service.load(null);
      expect(loaded.single.word, 'sun');
      expect(
        (await SharedPreferences.getInstance())
            .containsKey('user_guest_word_bank'),
        isTrue,
      );
    });
  });
}
