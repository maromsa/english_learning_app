import 'dart:convert';
import 'dart:io';

import 'package:english_learning_app/models/level_data.dart';
import 'package:english_learning_app/models/word_data.dart';
import 'package:english_learning_app/services/level_repository.dart';
import 'package:english_learning_app/services/level_unlock_service.dart';
import 'package:english_learning_app/services/offline_image_cache.dart';
import 'package:english_learning_app/services/offline_practice_service.dart';
import 'package:english_learning_app/services/word_repository.dart';
import 'package:english_learning_app/utils/device_connectivity.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

class _FakeConnectivity extends DeviceConnectivity {
  _FakeConnectivity(this._online);

  final bool _online;

  @override
  Future<bool> isOnline({Duration timeout = const Duration(seconds: 3)}) async =>
      _online;
}

class _FakeLevelRepository extends LevelRepository {
  _FakeLevelRepository(List<LevelData> levels)
      : super(bundle: _FakeBundle(levels));
}

class _FakeBundle extends AssetBundle {
  _FakeBundle(this.levels);

  final List<LevelData> levels;

  @override
  Future<String> loadString(String key, {bool cache = true}) async {
    return jsonEncode({
      'levels': levels.map((level) => level.toJson()).toList(),
    });
  }

  @override
  Future<ByteData> load(String key) {
    throw UnimplementedError();
  }

  @override
  void evict(String key) {}
}

class _FakeUnlockService extends LevelUnlockService {
  _FakeUnlockService(this._unlockedIds);

  final Set<String> _unlockedIds;

  @override
  Future<void> applyUnlockStatuses(
    List<LevelData> levels, {
    required String userId,
    bool isLocalUser = true,
  }) async {
    for (final level in levels) {
      level.isUnlocked = _unlockedIds.contains(level.id);
    }
  }
}

class _FakeHttpClient extends http.BaseClient {
  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) async {
    return http.StreamedResponse(
      Stream<List<int>>.value(<int>[1, 2, 3]),
      200,
      headers: {'content-type': 'image/jpeg'},
    );
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    DeviceConnectivity.testOverride = null;
  });

  test('downloadAllUnlocked caches words and saves manifest', () async {
    final levels = [
      LevelData(
        id: 'level_fruits',
        name: 'Fruits',
        words: [
          WordData(
            word: 'Apple',
            imageUrl: 'assets/images/words/apple.png',
          ),
        ],
      ),
    ];

    final prefs = await SharedPreferences.getInstance();
    final wordRepository = WordRepository(prefs: prefs);
    final prefetched = <String>[];

    final service = OfflinePracticeService(
      levelRepository: _FakeLevelRepository(levels),
      levelUnlockService: _FakeUnlockService({'level_fruits'}),
      wordRepository: wordRepository,
      imageCache: OfflineImageCache(prefs: prefs),
      connectivity: _FakeConnectivity(true),
      prefs: prefs,
      ttsPrefetcher: (word, {networkAllowed = true}) async {
        prefetched.add(word);
        return true;
      },
    );

    await service.downloadAllUnlocked(userId: 'child_1');

    final manifest = await service.loadManifest();
    expect(manifest, isNotNull);
    expect(manifest!.levelIds, ['level_fruits']);
    expect(prefetched, contains('Apple'));

    final cached = await wordRepository.loadWords(
      remoteEnabled: false,
      fallbackWords: levels.first.words,
      cacheNamespace: 'level_fruits',
      preferCacheOnly: true,
    );
    expect(cached.map((w) => w.word), ['Apple']);
  });

  test('localizeWordsForOffline rewrites known URLs', () async {
    final prefs = await SharedPreferences.getInstance();
    final tempDir = await Directory.systemTemp.createTemp('offline_practice_');
    final cache = OfflineImageCache(
      prefs: prefs,
      httpClient: _FakeHttpClient(),
      directoryProvider: () async => tempDir,
    );

    const url = 'https://cdn.example.com/banana.jpg';
    await cache.downloadAndCache(url);

    final service = OfflinePracticeService(
      imageCache: cache,
      prefs: prefs,
    );

    final localized = await service.localizeWordsForOffline([
      WordData(word: 'Banana', imageUrl: url),
    ]);

    expect(localized.first.imageUrl, isNot(url));
    expect(File(localized.first.imageUrl!).existsSync(), isTrue);

    addTearDown(() => tempDir.delete(recursive: true));
  });
}
