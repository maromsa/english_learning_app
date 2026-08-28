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
///
/// [destinationBuilder] defaults to the real (faked-out) CollectionScreen,
/// but tests that only care about navigation-stack mechanics — not
/// CollectionScreen's content — can swap in a trivial placeholder instead.
class _MenuHostScreen extends StatelessWidget {
  const _MenuHostScreen({this.destinationBuilder = _fakeCollectionScreen});

  final Widget Function() destinationBuilder;

  void _openMenu(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => GameMenuSheet(
        // Matches production's onCollection wiring in home_page.dart:
        // GameMenuGridTile already pops the sheet on tap, so this callback
        // must only push — an extra pop here would rip _MenuHostScreen off
        // the stack too (the double-pop bug this file's regression test
        // guards against).
        onCollection: () {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => destinationBuilder()),
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

Future<void> _pumpHost(
  WidgetTester tester, {
  Widget Function() destinationBuilder = _fakeCollectionScreen,
}) async {
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
                  MaterialPageRoute(
                    builder: (_) =>
                        _MenuHostScreen(destinationBuilder: destinationBuilder),
                  ),
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

  testWidgets(
      'the sheet pops exactly once, so the screen beneath survives on the '
      'stack (regression test for the Game Menu double-pop bug)',
      (tester) async {
    // A trivial destination, not the real CollectionScreen: this test is
    // only about navigation-stack mechanics (does onCollection push exactly
    // once on top of exactly one sheet-pop), which the real screen's async
    // data loading has nothing to do with — CollectionScreen itself is
    // covered by the "navigates to CollectionScreen" test above.
    await _pumpHost(
      tester,
      destinationBuilder: () => const Scaffold(
        body: Center(child: Text('collection placeholder')),
      ),
    );

    await tester.tap(find.text('open menu'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('ספר האוסף'));
    await tester.pumpAndSettle();

    expect(find.text('collection placeholder'), findsOneWidget);

    // Pop the destination and land back on _MenuHostScreen — not two
    // screens back at the root. A redundant extra pop in the onCollection
    // callback would have taken the sheet's pop AND this one, skipping
    // straight past _MenuHostScreen to the root "go to level" screen.
    Navigator.of(tester.element(find.text('collection placeholder'))).pop();
    await tester.pumpAndSettle();

    expect(find.text('open menu'), findsOneWidget);
    expect(find.text('go to level'), findsNothing);
  });
}
