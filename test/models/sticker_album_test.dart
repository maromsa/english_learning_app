// test/models/sticker_album_test.dart

import 'package:english_learning_app/models/sticker_album.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('StickerPlacement', () {
    test('toJson / fromJson round-trip', () {
      const placement =
          StickerPlacement(stickerId: 'sticker_fox', x: 0.25, y: 0.75);
      final restored = StickerPlacement.fromJson(placement.toJson());
      expect(restored, placement);
    });

    test('fromJson tolerates missing fields', () {
      final restored = StickerPlacement.fromJson(const {});
      expect(restored.stickerId, '');
      expect(restored.x, 0.0);
      expect(restored.y, 0.0);
    });
  });

  group('StickerAlbum', () {
    test('empty album owns and places nothing', () {
      final album = StickerAlbum.empty();
      expect(album.purchasedStickerIds, isEmpty);
      expect(album.placements, isEmpty);
      expect(album.isPurchased('sticker_fox'), isFalse);
      expect(album.isPlaced('sticker_fox'), isFalse);
    });

    test('purchase adds the sticker id and is idempotent', () {
      final album = StickerAlbum.empty().purchase('sticker_fox');
      expect(album.isPurchased('sticker_fox'), isTrue);

      final again = album.purchase('sticker_fox');
      expect(again.purchasedStickerIds.length, 1);
    });

    test(
        'place requires prior purchase — placing an unowned sticker is a no-op',
        () {
      final album = StickerAlbum.empty().place('sticker_fox', x: 0.1, y: 0.2);
      expect(album.isPlaced('sticker_fox'), isFalse);
      expect(album.placements, isEmpty);
    });

    test('place records coordinates for an owned sticker', () {
      final album = StickerAlbum.empty()
          .purchase('sticker_fox')
          .place('sticker_fox', x: 0.4, y: 0.6);

      expect(album.isPlaced('sticker_fox'), isTrue);
      final placement = album.placements['sticker_fox']!;
      expect(placement.x, 0.4);
      expect(placement.y, 0.6);
    });

    test('placing again for the same sticker replaces the old placement', () {
      final album = StickerAlbum.empty()
          .purchase('sticker_fox')
          .place('sticker_fox', x: 0.1, y: 0.1)
          .place('sticker_fox', x: 0.9, y: 0.9);

      expect(album.placements.length, 1);
      expect(album.placements['sticker_fox']!.x, 0.9);
      expect(album.placements['sticker_fox']!.y, 0.9);
    });

    test('removePlacement clears the canvas position but keeps ownership', () {
      final placed = StickerAlbum.empty()
          .purchase('sticker_fox')
          .place('sticker_fox', x: 0.4, y: 0.6);

      final removed = placed.removePlacement('sticker_fox');
      expect(removed.isPurchased('sticker_fox'), isTrue);
      expect(removed.isPlaced('sticker_fox'), isFalse);
    });

    test('toJson / fromJson round-trips purchases and placements', () {
      final album = StickerAlbum.empty()
          .purchase('sticker_fox')
          .purchase('sticker_bear')
          .place('sticker_fox', x: 0.4, y: 0.6);

      final restored = StickerAlbum.fromJson(album.toJson());
      expect(restored.purchasedStickerIds, {'sticker_fox', 'sticker_bear'});
      expect(restored.isPlaced('sticker_fox'), isTrue);
      expect(restored.isPlaced('sticker_bear'), isFalse);
      expect(restored.placements['sticker_fox']!.x, 0.4);
      expect(restored.placements['sticker_fox']!.y, 0.6);
    });

    test('fromJson tolerates missing fields', () {
      final album = StickerAlbum.fromJson(const {});
      expect(album.purchasedStickerIds, isEmpty);
      expect(album.placements, isEmpty);
    });

    test('fromJson drops a placement for a sticker not in purchasedStickerIds',
        () {
      final album = StickerAlbum.fromJson(const {
        'purchasedStickerIds': ['sticker_bear'],
        'placements': [
          {'stickerId': 'sticker_fox', 'x': 0.5, 'y': 0.5},
        ],
      });

      expect(album.purchasedStickerIds, {'sticker_bear'});
      expect(album.placements, isEmpty);
    });

    test('fromJson skips malformed placement entries', () {
      final album = StickerAlbum.fromJson(const {
        'purchasedStickerIds': ['sticker_fox'],
        'placements': [
          'not a map',
          {'stickerId': '', 'x': 0.5, 'y': 0.5},
          {'stickerId': 'sticker_fox', 'x': 0.2, 'y': 0.3},
        ],
      });

      expect(album.placements.length, 1);
      expect(album.placements['sticker_fox']!.x, 0.2);
    });
  });
}
