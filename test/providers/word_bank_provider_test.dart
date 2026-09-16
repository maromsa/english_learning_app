import 'package:english_learning_app/models/learned_word.dart';
import 'package:english_learning_app/providers/word_bank_provider.dart';
import 'package:english_learning_app/services/word_bank_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _RecordingWordBankService extends WordBankService {
  _RecordingWordBankService({required SharedPreferences prefs})
      : super(prefs: prefs);

  int saveCount = 0;
  List<LearnedWord>? lastSaved;

  @override
  Future<void> save(String? userId, List<LearnedWord> words) async {
    saveCount++;
    lastSaved = List<LearnedWord>.from(words);
    await super.save(userId, words);
  }
}

Future<WordBankProvider> _provider({
  String? userId,
  WordBankService? service,
  DateTime Function()? now,
}) async {
  final provider = WordBankProvider(
    service: service ??
        WordBankService(prefs: await SharedPreferences.getInstance()),
    now: now ?? () => DateTime(2026, 9, 16, 12),
  );
  provider.setUserId(userId);
  await provider.load();
  return provider;
}

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  group('WordBankProvider', () {
    test('initial state is empty', () async {
      final provider = await _provider();
      expect(provider.words, isEmpty);
      expect(provider.count, 0);
    });

    test('addWord stores a new entry and notifies listeners', () async {
      final provider = await _provider();
      var notifications = 0;
      provider.addListener(() => notifications++);

      final added = await provider.addWord('cat', translation: 'חתול');

      expect(added, isTrue);
      expect(provider.words, hasLength(1));
      expect(provider.words.first.word, 'cat');
      expect(provider.words.first.translation, 'חתול');
      expect(provider.words.first.dateLearned, DateTime(2026, 9, 16, 12));
      expect(notifications, 1);
    });

    test('addWord is case-insensitive and does not duplicate', () async {
      final service = _RecordingWordBankService(
        prefs: await SharedPreferences.getInstance(),
      );
      final provider = await _provider(service: service);

      await provider.addWord('Cat');
      final again = await provider.addWord('cat');
      final mixed = await provider.addWord(' CAT ');

      expect(again, isFalse);
      expect(mixed, isFalse);
      expect(provider.words, hasLength(1));
      expect(provider.words.first.word, 'Cat');
      expect(service.saveCount, 1);
    });

    test('addWord ignores blank strings', () async {
      final provider = await _provider();
      expect(await provider.addWord('   '), isFalse);
      expect(await provider.addWord(''), isFalse);
      expect(provider.words, isEmpty);
    });

    test('newer words are prepended', () async {
      final provider = await _provider();
      await provider.addWord('cat');
      await provider.addWord('dog');
      expect(provider.words.map((w) => w.word).toList(), ['dog', 'cat']);
    });

    test('addWord persists via the storage service', () async {
      final service = _RecordingWordBankService(
        prefs: await SharedPreferences.getInstance(),
      );
      final provider = await _provider(userId: 'child_1', service: service);

      await provider.addWord('water');

      expect(service.saveCount, 1);
      expect(service.lastSaved?.single.word, 'water');
    });

    test('state survives a reload from SharedPreferences', () async {
      final provider = await _provider(userId: 'child_1');
      await provider.addWord('sun', translation: 'שמש');

      final reloaded = await _provider(userId: 'child_1');
      expect(reloaded.words.single.word, 'sun');
      expect(reloaded.words.single.translation, 'שמש');
    });

    test('two profiles keep separate banks', () async {
      final childA = await _provider(userId: 'child_a');
      await childA.addWord('cat');

      final childB = await _provider(userId: 'child_b');
      expect(childB.words, isEmpty);
    });
  });
}
