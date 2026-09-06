// test/screens/achievements_screen_test.dart
//
// Widget tests for the Achievements Showcase ("Trophy Room").
// Verifies that the locked and unlocked states each render their distinct
// visual treatment, and that tapping a medal opens its detail sheet.

import 'package:english_learning_app/screens/achievements_screen.dart';
import 'package:english_learning_app/services/achievement_service.dart';
import 'package:english_learning_app/services/user_data_service.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Builds an [AchievementService] with [unlockedIds] already earned.
///
/// The service does real async I/O (SharedPreferences, Firestore), so it is
/// created inside [WidgetTester.runAsync] — the fake test clock cannot drive
/// those futures.
Future<AchievementService> _makeService(
  WidgetTester tester,
  List<String> unlockedIds,
) async {
  SharedPreferences.setMockInitialValues({});
  late AchievementService service;
  await tester.runAsync(() async {
    service = AchievementService(
      userDataService: UserDataService(firestore: FakeFirebaseFirestore()),
    );
    // The constructor kicks off loadAchievements() without awaiting it — drain
    // the event queue so it fully settles before we mutate state, otherwise it
    // resolves later and clobbers our unlocks back to false.
    await pumpEventQueue();
    for (final id in unlockedIds) {
      await service.unlockAchievement(id);
    }
    await pumpEventQueue();
  });
  return service;
}

Future<void> _pump(WidgetTester tester, AchievementService service) async {
  await tester.pumpWidget(
    ChangeNotifierProvider<AchievementService>.value(
      value: service,
      child: const MaterialApp(home: AchievementsScreen()),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('all-locked state: every medal shows a padlock and zero earned',
      (tester) async {
    final service = await _makeService(tester, const []);
    await _pump(tester, service);

    // Hero counter reads 0 / <total>.
    expect(find.text('0 / ${service.totalCount}'), findsOneWidget);

    // Padlocks are rendered for the locked medals; no "earned" check badges.
    expect(find.byIcon(Icons.lock_rounded), findsWidgets);
    expect(find.byIcon(Icons.verified_rounded), findsNothing);
  });

  testWidgets('unlocked state: earned medal shows its title + a check badge',
      (tester) async {
    final service = await _makeService(tester, const ['first_correct']);
    await _pump(tester, service);

    // Hero counter now reflects the single unlock.
    expect(find.text('1 / ${service.totalCount}'), findsOneWidget);
    // First Steps category banner: 1 of its 4 earned.
    expect(find.text('1 / 4'), findsOneWidget);

    // The unlocked medal renders its title (locked ones render no text) and a
    // check badge.
    expect(find.text('First Word Learned'), findsOneWidget);
    expect(find.byIcon(Icons.verified_rounded), findsWidgets);
  });

  testWidgets('tapping a medal opens its detail sheet with the description',
      (tester) async {
    final service = await _makeService(tester, const ['first_correct']);
    await _pump(tester, service);

    await tester.tap(find.byKey(const Key('achievement_first_correct')));
    await tester.pumpAndSettle();

    expect(find.text('ענית נכון על המילה הראשונה שלך!'), findsOneWidget);
    expect(find.text('+20'), findsOneWidget);
  });

  testWidgets('tapping a locked medal shows the still-locked sheet',
      (tester) async {
    final service = await _makeService(tester, const []);
    await _pump(tester, service);

    await tester.tap(find.byKey(const Key('achievement_first_correct')));
    await tester.pumpAndSettle();

    expect(find.text('עדיין נעול 🔒'), findsOneWidget);
  });
}
