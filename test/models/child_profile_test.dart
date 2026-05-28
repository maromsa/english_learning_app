import 'package:english_learning_app/models/child_profile.dart';
import 'package:english_learning_app/models/local_user.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('ChildProfile', () {
    test('create factory sets defaults', () {
      final profile = ChildProfile.create(
        displayName: 'Noa',
        avatarColor: ChildProfile.defaultAvatarColors.first,
      );

      expect(profile.displayName, 'Noa');
      expect(profile.totalStars, 0);
      expect(profile.dailyStreak, 0);
      expect(profile.pendingSync, true);
    });

    test('fromLocalUser maps legacy local user', () {
      final localUser = LocalUser(
        id: '1',
        name: 'Tom',
        age: 7,
        createdAt: DateTime(2024, 1, 1),
      );

      final profile = ChildProfile.fromLocalUser(localUser);
      expect(profile.id, '1');
      expect(profile.displayName, 'Tom');
      expect(profile.pendingSync, true);
    });

    test('toMap and fromMap round-trip locally', () {
      final profile = ChildProfile.create(
        displayName: 'Maya',
        avatarColor: 0xFFFF0000,
      ).copyWith(
        totalStars: 5,
        dailyStreak: 3,
        achievements: const {'first_correct': true},
      );

      final restored = ChildProfile.fromMap(profile.toMap());
      expect(restored.displayName, 'Maya');
      expect(restored.totalStars, 5);
      expect(restored.dailyStreak, 3);
      expect(restored.achievements['first_correct'], true);
    });
  });
}
