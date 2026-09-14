// test/services/sticker_album_service_test.dart
//
// Unit tests for StickerAlbumService: local persistence of the sticker
// album (owned stickers + placements), namespaced per child profile.

import 'package:english_learning_app/models/sticker_album.dart';
import 'package:english_learning_app/services/sticker_album_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  late StickerAlbumService service;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    service = StickerAlbumService(prefs: await SharedPreferences.getInstance());
  });

  test('load returns an empty album when nothing has been saved', () async {
    final album = await service.load('u1');
    expect(album.purchasedStickerIds, isEmpty);
    expect(album.placements, isEmpty);
  });

  test('round-trips a purchased + placed album', () async {
    final album = StickerAlbum.empty()
        .purchase('sticker_fox')
        .place('sticker_fox', x: 0.4, y: 0.6);

    await service.save('u1', album);
    final reloaded = await service.load('u1');

    expect(reloaded.isPurchased('sticker_fox'), isTrue);
    expect(reloaded.placements['sticker_fox']?.x, 0.4);
    expect(reloaded.placements['sticker_fox']?.y, 0.6);
  });

  test('guest (null userId) and a named profile stay isolated', () async {
    await service.save(null, StickerAlbum.empty().purchase('sticker_fox'));
    await service.save('u1', StickerAlbum.empty().purchase('sticker_bear'));

    final guest = await service.load(null);
    final u1 = await service.load('u1');

    expect(guest.isPurchased('sticker_fox'), isTrue);
    expect(guest.isPurchased('sticker_bear'), isFalse);
    expect(u1.isPurchased('sticker_bear'), isTrue);
    expect(u1.isPurchased('sticker_fox'), isFalse);
  });

  test('load tolerates a malformed stored value', () async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('user_u1_sticker_album', 'not json');

    final album = await service.load('u1');
    expect(album.purchasedStickerIds, isEmpty);
  });
}
