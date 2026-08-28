// test/widgets/game_menu_test.dart
//
// Widget tests for GameMenuSheet (lib/screens/home_page.dart) — the
// frosted-glass "תפריט משחק" bottom sheet opened from the map/practice
// screens.

import 'package:english_learning_app/providers/user_session_provider.dart';
import 'package:english_learning_app/screens/collection_screen.dart';
import 'package:english_learning_app/screens/home_page.dart';
import 'package:english_learning_app/services/level_unlock_service.dart';
import 'package:english_learning_app/services/offline_practice_service.dart';
import 'package:english_learning_app/services/srs_service.dart';
import 'package:english_learning_app/utils/offline_word_loader.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../support/fake_firebase_services.dart';

/// A CollectionScreen with every Firestore/sqflite-touching dependency
/// faked out — see test/support/fake_firebase_services.dart for why this
/// matters (default constructors eagerly touch a real, uninitialized
/// FirebaseFirestore.instance).
CollectionScreen _fakeCollectionScreen() {
  return CollectionScreen(
    levelProgressService: fakeLevelProgressService(),
    offlineWordLoader: OfflineWordLoader(
      offlinePracticeService: OfflinePracticeService(
        levelUnlockService: LevelUnlockService(
          levelProgressService: fakeLevelProgressService(),
        ),
      ),
    ),
    srsService: SrsService(firestore: FakeFirebaseFirestore()),
  );
}

/// A minimal host screen standing in for the real map/practice screen that
/// opens GameMenuSheet in production. Pushed on top of a root route (rather
/// than being MaterialApp.home itself) so the test exercises the same
/// navigation depth the real app has when the sheet is opened.
class _MenuHostScreen extends StatelessWidget {
  const _MenuHostScreen();

  void _openMenu(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => GameMenuSheet(
        onCollection: () {
          Navigator.pop(context);
          Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => _fakeCollectionScreen()),
          );
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: ElevatedButton(
          onPressed: () => _openMenu(context),
          child: const Text('open menu'),
        ),
      ),
    );
  }
}

Future<void> _pumpHost(WidgetTester tester) async {
  SharedPreferences.setMockInitialValues({});
  await tester.pumpWidget(
    ChangeNotifierProvider<UserSessionProvider>(
      create: (_) => UserSessionProvider(),
      child: MaterialApp(
        home: Builder(
          builder: (context) => Scaffold(
            body: Center(
              child: ElevatedButton(
                // A root route beneath the host, matching production where
                // the game-menu host screen is itself pushed from the map.
                onPressed: () => Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const _MenuHostScreen()),
                ),
                child: const Text('go to level'),
              ),
            ),
          ),
        ),
      ),
    ),
  );
  await tester.tap(find.text('go to level'));
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('renders a tile for every supplied callback, none for the rest',
      (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: GameMenuSheet(),
        ),
      ),
    );

    // No callbacks supplied → no tiles, just the sheet title.
    expect(find.text('תפריט משחק'), findsOneWidget);
    expect(find.text('חנות'), findsNothing);
    expect(find.text('ספר האוסף'), findsNothing);
  });

  testWidgets('shows the collection entry only when onCollection is supplied',
      (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: GameMenuSheet(onCollection: () {}),
        ),
      ),
    );

    expect(find.text('ספר האוסף'), findsOneWidget);
    expect(find.byIcon(Icons.menu_book_rounded), findsOneWidget);
  });

  testWidgets('tapping "ספר האוסף" navigates to CollectionScreen',
      (tester) async {
    await _pumpHost(tester);

    await tester.tap(find.text('open menu'));
    await tester.pumpAndSettle();
    expect(find.text('ספר האוסף'), findsOneWidget);

    await tester.tap(find.text('ספר האוסף'));
    await tester.pumpAndSettle();

    expect(find.byType(CollectionScreen), findsOneWidget);
    // The sheet closed along with it — no leftover menu tile on screen.
    expect(find.text('ספר האוסף'), findsNothing);
  });
}
