// test/providers/equipped_avatar_provider_test.dart
//
// Unit tests for EquippedAvatarProvider: initial state, equipItem overriding
// the correct slot, unequipItem clearing it, persistence on every change,
// restoring saved state on load(), and the debounced Firestore sync used to
// mirror the equipped avatar onto the leaderboard.

import 'package:english_learning_app/models/avatar_item.dart';
import 'package:english_learning_app/models/equipped_avatar.dart';
import 'package:english_learning_app/providers/equipped_avatar_provider.dart';
import 'package:english_learning_app/services/child_profile_sync_service.dart';
import 'package:english_learning_app/services/equipped_avatar_service.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

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

/// Records every `save()` call so tests can assert persistence was
/// triggered without depending on `SharedPreferences` internals.
class _RecordingEquippedAvatarService extends EquippedAvatarService {
  _RecordingEquippedAvatarService({required SharedPreferences prefs})
      : super(prefs: prefs);

  int saveCount = 0;
  EquippedAvatar? lastSaved;

  @override
  Future<void> save(String? userId, EquippedAvatar equipped) async {
    saveCount++;
    lastSaved = equipped;
    await super.save(userId, equipped);
  }
}

/// Records every `updateEquippedAvatar()` call so tests can assert the
/// debounced cloud sync fired (or didn't) without depending on real network
/// timing.
class _RecordingChildProfileSyncService extends ChildProfileSyncService {
  _RecordingChildProfileSyncService()
      : super(firestore: FakeFirebaseFirestore());

  int callCount = 0;
  String? lastParentUid;
  String? lastProfileId;
  EquippedAvatar? lastEquipped;

  @override
  Future<bool> updateEquippedAvatar(
    String parentUid,
    String profileId,
    EquippedAvatar equipped,
  ) async {
    callCount++;
    lastParentUid = parentUid;
    lastProfileId = profileId;
    lastEquipped = equipped;
    return super.updateEquippedAvatar(parentUid, profileId, equipped);
  }
}

Future<EquippedAvatarProvider> _provider({
  String? userId,
  String? parentUid,
  EquippedAvatarService? service,
  ChildProfileSyncService? syncService,
  Duration cloudSyncDebounce = const Duration(milliseconds: 30),
}) async {
  final provider = EquippedAvatarProvider(
    service: service ??
        EquippedAvatarService(prefs: await SharedPreferences.getInstance()),
    syncService: syncService ?? _RecordingChildProfileSyncService(),
    cloudSyncDebounce: cloudSyncDebounce,
  );
  provider.setUserId(userId);
  provider.setParentUid(parentUid);
  await provider.load();
  return provider;
}

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  group('EquippedAvatarProvider', () {
    test('initial state is an empty EquippedAvatar', () async {
      final provider = await _provider();
      expect(provider.equipped, EquippedAvatar.empty());
    });

    test('equipItem sets the hat slot for a hat item', () async {
      final provider = await _provider();
      await provider.equipItem(_hat);
      expect(provider.equipped.hatId, _hat.id);
      expect(provider.equipped.shirtId, isNull);
    });

    test('equipItem sets the shirt slot for a shirt item', () async {
      final provider = await _provider();
      await provider.equipItem(_shirt);
      expect(provider.equipped.shirtId, _shirt.id);
      expect(provider.equipped.hatId, isNull);
    });

    test('equipItem sets the accessory slot for an accessory item', () async {
      final provider = await _provider();
      await provider.equipItem(_accessory);
      expect(provider.equipped.accessoryId, _accessory.id);
    });

    test('equipItem sets the background slot for a background item', () async {
      final provider = await _provider();
      await provider.equipItem(_background);
      expect(provider.equipped.backgroundId, _background.id);
    });

    test('equipItem overrides whatever was previously in that slot', () async {
      final provider = await _provider();
      await provider.equipItem(_hat);
      await provider.equipItem(_otherHat);
      expect(provider.equipped.hatId, _otherHat.id);
    });

    test('equipItem into one slot leaves other slots untouched', () async {
      final provider = await _provider();
      await provider.equipItem(_hat);
      await provider.equipItem(_shirt);
      expect(provider.equipped.hatId, _hat.id);
      expect(provider.equipped.shirtId, _shirt.id);
    });

    test('unequipItem clears only the targeted slot', () async {
      final provider = await _provider();
      await provider.equipItem(_hat);
      await provider.equipItem(_shirt);

      await provider.unequipItem(AvatarItemType.hat);

      expect(provider.equipped.hatId, isNull);
      expect(provider.equipped.shirtId, _shirt.id);
    });

    test('unequipItem on an already-empty slot is a no-op', () async {
      final provider = await _provider();
      await provider.unequipItem(AvatarItemType.accessory);
      expect(provider.equipped, EquippedAvatar.empty());
    });

    test('notifyListeners fires on equip and unequip', () async {
      final provider = await _provider();
      var notifications = 0;
      provider.addListener(() => notifications++);

      await provider.equipItem(_hat);
      expect(notifications, 1);

      await provider.unequipItem(AvatarItemType.hat);
      expect(notifications, 2);
    });

    test('equipItem persists the new state via the storage service', () async {
      final service = _RecordingEquippedAvatarService(
        prefs: await SharedPreferences.getInstance(),
      );
      final provider = await _provider(service: service);

      await provider.equipItem(_hat);

      expect(service.saveCount, 1);
      expect(service.lastSaved?.hatId, _hat.id);
    });

    test('unequipItem persists the cleared state via the storage service',
        () async {
      final service = _RecordingEquippedAvatarService(
        prefs: await SharedPreferences.getInstance(),
      );
      final provider = await _provider(service: service);
      await provider.equipItem(_hat);

      await provider.unequipItem(AvatarItemType.hat);

      expect(service.saveCount, 2);
      expect(service.lastSaved?.hatId, isNull);
    });

    test('state survives a reload from SharedPreferences', () async {
      final provider = await _provider(userId: 'child_1');
      await provider.equipItem(_hat);
      await provider.equipItem(_shirt);
      await provider.equipItem(_accessory);

      final reloaded = await _provider(userId: 'child_1');

      expect(reloaded.equipped.hatId, _hat.id);
      expect(reloaded.equipped.shirtId, _shirt.id);
      expect(reloaded.equipped.accessoryId, _accessory.id);
      expect(reloaded.equipped.backgroundId, isNull);
    });

    test('two profiles keep separate equipped avatars', () async {
      final childA = await _provider(userId: 'child_a');
      await childA.equipItem(_hat);

      final childB = await _provider(userId: 'child_b');

      expect(childB.equipped.hatId, isNull);
    });

    test('load() restores an empty avatar when nothing was saved yet',
        () async {
      final provider = await _provider(userId: 'brand_new_child');
      expect(provider.equipped, EquippedAvatar.empty());
    });
  });

  group('EquippedAvatarProvider cloud sync', () {
    test(
        'equipItem does not push to the cloud without a parentUid (guest '
        '/ local profile)', () async {
      final sync = _RecordingChildProfileSyncService();
      final provider = await _provider(userId: 'child_1', syncService: sync);

      await provider.equipItem(_hat);
      await Future<void>.delayed(const Duration(milliseconds: 100));

      expect(sync.callCount, 0);
    });

    test('equipItem schedules a debounced push once a parentUid is set',
        () async {
      final sync = _RecordingChildProfileSyncService();
      final provider = await _provider(
        userId: 'child_1',
        parentUid: 'parent_1',
        syncService: sync,
      );

      await provider.equipItem(_hat);
      // Not yet — the debounce window hasn't elapsed.
      expect(sync.callCount, 0);

      await Future<void>.delayed(const Duration(milliseconds: 100));

      expect(sync.callCount, 1);
      expect(sync.lastParentUid, 'parent_1');
      expect(sync.lastProfileId, 'child_1');
      expect(sync.lastEquipped?.hatId, _hat.id);
    });

    test('rapid equip calls collapse into a single debounced cloud write',
        () async {
      final sync = _RecordingChildProfileSyncService();
      final provider = await _provider(
        userId: 'child_1',
        parentUid: 'parent_1',
        syncService: sync,
      );

      await provider.equipItem(_hat);
      await provider.equipItem(_otherHat);
      await provider.equipItem(_shirt);

      expect(sync.callCount, 0, reason: 'still inside the debounce window');

      await Future<void>.delayed(const Duration(milliseconds: 100));

      // Exactly one write, carrying the final state.
      expect(sync.callCount, 1);
      expect(sync.lastEquipped?.hatId, _otherHat.id);
      expect(sync.lastEquipped?.shirtId, _shirt.id);
    });

    test('unequipItem also schedules a debounced cloud push', () async {
      final sync = _RecordingChildProfileSyncService();
      final provider = await _provider(
        userId: 'child_1',
        parentUid: 'parent_1',
        syncService: sync,
      );
      await provider.equipItem(_hat);
      await Future<void>.delayed(const Duration(milliseconds: 100));
      expect(sync.callCount, 1);

      await provider.unequipItem(AvatarItemType.hat);
      await Future<void>.delayed(const Duration(milliseconds: 100));

      expect(sync.callCount, 2);
      expect(sync.lastEquipped?.hatId, isNull);
    });

    test(
        'flushCloudSync pushes immediately without waiting for the '
        'debounce window', () async {
      final sync = _RecordingChildProfileSyncService();
      final provider = await _provider(
        userId: 'child_1',
        parentUid: 'parent_1',
        syncService: sync,
        cloudSyncDebounce: const Duration(seconds: 30),
      );

      await provider.equipItem(_hat);
      expect(sync.callCount, 0);

      await provider.flushCloudSync();

      expect(sync.callCount, 1);
      expect(sync.lastEquipped?.hatId, _hat.id);
    });

    test('a pending cloud sync is cancelled on dispose', () async {
      final sync = _RecordingChildProfileSyncService();
      final provider = await _provider(
        userId: 'child_1',
        parentUid: 'parent_1',
        syncService: sync,
      );

      await provider.equipItem(_hat);
      provider.dispose();

      await Future<void>.delayed(const Duration(milliseconds: 100));

      expect(sync.callCount, 0);
    });
  });
}
