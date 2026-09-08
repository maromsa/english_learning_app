// test/services/shop_customization_service_test.dart
//
// Unit tests for ShopCustomizationService: local persistence of unlocked +
// equipped map themes / victory sounds, namespaced per child profile.

import 'package:english_learning_app/models/customization_item.dart';
import 'package:english_learning_app/services/shop_customization_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  late ShopCustomizationService service;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    service = ShopCustomizationService(
      prefs: await SharedPreferences.getInstance(),
    );
  });

  test('defaults: nothing unlocked, default theme + sound equipped', () async {
    expect(await service.getUnlockedThemeIds('u1'), isEmpty);
    expect(await service.getUnlockedSoundIds('u1'), isEmpty);
    expect(
      await service.getEquippedThemeId('u1'),
      CustomizationItem.defaultThemeId,
    );
    expect(
      await service.getEquippedSoundId('u1'),
      CustomizationItem.defaultSoundId,
    );
  });

  test('round-trips unlocked + equipped state', () async {
    await service.saveUnlockedThemeIds('u1', {CustomizationItem.spaceThemeId});
    await service.saveUnlockedSoundIds('u1', {CustomizationItem.funnySoundId});
    await service.saveEquippedThemeId('u1', CustomizationItem.spaceThemeId);
    await service.saveEquippedSoundId('u1', CustomizationItem.funnySoundId);

    expect(
      await service.getUnlockedThemeIds('u1'),
      {CustomizationItem.spaceThemeId},
    );
    expect(
      await service.getUnlockedSoundIds('u1'),
      {CustomizationItem.funnySoundId},
    );
    expect(
      await service.getEquippedThemeId('u1'),
      CustomizationItem.spaceThemeId,
    );
    expect(
      await service.getEquippedSoundId('u1'),
      CustomizationItem.funnySoundId,
    );
  });

  test('state is isolated per profile id', () async {
    await service.saveUnlockedThemeIds('child_a', {
      CustomizationItem.goldThemeId,
    });
    await service.saveEquippedThemeId('child_a', CustomizationItem.goldThemeId);

    expect(await service.getUnlockedThemeIds('child_b'), isEmpty);
    expect(
      await service.getEquippedThemeId('child_b'),
      CustomizationItem.defaultThemeId,
    );
  });

  test('guest (null id) falls back to a stable namespace', () async {
    await service.saveUnlockedThemeIds(null, {CustomizationItem.spaceThemeId});
    expect(
      await service.getUnlockedThemeIds(null),
      {CustomizationItem.spaceThemeId},
    );
    // A named profile does not see the guest's picks.
    expect(await service.getUnlockedThemeIds('u1'), isEmpty);
  });
}
