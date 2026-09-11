// test/models/sticker_test.dart

import 'package:english_learning_app/models/sticker.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('Sticker', () {
    const sticker = Sticker(
      id: 'sticker_fox',
      name: 'שועל',
      assetPath: 'assets/images/stickers/fox.png',
      cost: 50,
    );

    test('toJson / fromJson round-trip', () {
      final restored = Sticker.fromJson(sticker.toJson());
      expect(restored, sticker);
    });

    test('fromJson tolerates missing fields', () {
      final restored = Sticker.fromJson(const {});
      expect(restored.id, '');
      expect(restored.name, '');
      expect(restored.assetPath, '');
      expect(restored.cost, 0);
    });

    test('fromJson coerces a numeric cost written as double', () {
      final restored = Sticker.fromJson(const {
        'id': 'sticker_bear',
        'name': 'דוב',
        'assetPath': 'assets/images/stickers/bear.png',
        'cost': 30.0,
      });
      expect(restored.cost, 30);
    });

    test('copyWith overrides only the given fields', () {
      final updated = sticker.copyWith(cost: 75);
      expect(updated.cost, 75);
      expect(updated.id, sticker.id);
      expect(updated.name, sticker.name);
      expect(updated.assetPath, sticker.assetPath);
    });

    test('equality is value-based', () {
      const other = Sticker(
        id: 'sticker_fox',
        name: 'שועל',
        assetPath: 'assets/images/stickers/fox.png',
        cost: 50,
      );
      expect(sticker, other);
      expect(sticker.hashCode, other.hashCode);
      expect(sticker == sticker.copyWith(cost: 51), isFalse);
    });
  });
}
