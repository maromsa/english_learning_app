import 'dart:io';

import 'package:english_learning_app/models/word_data.dart';
import 'package:english_learning_app/services/offline_image_cache.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

class _FakeHttpClient extends http.BaseClient {
  _FakeHttpClient(this._bytes);

  final List<int> _bytes;
  int callCount = 0;

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) async {
    callCount++;
    return http.StreamedResponse(
      Stream<List<int>>.value(_bytes),
      200,
      headers: {'content-type': 'image/jpeg'},
    );
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  test('downloads remote image and maps URL to local path', () async {
    final tempDir = await Directory.systemTemp.createTemp('offline_img_');
    final cache = OfflineImageCache(
      httpClient: _FakeHttpClient(<int>[1, 2, 3, 4]),
      directoryProvider: () async => tempDir,
    );

    const url = 'https://example.com/apple.jpg';
    final local = await cache.downloadAndCache(url);
    expect(local, isNotNull);
    expect(File(local!).existsSync(), isTrue);

    final resolved = await cache.getLocalPath(url);
    expect(resolved, local);

    final words = await cache.localizeWords([
      WordData(word: 'Apple', imageUrl: url),
    ]);
    expect(words.first.imageUrl, local);

    addTearDown(() async {
      if (await tempDir.exists()) {
        await tempDir.delete(recursive: true);
      }
    });
    await cache.clear();
  });

  test('skips asset URLs', () async {
    expect(
      OfflineImageCache.shouldDownload('assets/images/words/apple.png'),
      isFalse,
    );
  });
}
