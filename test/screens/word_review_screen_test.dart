import 'dart:math';

import 'package:english_learning_app/l10n/spark_strings.dart';
import 'package:english_learning_app/models/learned_word.dart';
import 'package:english_learning_app/providers/coin_provider.dart';
import 'package:english_learning_app/providers/spark_overlay_controller.dart';
import 'package:english_learning_app/providers/word_bank_provider.dart';
import 'package:english_learning_app/providers/word_review_provider.dart';
import 'package:english_learning_app/screens/word_review_screen.dart';
import 'package:english_learning_app/services/audio_settings.dart';
import 'package:english_learning_app/services/sound_service.dart';
import 'package:english_learning_app/services/tts_service.dart';
import 'package:english_learning_app/services/user_data_service.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _FakeTtsService extends TtsService {
  _FakeTtsService();

  final List<String> spoken = [];

  @override
  Future<void> speak(String text) async {
    final trimmed = text.trim();
    if (trimmed.isEmpty) return;
    spoken.add(trimmed);
  }
}

LearnedWord _word(String english, String hebrew) => LearnedWord(
      word: english,
      translation: hebrew,
      dateLearned: DateTime(2026, 9, 16),
    );

Future<(CoinProvider, WordReviewProvider, _FakeTtsService)> _pumpScreen(
  WidgetTester tester, {
  required List<LearnedWord> bankWords,
  int randomSeed = 1,
}) async {
  SharedPreferences.setMockInitialValues({});
  await AudioSettings().setMuted(false);
  tester.platformDispatcher.accessibilityFeaturesTestValue =
      const FakeAccessibilityFeatures(disableAnimations: true);
  addTearDown(tester.platformDispatcher.clearAccessibilityFeaturesTestValue);

  final coins = CoinProvider(
    userDataService: UserDataService(firestore: FakeFirebaseFirestore()),
  );
  final bank = WordBankProvider(initial: bankWords);
  final review = WordReviewProvider(wordBank: bank, random: Random(randomSeed));
  review.generateQuiz();
  final tts = _FakeTtsService();

  await tester.pumpWidget(
    MultiProvider(
      providers: [
        ChangeNotifierProvider.value(value: coins),
        ChangeNotifierProvider.value(value: review),
        ChangeNotifierProvider(create: (_) => SparkOverlayController()),
        Provider<SoundService>.value(value: SoundService()),
        Provider<TtsService>.value(value: tts),
      ],
      child: MaterialApp(
        home: WordReviewScreen(ttsService: tts),
      ),
    ),
  );
  await tester.pump();
  await tester.pump();
  return (coins, review, tts);
}

void main() {
  testWidgets('shows the English prompt, speaks it, and awards coins on a hit',
      (tester) async {
    final (coins, review, tts) = await _pumpScreen(
      tester,
      bankWords: [
        _word('cat', 'חתול'),
        _word('dog', 'כלב'),
        _word('sun', 'שמש'),
        _word('water', 'מים'),
      ],
    );

    final prompt = review.currentWord!.word;
    expect(find.byKey(WordReviewScreen.promptKey), findsOneWidget);
    expect(find.text(prompt), findsWidgets);
    expect(tts.spoken, contains(prompt));

    final start = coins.coins;
    await tester.tap(
      find.byKey(WordReviewScreen.optionKey(review.correctTranslation!)),
    );
    await tester.pump();
    await tester.pump();

    expect(coins.coins, start + WordReviewScreen.defaultCoinReward);
    expect(find.byKey(WordReviewScreen.successKey), findsOneWidget);

    await tester.pump(const Duration(milliseconds: 1500));
  });

  testWidgets('a wrong pick stays on the same word and shows try-again',
      (tester) async {
    final (_, review, _) = await _pumpScreen(
      tester,
      bankWords: [
        _word('cat', 'חתול'),
        _word('dog', 'כלב'),
        _word('sun', 'שמש'),
        _word('water', 'מים'),
      ],
    );
    final prompt = review.currentWord!.word;
    final wrong = review.options.firstWhere(
      (option) => option != review.correctTranslation,
    );

    await tester.tap(find.byKey(WordReviewScreen.optionKey(wrong)));
    await tester.pump();

    expect(find.text(SparkStrings.tryAgain), findsOneWidget);
    expect(review.currentWord!.word, prompt);
  });
}
