// test/screens/voice_challenge_screen_test.dart
//
// Widget tests for VoiceChallengeScreen (lib/screens/voice_challenge_screen.dart).
//
// The screen takes its round's words directly (like ImageQuizScreen /
// MemoryMatchScreen), plus an injectable SpeechFeedbackService and
// WordMasteryService. A fake SpeechFeedbackService drives the
// PronunciationMicButton without touching real speech-to-text or Gemini:
// startListening() immediately reports a final transcript, and
// evaluatePronunciation() returns a canned star rating.
//
// Note: the shared SparkOrb inside PronunciationMicButton runs a perpetual
// idle pulse (even under reduce-motion), so these tests advance the clock with
// fixed `pump()` steps rather than `pumpAndSettle()`.

import 'dart:math';

import 'package:english_learning_app/l10n/spark_strings.dart';
import 'package:english_learning_app/models/pronunciation_feedback.dart';
import 'package:english_learning_app/models/word_data.dart';
import 'package:english_learning_app/providers/coin_provider.dart';
import 'package:english_learning_app/providers/spark_overlay_controller.dart';
import 'package:english_learning_app/screens/voice_challenge_screen.dart';
import 'package:english_learning_app/services/sound_service.dart';
import 'package:english_learning_app/services/speech_feedback_service.dart';
import 'package:english_learning_app/services/user_data_service.dart';
import 'package:english_learning_app/services/word_mastery_service.dart';
import 'package:english_learning_app/widgets/bouncy_button.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

final List<WordData> _testWords = [
  WordData(word: 'Apple', translation: 'תפוח', imageUrl: 'assets/images/apple.png'),
  WordData(word: 'Banana', translation: 'בננה', imageUrl: 'assets/images/banana.png'),
  WordData(word: 'Cat', translation: 'חתול', imageUrl: 'assets/images/cat.png'),
];

/// Fake that satisfies everything [PronunciationMicButton] calls on a
/// [SpeechFeedbackService] without any platform plugins.
class _FakeSpeechFeedbackService extends SpeechFeedbackService {
  _FakeSpeechFeedbackService({this.stars = 3});

  /// Star rating every [evaluatePronunciation] call returns.
  int stars;

  /// Transcript reported back for every listen.
  String heard = 'apple';

  int evaluateCalls = 0;

  @override
  bool get isListening => false;

  @override
  Future<MicrophoneAccessStatus> ensureMicrophonePermission() async =>
      MicrophoneAccessStatus.granted;

  @override
  Future<bool> initialize() async => true;

  @override
  Future<void> startListening({
    required void Function(String transcript) onTranscript,
    void Function(String finalTranscript)? onFinalTranscript,
    void Function(double soundLevel)? onSoundLevel,
    void Function(String status)? onStatus,
  }) async {
    onTranscript(heard);
    onFinalTranscript?.call(heard);
  }

  @override
  Future<void> stopListening() async {}

  @override
  Future<void> cancelListening() async {}

  @override
  Future<PronunciationFeedback> evaluatePronunciation({
    required String targetWord,
    required String transcribedText,
  }) async {
    evaluateCalls++;
    return PronunciationFeedback(
      stars: stars,
      feedbackMessage: stars >= 2 ? 'מצוין!' : 'נסו שוב',
      fromGemini: true,
    );
  }
}

/// Advances the clock in fixed steps (SparkOrb never settles).
Future<void> _tick(WidgetTester tester, {int frames = 24}) async {
  for (var i = 0; i < frames; i++) {
    await tester.pump(const Duration(milliseconds: 120));
  }
}

Future<(CoinProvider, WordMasteryService, _FakeSpeechFeedbackService)> _pumpScreen(
  WidgetTester tester, {
  _FakeSpeechFeedbackService? speech,
  List<WordData>? words,
  int roundSize = 3,
  bool provideSpeechService = true,
}) async {
  SharedPreferences.setMockInitialValues({});
  final prefs = await SharedPreferences.getInstance();
  final mastery = WordMasteryService(prefs: prefs);
  final fakeSpeech = speech ?? _FakeSpeechFeedbackService();

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
        home: VoiceChallengeScreen(
          levelId: 'test_level',
          wordsForLevel: words ?? _testWords,
          roundSize: roundSize,
          speechFeedbackService: provideSpeechService ? fakeSpeech : null,
          wordMasteryService: mastery,
          random: Random(1),
        ),
      ),
    ),
  );
  // First frame + the post-frame callback that resolves the speech service.
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 50));

  return (coinProvider, mastery, fakeSpeech);
}

/// Taps the mic; the fake reports a transcript + grade. Then settle the star
/// animation and any celebration dialog transition.
Future<void> _speak(WidgetTester tester) async {
  final mic = find.byType(BouncyButton);
  await tester.ensureVisible(mic);
  await tester.pump();
  await tester.tap(mic, warnIfMissed: false);
  await _tick(tester, frames: 30);
}

Future<void> _dismissCelebrationIfPresent(WidgetTester tester) async {
  final continueButton = find.text(SparkStrings.continueBtn);
  if (continueButton.evaluate().isNotEmpty) {
    await tester.tap(continueButton);
    await _tick(tester, frames: 10);
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('VoiceChallengeScreen', () {
    testWidgets('shows the first word, its meaning and a progress counter',
        (tester) async {
      await _pumpScreen(tester);

      expect(find.text('מילה 1 מתוך 3'), findsOneWidget);
      expect(find.byType(BouncyButton), findsOneWidget);
      // Exactly one of the three words' Hebrew meanings is on screen.
      final shown = _testWords
          .where((w) => find.text(w.translation!).evaluate().isNotEmpty)
          .length;
      expect(shown, 1);
    });

    testWidgets('a strong attempt awards coins and advances to the next word',
        (tester) async {
      final (coinProvider, _, _) =
          await _pumpScreen(tester, speech: _FakeSpeechFeedbackService(stars: 3));
      final startCoins = coinProvider.coins;

      await _speak(tester);
      await _dismissCelebrationIfPresent(tester);

      expect(coinProvider.coins, startCoins + VoiceChallengeScreen.coinReward);
      expect(find.text('מילה 2 מתוך 3'), findsOneWidget);
    });

    testWidgets('a weak attempt neither awards coins nor advances',
        (tester) async {
      final (coinProvider, _, _) =
          await _pumpScreen(tester, speech: _FakeSpeechFeedbackService(stars: 1));
      final startCoins = coinProvider.coins;

      await _speak(tester);

      expect(coinProvider.coins, startCoins);
      expect(find.text('מילה 1 מתוך 3'), findsOneWidget);
      expect(find.text(SparkStrings.micRetry), findsOneWidget);
    });

    testWidgets('every attempt is recorded into the SRS via WordMasteryService',
        (tester) async {
      final (_, mastery, _) = await _pumpScreen(
        tester,
        speech: _FakeSpeechFeedbackService(stars: 2),
        words: [WordData(word: 'Apple', translation: 'תפוח')],
        roundSize: 1,
      );

      await _speak(tester);
      await _dismissCelebrationIfPresent(tester);

      final entry = await mastery.getMastery(
        userId: 'local_guest',
        levelId: 'test_level',
        word: 'Apple',
      );
      expect(entry.bestPronunciationStars, 2);
    });

    testWidgets(
        'clearing the last word shows the victory panel; play again resets',
        (tester) async {
      await _pumpScreen(
        tester,
        speech: _FakeSpeechFeedbackService(stars: 3),
        words: [WordData(word: 'Apple', translation: 'תפוח')],
        roundSize: 1,
      );

      await _speak(tester);
      await _dismissCelebrationIfPresent(tester);

      expect(find.text('סיימתם את האתגר!'), findsOneWidget);
      expect(find.text('הגיתם נכון 1 מתוך 1 מילים'), findsOneWidget);

      await tester.tap(find.text(SparkStrings.levelPlayAgain));
      await _tick(tester, frames: 6);

      expect(find.text('סיימתם את האתגר!'), findsNothing);
      expect(find.text('מילה 1 מתוך 1'), findsOneWidget);
    });

    testWidgets('renders an empty state when there are no words', (tester) async {
      await _pumpScreen(tester, words: []);

      expect(find.text('אין מספיק מילים לאתגר הזה'), findsOneWidget);
      expect(find.byType(BouncyButton), findsNothing);
    });

    testWidgets('falls back to a notice when no speech service is available',
        (tester) async {
      await _pumpScreen(tester, provideSpeechService: false);

      expect(find.text(SparkStrings.micStartFailed), findsOneWidget);
      expect(find.byType(BouncyButton), findsNothing);
    });
  });
}
