import 'dart:typed_data';

import 'package:english_learning_app/services/level_repository.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

class _FakeBundle extends CachingAssetBundle {
  _FakeBundle(this._responses);

  final Map<String, String> _responses;

  @override
  Future<ByteData> load(String key) async {
    final value = _responses[key];
    if (value == null) {
      throw FlutterError('missing asset: $key');
    }
    final bytes = Uint8List.fromList(value.codeUnits);
    return bytes.buffer.asByteData();
  }

  @override
  Future<String> loadString(String key, {bool cache = true}) async {
    final value = _responses[key];
    if (value == null) {
      throw FlutterError('missing asset: $key');
    }
    return value;
  }
}

void main() {
  test('loadLevels parses level metadata from bundle', () async {
    const assetPath = 'assets/data/levels.json';
    final bundle = _FakeBundle({
      assetPath: '''
{
  "levels": [
    {
      "id": "level_alpha",
      "name": "Alpha",
      "unlockStars": 0,
      "position": {"x": 0.5, "y": 0.5},
      "words": [
        {"word": "Sun"},
        {"word": "Moon"}
      ]
    }
  ]
}
''',
    });

    final repository = LevelRepository(bundle: bundle);
    final levels = await repository.loadLevels(assetPath: assetPath);

    expect(levels, hasLength(1));
    final level = levels.first;
    expect(level.id, 'level_alpha');
    expect(level.name, 'Alpha');
    expect(level.positionX, 0.5);
    expect(level.words, hasLength(2));
  });

  test('loadLevels returns empty list on errors', () async {
    final repository = LevelRepository(bundle: _FakeBundle({}));
    final levels = await repository.loadLevels(assetPath: 'missing.json');

    expect(levels, isEmpty);
  });
}
