// test/providers/equipped_avatar_provider_test.dart
//
// Unit tests for EquippedAvatarProvider: initial state, equipItem overriding
// the correct slot, and unequipItem clearing it.

import 'package:english_learning_app/models/avatar_item.dart';
import 'package:english_learning_app/models/equipped_avatar.dart';
import 'package:english_learning_app/providers/equipped_avatar_provider.dart';
import 'package:flutter_test/flutter_test.dart';

const _hat = AvatarItem(
  id: 'hat_wizard',
  name: 'כובע קוסם',
  type: AvatarItemType.hat,
  assetPath: 'assets/images/avatar/hat_wizard.png',
  cost: 50,
);

const _otherHat = AvatarItem(
  id: 'hat_pirate',
  name: 'כובע פיראט',
  type: AvatarItemType.hat,
  assetPath: 'assets/images/avatar/hat_pirate.png',
  cost: 40,
);

const _shirt = AvatarItem(
  id: 'shirt_red',
  name: 'חולצה אדומה',
  type: AvatarItemType.shirt,
  assetPath: 'assets/images/avatar/shirt_red.png',
  cost: 20,
);

const _accessory = AvatarItem(
  id: 'accessory_glasses',
  name: 'משקפיים',
  type: AvatarItemType.accessory,
  assetPath: 'assets/images/avatar/accessory_glasses.png',
  cost: 15,
);

const _background = AvatarItem(
  id: 'background_forest',
  name: 'רקע יער',
  type: AvatarItemType.background,
  assetPath: 'assets/images/avatar/background_forest.png',
  cost: 30,
);

void main() {
  group('EquippedAvatarProvider', () {
    test('initial state is an empty EquippedAvatar', () {
      final provider = EquippedAvatarProvider();
      expect(provider.equipped, EquippedAvatar.empty());
    });

    test('equipItem sets the hat slot for a hat item', () {
      final provider = EquippedAvatarProvider();
      provider.equipItem(_hat);
      expect(provider.equipped.hatId, _hat.id);
      expect(provider.equipped.shirtId, isNull);
    });

    test('equipItem sets the shirt slot for a shirt item', () {
      final provider = EquippedAvatarProvider();
      provider.equipItem(_shirt);
      expect(provider.equipped.shirtId, _shirt.id);
      expect(provider.equipped.hatId, isNull);
    });

    test('equipItem sets the accessory slot for an accessory item', () {
      final provider = EquippedAvatarProvider();
      provider.equipItem(_accessory);
      expect(provider.equipped.accessoryId, _accessory.id);
    });

    test('equipItem sets the background slot for a background item', () {
      final provider = EquippedAvatarProvider();
      provider.equipItem(_background);
      expect(provider.equipped.backgroundId, _background.id);
    });

    test('equipItem overrides whatever was previously in that slot', () {
      final provider = EquippedAvatarProvider();
      provider.equipItem(_hat);
      provider.equipItem(_otherHat);
      expect(provider.equipped.hatId, _otherHat.id);
    });

    test('equipItem into one slot leaves other slots untouched', () {
      final provider = EquippedAvatarProvider();
      provider.equipItem(_hat);
      provider.equipItem(_shirt);
      expect(provider.equipped.hatId, _hat.id);
      expect(provider.equipped.shirtId, _shirt.id);
    });

    test('unequipItem clears only the targeted slot', () {
      final provider = EquippedAvatarProvider();
      provider.equipItem(_hat);
      provider.equipItem(_shirt);

      provider.unequipItem(AvatarItemType.hat);

      expect(provider.equipped.hatId, isNull);
      expect(provider.equipped.shirtId, _shirt.id);
    });

    test('unequipItem on an already-empty slot is a no-op', () {
      final provider = EquippedAvatarProvider();
      provider.unequipItem(AvatarItemType.accessory);
      expect(provider.equipped, EquippedAvatar.empty());
    });

    test('notifyListeners fires on equip and unequip', () {
      final provider = EquippedAvatarProvider();
      var notifications = 0;
      provider.addListener(() => notifications++);

      provider.equipItem(_hat);
      expect(notifications, 1);

      provider.unequipItem(AvatarItemType.hat);
      expect(notifications, 2);
    });
  });
}
