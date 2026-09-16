import 'package:english_learning_app/models/avatar_inventory.dart';
import 'package:english_learning_app/services/avatar_inventory_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  group('AvatarInventoryService', () {
    test('applyMergedSnapshot unions cloud ids with local unlocks', () async {
      final service = AvatarInventoryService(
        prefs: await SharedPreferences.getInstance(),
      );
      await service.save(
        'child_1',
        const AvatarInventory(unlockedItemIds: {'hat_wizard'}),
      );

      await service.applyMergedSnapshot(
        'child_1',
        unlockedItemIds: const {'shirt_red'},
      );

      final merged = await service.load('child_1');
      expect(
        merged.unlockedItemIds,
        containsAll(<String>['hat_wizard', 'shirt_red']),
      );
    });
  });
}
