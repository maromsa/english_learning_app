// test/screens/sentence_practice_screen_test.dart
//
// Widget tests for SentencePracticeScreen (lib/screens/sentence_practice_screen.dart).
//
// The screen takes its questions directly (like MemoryMatchScreen.wordsForLevel),
// so only the providers it reads from context are faked: CoinProvider (coin
// award), plus SoundService / SparkOverlayController used by the shared
// Celebration.fire helper on a correct answer. A fake `speak` callback stands in
// for SparkVoiceService so no TTS / network is involved.

import 'package:english_learning_app/l10n/spark_strings.dart';
import 'package:english_learning_app/models/sentence_question.dart';
import 'package:english_learning_app/providers/coin_provider.dart';
import 'package:english_learning_app/providers/spark_overlay_controller.dart';
import 'package:english_learning_app/screens/sentence_practice_screen.dart';
import 'package:english_learning_app/services/audio_settings.dart';
import 'package:english_learning_app/services/sound_service.dart';
import 'package:english_learning_app/services/user_data_service.dart';
import 'package:english_learning_app/widgets/word_speaker_button.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

final List<SentenceQuestion> _questions = [
  const SentenceQuestion(
    fullEnglishSentence: 'The cat is sleeping',
    hebrewTranslation: 'החתול ישן',
    missingWord: 'cat',
    options: ['cat', 'dog', 'fish'],
  ),
  const SentenceQuestion(
    fullEnglishSentence: 'I drink water',
    hebrewTranslation: 'אני שותה מים',
    missingWord: 'water',
    options: ['juice', 'water', 'milk'],
  ),
];

Future<CoinProvider> _pumpScreen(
  WidgetTester tester, {
  List<SentenceQuestion>? questions,
  List<String>? spoken,
}) async {
  SharedPreferences.setMockInitialValues({});
  await AudioSettings().setMuted(false);

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
        home: SentencePracticeScreen(
          questions: questions ?? _questions,
          speak: (sentence) async {
            spoken?.add(sentence);
            return true;
          },
        ),
      ),
    ),
  );
  await tester.pump();
  return coinProvider;
}

/// Taps the option card labelled [label] and flushes the correct-answer
/// async chain (coin award, micro celebration, the 700ms auto-advance, and the
/// 900ms celebration-bubble timer).
Future<void> _tapOption(WidgetTester tester, String label) async {
  await tester.tap(find.byKey(ValueKey('option_$label')));
  await tester.pump();
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 800));
  await tester.pump(const Duration(milliseconds: 300));
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('SentencePracticeScreen', () {
    testWidgets('renders the translation, blanked sentence and speaker button',
        (tester) async {
      await _pumpScreen(tester);

      expect(find.text('החתול ישן'), findsOneWidget);
      expect(find.text('The ____ is sleeping'), findsOneWidget);
      expect(find.byType(WordSpeakerButton), findsOneWidget);
      expect(find.text(SparkStrings.sentencePracticeProgress(1, 2)),
          findsOneWidget);
    });

    testWidgets('speaker button reads the full sentence aloud', (tester) async {
      final spoken = <String>[];
      await _pumpScreen(tester, spoken: spoken);

      await tester.tap(find.byType(WordSpeakerButton));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 50));

      expect(spoken, ['The cat is sleeping']);
    });

    testWidgets('a correct option awards coins and advances', (tester) async {
      final coinProvider = await _pumpScreen(tester);
      final start = coinProvider.coins;

      await _tapOption(tester, 'cat');

      expect(
        coinProvider.coins,
        start + SentencePracticeScreen.defaultCoinReward,
      );
      // Advanced to question 2.
      expect(find.text('אני שותה מים'), findsOneWidget);
      expect(find.text(SparkStrings.sentencePracticeProgress(2, 2)),
          findsOneWidget);
    });

    testWidgets('a wrong option keeps the child on the same question',
        (tester) async {
      final coinProvider = await _pumpScreen(tester);
      final start = coinProvider.coins;

      await tester.tap(find.byKey(const ValueKey('option_dog')));
      await tester.pump();

      expect(coinProvider.coins, start);
      expect(find.text('החתול ישן'), findsOneWidget);
      expect(find.text(SparkStrings.tryAgain), findsOneWidget);
    });

    testWidgets('completing every question shows the summary panel',
        (tester) async {
      await _pumpScreen(tester);

      await _tapOption(tester, 'cat');
      await _tapOption(tester, 'water');

      expect(
          find.text(SparkStrings.sentencePracticeSummaryTitle), findsOneWidget);
      expect(
          find.text(SparkStrings.sentencePracticeScore(2, 2)), findsOneWidget);
      expect(find.text(SparkStrings.levelPlayAgain), findsOneWidget);
    });

    testWidgets('play again restarts from the first question', (tester) async {
      await _pumpScreen(tester);

      await _tapOption(tester, 'cat');
      await _tapOption(tester, 'water');
      await tester.tap(find.text(SparkStrings.levelPlayAgain));
      await tester.pumpAndSettle();

      expect(find.text('החתול ישן'), findsOneWidget);
      expect(find.text(SparkStrings.sentencePracticeProgress(1, 2)),
          findsOneWidget);
    });

    testWidgets('shows an empty state when there are no playable questions',
        (tester) async {
      await _pumpScreen(tester, questions: [
        const SentenceQuestion(
          fullEnglishSentence: 'Only one choice here',
          hebrewTranslation: 'x',
          missingWord: 'choice',
          options: [],
        ),
      ]);

      expect(find.text(SparkStrings.sentencePracticeEmpty), findsOneWidget);
      expect(find.byType(WordSpeakerButton), findsNothing);
    });
  });
}
