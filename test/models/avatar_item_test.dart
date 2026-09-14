// test/models/avatar_item_test.dart

import 'package:english_learning_app/models/avatar_item.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('AvatarItem', () {
    const item = AvatarItem(
      id: 'hat_wizard',
      name: 'כובע קוסם',
      type: AvatarItemType.hat,
      assetPath: 'assets/images/avatar/hat_wizard.png',
      cost: 50,
    );

    test('toJson / fromJson round-trip', () {
      final restored = AvatarItem.fromJson(item.toJson());
      expect(restored, item);
    });

    test('toJson serializes the enum as its name', () {
      final json = item.toJson();
      expect(json['type'], 'hat');
    });

    for (final type in AvatarItemType.values) {
      test('round-trips AvatarItemType.${type.name}', () {
        final withType = item.copyWith(type: type);
        final restored = AvatarItem.fromJson(withType.toJson());
        expect(restored.type, type);
      });
    }

    test('fromJson tolerates missing fields, defaulting type to hat', () {
      final restored = AvatarItem.fromJson(const {});
      expect(restored.id, '');
      expect(restored.name, '');
      expect(restored.type, AvatarItemType.hat);
      expect(restored.assetPath, '');
      expect(restored.cost, 0);
    });

    test('fromJson falls back to hat for an unknown type string', () {
      final restored = AvatarItem.fromJson(const {
        'id': 'mystery_item',
        'name': 'Mystery',
        'type': 'cape', // not a recognized AvatarItemType
        'assetPath': 'assets/images/avatar/cape.png',
        'cost': 100,
      });
      expect(restored.type, AvatarItemType.hat);
      expect(restored.id, 'mystery_item');
    });

    test('fromJson falls back to hat when type is null', () {
      final restored = AvatarItem.fromJson(const {
        'id': 'item_x',
        'type': null,
      });
      expect(restored.type, AvatarItemType.hat);
    });

    test('fromJson coerces a numeric cost written as double', () {
      final restored = AvatarItem.fromJson(const {
        'id': 'shirt_red',
        'name': 'חולצה אדומה',
        'type': 'shirt',
        'assetPath': 'assets/images/avatar/shirt_red.png',
        'cost': 20.0,
      });
      expect(restored.cost, 20);
      expect(restored.type, AvatarItemType.shirt);
    });

    test('copyWith overrides only the given fields', () {
      final updated = item.copyWith(cost: 75);
      expect(updated.cost, 75);
      expect(updated.id, item.id);
      expect(updated.name, item.name);
      expect(updated.type, item.type);
      expect(updated.assetPath, item.assetPath);
    });

    test('equality is value-based', () {
      const other = AvatarItem(
        id: 'hat_wizard',
        name: 'כובע קוסם',
        type: AvatarItemType.hat,
        assetPath: 'assets/images/avatar/hat_wizard.png',
        cost: 50,
      );
      expect(item, other);
      expect(item.hashCode, other.hashCode);
      expect(item == item.copyWith(cost: 51), isFalse);
      expect(item == item.copyWith(type: AvatarItemType.shirt), isFalse);
    });
  });
}
