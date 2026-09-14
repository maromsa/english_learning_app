// test/providers/sticker_album_provider_test.dart
//
// Unit tests for StickerAlbumProvider: buying delegates the coin debit to
// CoinProvider, placement/removal update the album, and state persists
// per-profile across a reload.

import 'package:english_learning_app/models/sticker.dart';
import 'package:english_learning_app/providers/coin_provider.dart';
import 'package:english_learning_app/providers/sticker_album_provider.dart';
import 'package:english_learning_app/services/sticker_album_service.dart';
import 'package:english_learning_app/services/user_data_service.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

final _fox = Sticker.defaultCatalog[0];
final _bear = Sticker.defaultCatalog[1];

Future<CoinProvider> _coins(int amount) async {
  final provider = CoinProvider(
    userDataService: UserDataService(firestore: FakeFirebaseFirestore()),
  );
  await provider.setCoins(amount);
  return provider;
}

Future<StickerAlbumProvider> _album({String? userId}) async {
  final provider = StickerAlbumProvider(
    service: StickerAlbumService(prefs: await SharedPreferences.getInstance()),
  );
  provider.setUserId(userId);
  await provider.load();
  return provider;
}

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  test('a fresh album owns and places nothing', () async {
    final album = await _album();
    expect(album.isOwned(_fox.id), isFalse);
    expect(album.isPlaced(_fox.id), isFalse);
    expect(album.unplacedStickers, isEmpty);
    expect(album.placedStickers, isEmpty);
  });

  test('purchase deducts coins via CoinProvider and adds it unplaced',
      () async {
    final coins = await _coins(500);
    final album = await _album();

    final ok = await album.purchase(_fox, coins);

    expect(ok, isTrue);
    expect(coins.coins, 500 - _fox.cost);
    expect(album.isOwned(_fox.id), isTrue);
    expect(album.unplacedStickers, [_fox]);
  });

  test('purchase fails and charges nothing when the child cannot afford it',
      () async {
    final coins = await _coins(1);
    final album = await _album();

    final ok = await album.purchase(_fox, coins);

    expect(ok, isFalse);
    expect(coins.coins, 1);
    expect(album.isOwned(_fox.id), isFalse);
  });

  test('purchase is idempotent for an already-owned sticker', () async {
    final coins = await _coins(500);
    final album = await _album();
    await album.purchase(_fox, coins);
    final spentAfterFirstBuy = coins.coins;

    final ok = await album.purchase(_fox, coins);

    expect(ok, isTrue);
    expect(coins.coins, spentAfterFirstBuy); // no second charge
  });

  test('place moves an owned sticker from unplaced to placed', () async {
    final coins = await _coins(500);
    final album = await _album();
    await album.purchase(_fox, coins);

    await album.place(_fox.id, x: 0.3, y: 0.6);

    expect(album.isPlaced(_fox.id), isTrue);
    expect(album.unplacedStickers, isEmpty);
    expect(album.placementOf(_fox.id)?.x, 0.3);
    expect(album.placementOf(_fox.id)?.y, 0.6);
    expect(album.placedStickers, [(_fox, album.placementOf(_fox.id)!)]);
  });

  test('place is a no-op for a sticker that was never purchased', () async {
    final album = await _album();

    await album.place(_fox.id, x: 0.5, y: 0.5);

    expect(album.isPlaced(_fox.id), isFalse);
  });

  test('removePlacement returns a sticker to the unplaced tray', () async {
    final coins = await _coins(500);
    final album = await _album();
    await album.purchase(_fox, coins);
    await album.place(_fox.id, x: 0.5, y: 0.5);

    await album.removePlacement(_fox.id);

    expect(album.isPlaced(_fox.id), isFalse);
    expect(album.isOwned(_fox.id), isTrue);
    expect(album.unplacedStickers, [_fox]);
  });

  test('state survives a reload from SharedPreferences', () async {
    final coins = await _coins(500);
    final album = await _album(userId: 'child_1');
    await album.purchase(_fox, coins);
    await album.place(_fox.id, x: 0.2, y: 0.8);
    await album.purchase(_bear, coins);

    final reloaded = await _album(userId: 'child_1');
    expect(reloaded.isOwned(_fox.id), isTrue);
    expect(reloaded.isPlaced(_fox.id), isTrue);
    expect(reloaded.placementOf(_fox.id)?.x, 0.2);
    expect(reloaded.isOwned(_bear.id), isTrue);
    expect(reloaded.isPlaced(_bear.id), isFalse);
  });

  test('two profiles keep separate albums', () async {
    final coins = await _coins(500);
    final childA = await _album(userId: 'child_a');
    await childA.purchase(_fox, coins);

    final childB = await _album(userId: 'child_b');
    expect(childB.isOwned(_fox.id), isFalse);
  });
}
