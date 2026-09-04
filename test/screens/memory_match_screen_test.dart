// test/screens/memory_match_screen_test.dart
//
// Widget tests for MemoryMatchScreen (lib/screens/memory_match_screen.dart).
//
// MemoryMatchScreen takes its round's words directly (like ImageQuizScreen's
// `wordsForLevel`), so no repository/service fakes are needed — only the
// providers the screen reads from context: CoinProvider (coin award) and
// SoundService / SparkOverlayController (used internally by the shared
// Celebration.fire helper on a completed round).

import 'dart:math';

import 'package:english_learning_app/l10n/spark_strings.dart';
import 'package:english_learning_app/models/word_data.dart';
import 'package:english_learning_app/providers/coin_provider.dart';
import 'package:english_learning_app/providers/spark_overlay_controller.dart';
import 'package:english_learning_app/screens/memory_match_screen.dart';
import 'package:english_learning_app/services/sound_service.dart';
import 'package:english_learning_app/services/user_data_service.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

final List<WordData> _testWords = [
  WordData(word: 'Apple', imageUrl: 'assets/images/apple.png'),
  WordData(word: 'Banana', imageUrl: 'assets/images/banana.png'),
  WordData(word: 'Cat', imageUrl: 'assets/images/cat.png'),
  WordData(word: 'Dog', imageUrl: 'assets/images/dog.png'),
];

Future<CoinProvider> _pumpGame(
  WidgetTester tester, {
  List<WordData>? words,
  int pairCount = 4,
}) async {
  SharedPreferences.setMockInitialValues({});

  // The shared Celebration.fire() helper skips its confetti burst and coin
  // shower animations when reduce-motion is on — avoids a multi-second
  // animation tail after the final match that would slow pumpAndSettle().
  tester.platformDispatcher.accessibilityFeaturesTestValue =
      const FakeAccessibilityFeatures(disableAnimations: true);
  addTearDown(tester.platformDispatcher.clearAccessibilityFeaturesTestValue);

  final coinProvider = CoinProvider(
    userDataService: UserDataService(firestore: FakeFirebaseFirestore()),
  );

  await tester.pumpWidget(
    MultiProvider(
      providers: [
        ChangeNotifierProvider.value(value: coinProvider),
        ChangeNotifierProvider(create: (_) => SparkOverlayController()),
        Provider<SoundService>.value(value: SoundService()),
      ],
      child: MaterialApp(
        home: MemoryMatchScreen(
          levelId: 'test_level',
          wordsForLevel: words ?? _testWords,
          pairCount: pairCount,
          random: Random(1),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();

  return coinProvider;
}

/// Scrolls [keyValue]'s card into view (the grid can overflow the test
/// viewport) and taps it, settling the flip animation afterwards.
Future<void> _tapCard(WidgetTester tester, String keyValue) async {
  final finder = find.byKey(ValueKey(keyValue), skipOffstage: false);
  await tester.ensureVisible(finder);
  await tester.pumpAndSettle();
  await tester.tap(finder);
  await tester.pumpAndSettle();
}

/// Taps the image card and the word card for [word] in turn.
Future<void> _tapPair(WidgetTester tester, String word) async {
  await _tapCard(tester, 'image_$word');
  await _tapCard(tester, 'word_$word');
}

/// Dismisses the Celebration.fire() big-tier dialog (shown on round
/// completion) via its "נמשיך!" button, if one is currently open.
Future<void> _dismissCelebrationIfPresent(WidgetTester tester) async {
  final continueButton = find.text(SparkStrings.continueBtn);
  if (continueButton.evaluate().isNotEmpty) {
    await tester.tap(continueButton);
    await tester.pumpAndSettle();
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('MemoryMatchScreen', () {
    testWidgets('deals an image+word card for every selected word',
        (tester) async {
      await _pumpGame(tester, pairCount: 3);

      // 3 pairs -> 6 cards, one image + one word key per dealt word.
      expect(find.byType(GridView), findsOneWidget);
      final gridView = tester.widget<GridView>(find.byType(GridView));
      expect(gridView.childrenDelegate.estimatedChildCount, 6);
    });

    testWidgets('matching a pair keeps both cards revealed', (tester) async {
      await _pumpGame(tester, words: _testWords, pairCount: 4);

      await _tapPair(tester, 'Apple');

      expect(find.text('Apple'), findsOneWidget);
      expect(find.text('ניסיונות: 1'), findsOneWidget);
    });

    testWidgets('mismatched cards flip back down', (tester) async {
      await _pumpGame(tester, words: _testWords, pairCount: 4);

      await _tapCard(tester, 'image_Apple');
      await _tapCard(tester, 'word_Banana');

      // Mismatch: neither word label should remain visible once flipped back.
      await tester.pump(const Duration(milliseconds: 800));
      await tester.pumpAndSettle();

      expect(find.text('Banana'), findsNothing);
    });

    testWidgets('completing all pairs awards coins and shows victory panel',
        (tester) async {
      final coinProvider = await _pumpGame(tester, words: _testWords);

      final startingCoins = coinProvider.coins;

      for (final word in _testWords) {
        await _tapPair(tester, word.word);
      }
      await tester.pumpAndSettle();
      await _dismissCelebrationIfPresent(tester);

      expect(coinProvider.coins, startingCoins + MemoryMatchScreen.coinReward);
      expect(find.text('שחקו שוב'), findsOneWidget);
      expect(find.text('חזרה לתפריט'), findsOneWidget);
    });

    testWidgets('play again deals a fresh round', (tester) async {
      await _pumpGame(tester, words: _testWords);

      for (final word in _testWords) {
        await _tapPair(tester, word.word);
      }
      await tester.pumpAndSettle();
      await _dismissCelebrationIfPresent(tester);

      await tester.tap(find.text('שחקו שוב'));
      await tester.pumpAndSettle();

      expect(find.text('שחקו שוב'), findsNothing);
      expect(find.text('ניסיונות: 0'), findsOneWidget);
    });

    testWidgets('shows an empty state when fewer than 2 words are available',
        (tester) async {
      await _pumpGame(
        tester,
        words: [WordData(word: 'Solo', imageUrl: 'assets/images/solo.png')],
      );

      expect(find.text('אין מספיק מילים במשחק הזה'), findsOneWidget);
      expect(find.byType(GridView), findsNothing);
    });
  });
}
