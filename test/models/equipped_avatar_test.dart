// test/models/equipped_avatar_test.dart

import 'package:english_learning_app/models/equipped_avatar.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('EquippedAvatar', () {
    test('empty avatar has every slot unset', () {
      final avatar = EquippedAvatar.empty();
      expect(avatar.hatId, isNull);
      expect(avatar.shirtId, isNull);
      expect(avatar.accessoryId, isNull);
      expect(avatar.backgroundId, isNull);
    });

    test('toJson / fromJson round-trip with all slots filled', () {
      const avatar = EquippedAvatar(
        hatId: 'hat_wizard',
        shirtId: 'shirt_red',
        accessoryId: 'accessory_glasses',
        backgroundId: 'background_forest',
      );
      final restored = EquippedAvatar.fromJson(avatar.toJson());
      expect(restored, avatar);
    });

    test('toJson omits unset slots rather than writing null', () {
      const avatar = EquippedAvatar(hatId: 'hat_wizard');
      final json = avatar.toJson();
      expect(json.containsKey('hatId'), isTrue);
      expect(json.containsKey('shirtId'), isFalse);
      expect(json.containsKey('accessoryId'), isFalse);
      expect(json.containsKey('backgroundId'), isFalse);
    });

    test('fromJson tolerates missing / malformed document', () {
      final restored = EquippedAvatar.fromJson(const {});
      expect(restored, EquippedAvatar.empty());
    });

    test('copyWith updates only the given slot', () {
      final avatar = EquippedAvatar.empty().copyWith(hatId: 'hat_wizard');
      expect(avatar.hatId, 'hat_wizard');
      expect(avatar.shirtId, isNull);

      final updated = avatar.copyWith(shirtId: 'shirt_red');
      expect(updated.hatId, 'hat_wizard');
      expect(updated.shirtId, 'shirt_red');
    });

    test('copyWith with no arguments leaves the avatar unchanged', () {
      const avatar = EquippedAvatar(
        hatId: 'hat_wizard',
        shirtId: 'shirt_red',
        accessoryId: 'accessory_glasses',
        backgroundId: 'background_forest',
      );
      expect(avatar.copyWith(), avatar);
    });

    test('clearHat explicitly unequips the hat slot', () {
      const avatar = EquippedAvatar(hatId: 'hat_wizard', shirtId: 'shirt_red');
      final cleared = avatar.copyWith(clearHat: true);
      expect(cleared.hatId, isNull);
      expect(cleared.shirtId, 'shirt_red');
    });

    test('clearShirt explicitly unequips the shirt slot', () {
      const avatar = EquippedAvatar(shirtId: 'shirt_red');
      final cleared = avatar.copyWith(clearShirt: true);
      expect(cleared.shirtId, isNull);
    });

    test('clearAccessory explicitly unequips the accessory slot', () {
      const avatar = EquippedAvatar(accessoryId: 'accessory_glasses');
      final cleared = avatar.copyWith(clearAccessory: true);
      expect(cleared.accessoryId, isNull);
    });

    test('clearBackground explicitly unequips the background slot', () {
      const avatar = EquippedAvatar(backgroundId: 'background_forest');
      final cleared = avatar.copyWith(clearBackground: true);
      expect(cleared.backgroundId, isNull);
    });

    test('a clear flag takes precedence over a simultaneous value argument',
        () {
      const avatar = EquippedAvatar(hatId: 'hat_wizard');
      final result = avatar.copyWith(hatId: 'hat_pirate', clearHat: true);
      expect(result.hatId, isNull);
    });

    test('clearing one slot leaves the others untouched', () {
      const avatar = EquippedAvatar(
        hatId: 'hat_wizard',
        shirtId: 'shirt_red',
        accessoryId: 'accessory_glasses',
        backgroundId: 'background_forest',
      );
      final result = avatar.copyWith(clearHat: true);
      expect(result.hatId, isNull);
      expect(result.shirtId, 'shirt_red');
      expect(result.accessoryId, 'accessory_glasses');
      expect(result.backgroundId, 'background_forest');
    });

    test('equality is value-based', () {
      const a = EquippedAvatar(hatId: 'hat_wizard', shirtId: 'shirt_red');
      const b = EquippedAvatar(hatId: 'hat_wizard', shirtId: 'shirt_red');
      expect(a, b);
      expect(a.hashCode, b.hashCode);
      expect(a == a.copyWith(shirtId: 'shirt_blue'), isFalse);
    });
  });
}
