import 'package:english_learning_app/models/word_data.dart';
import 'package:english_learning_app/services/cloudinary_service.dart';
import 'package:english_learning_app/services/web_image_service.dart';
import 'package:english_learning_app/services/word_repository.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _FakeCloudinaryService extends CloudinaryService {
  _FakeCloudinaryService(this._words, {this.shouldThrow = false})
      : super();

  final List<WordData> _words;
  final bool shouldThrow;

  @override
  Future<List<WordData>> fetchWords({
    required String cloudName,
    required String tagName,
    int maxResults = 50,
  }) async {
    if (shouldThrow) {
      throw Exception('network error');
    }
    return _words;
  }
}

class _StubWebImageProvider implements WebImageProvider {
  _StubWebImageProvider(this._lookup);

  final Map<String, WebImageResult?> _lookup;
  final List<String> requestedKeys = <String>[];
  final List<String> requestedWords = <String>[];
  final List<String?> requestedHints = <String?>[];

  @override
  Future<WebImageResult?> fetchImageForWord(String word, {String? searchHint}) async {
    final key = searchHint ?? word;
    requestedWords.add(word);
    requestedHints.add(searchHint);
    requestedKeys.add(key);
    return _lookup[key];
  }
}

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  test('returns fallback when remote disabled and cache empty', () async {
    final prefs = await SharedPreferences.getInstance();
    final repository = WordRepository(
      prefs: prefs,
      cloudinaryService: _FakeCloudinaryService(const []),
    );

    final fallback = [WordData(word: 'Apple')];

    final words = await repository.loadWords(
      remoteEnabled: false,
      fallbackWords: fallback,
    );

    expect(words.map((w) => w.word), ['Apple']);
  });

  test('caches remote words and reuses them when offline', () async {
    final prefs = await SharedPreferences.getInstance();
    final remoteWords = [
      WordData(word: 'Dog', imageUrl: 'https://example.com/dog.png'),
      WordData(word: 'Cat', imageUrl: 'https://example.com/cat.png'),
    ];

    final repository = WordRepository(
      prefs: prefs,
      cloudinaryService: _FakeCloudinaryService(remoteWords),
      cacheDuration: const Duration(hours: 12),
    );

    final firstLoad = await repository.loadWords(
      remoteEnabled: true,
      fallbackWords: const [],
      cloudName: 'demo',
      tagName: 'tag',
    );

    expect(firstLoad.map((w) => w.word), ['Dog', 'Cat']);

    final secondLoad = await repository.loadWords(
      remoteEnabled: false,
      fallbackWords: const [],
    );

    expect(secondLoad.map((w) => w.word), ['Dog', 'Cat']);
  });

  test('stores cached words per namespace', () async {
    final prefs = await SharedPreferences.getInstance();
    final repository = WordRepository(
      prefs: prefs,
      cloudinaryService: _FakeCloudinaryService(const []),
    );

    final fruits = [WordData(word: 'Apple')];
    final animals = [WordData(word: 'Dog')];

    final fruitsFirst = await repository.loadWords(
      remoteEnabled: false,
      fallbackWords: fruits,
      cacheNamespace: 'level_fruits',
    );
    expect(fruitsFirst.map((w) => w.word), ['Apple']);

    final animalsFirst = await repository.loadWords(
      remoteEnabled: false,
      fallbackWords: animals,
      cacheNamespace: 'level_animals',
    );
    expect(animalsFirst.map((w) => w.word), ['Dog']);

    final fruitsReload = await repository.loadWords(
      remoteEnabled: false,
      fallbackWords: [WordData(word: 'Banana')],
      cacheNamespace: 'level_fruits',
    );
    expect(fruitsReload.map((w) => w.word), ['Apple']);

    final animalsReload = await repository.loadWords(
      remoteEnabled: false,
      fallbackWords: [WordData(word: 'Cat')],
      cacheNamespace: 'level_animals',
    );
    expect(animalsReload.map((w) => w.word), ['Dog']);
  });

  test('enriches fallback words with web images and stores them in cache', () async {
    final prefs = await SharedPreferences.getInstance();
    final webProvider = _StubWebImageProvider({
      'ripe red apple fruit': const WebImageResult(
        imageUrl: 'https://images.example/apple.jpg',
        inferredWord: 'Apple',
      ),
      'yellow banana fruit bunch': null,
    });

    final repository = WordRepository(
      prefs: prefs,
      cloudinaryService: _FakeCloudinaryService(const []),
      webImageProvider: webProvider,
    );

    final fallback = [
      WordData(word: 'Apple', searchHint: 'ripe red apple fruit'),
      WordData(word: 'Banana', searchHint: 'yellow banana fruit bunch'),
      WordData(word: 'Cherry', imageUrl: 'https://example.com/cherry.jpg'),
    ];

    final words = await repository.loadWords(
      remoteEnabled: false,
      fallbackWords: fallback,
    );

    expect(words[0].word, 'Apple');
    expect(words[0].searchHint, 'ripe red apple fruit');
    expect(words[0].imageUrl, 'https://images.example/apple.jpg');
    expect(words[1].searchHint, 'yellow banana fruit bunch');
    expect(words[1].imageUrl, null);
    expect(words[2].imageUrl, 'https://example.com/cherry.jpg');
    expect(webProvider.requestedKeys, equals(<String>['ripe red apple fruit', 'yellow banana fruit bunch']));

    final cachedWords = await repository.loadWords(
      remoteEnabled: false,
      fallbackWords: const [],
    );

    expect(webProvider.requestedKeys, equals(<String>['ripe red apple fruit', 'yellow banana fruit bunch']));
    expect(
      cachedWords.map((w) => w.imageUrl).toList(),
      words.map((w) => w.imageUrl).toList(),
    );
  });

  test('clearCache removes cached data', () async {
    final prefs = await SharedPreferences.getInstance();
    final repository = WordRepository(
      prefs: prefs,
      cloudinaryService: _FakeCloudinaryService([
        WordData(word: 'Sun', imageUrl: 'https://example.com/sun.png'),
      ]),
    );

    await repository.loadWords(
      remoteEnabled: true,
      fallbackWords: const [],
      cloudName: 'demo',
      tagName: 'tag',
    );

    await repository.clearCache();

    final fallback = [WordData(word: 'Star')];
    final offlineWords = await repository.loadWords(
      remoteEnabled: false,
      fallbackWords: fallback,
    );

    expect(offlineWords.map((w) => w.word), ['Star']);
  });
}
