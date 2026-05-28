import 'package:english_learning_app/models/word_data.dart';
import 'package:english_learning_app/services/offline_image_cache.dart';
import 'package:english_learning_app/services/offline_practice_service.dart';
import 'package:english_learning_app/services/word_repository.dart';
import 'package:english_learning_app/utils/device_connectivity.dart';
import 'package:english_learning_app/utils/offline_word_loader.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _OfflineConnectivity extends DeviceConnectivity {
  @override
  Future<bool> isOnline({Duration timeout = const Duration(seconds: 3)}) async =>
      false;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    DeviceConnectivity.testOverride = _OfflineConnectivity();
  });

  tearDown(() {
    DeviceConnectivity.testOverride = null;
  });

  test('uses cache when device is offline', () async {
    final prefs = await SharedPreferences.getInstance();
    final repository = WordRepository(prefs: prefs);
    await repository.cacheWords(
      [WordData(word: 'Star', imageUrl: 'assets/images/words/star.png')],
      cacheNamespace: 'level_test',
    );

    final loader = OfflineWordLoader(
      wordRepository: repository,
      offlinePracticeService: OfflinePracticeService(
        prefs: prefs,
        imageCache: OfflineImageCache(prefs: prefs),
      ),
      connectivity: DeviceConnectivity.current,
    );

    final words = await loader.loadWords(
      remoteCapable: true,
      fallbackWords: [WordData(word: 'Moon')],
      cacheNamespace: 'level_test',
    );

    expect(words.single.word, 'Star');
  });
}
