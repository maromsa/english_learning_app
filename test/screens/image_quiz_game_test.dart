import 'package:english_learning_app/providers/coin_provider.dart';
import 'package:english_learning_app/screens/image_quiz_game.dart';
import 'package:english_learning_app/widgets/answer_button.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('quiz items use image assets that exist', () async {
    for (final item in quizItems) {
      final data = await rootBundle.load(item.imageAsset);
      expect(data.lengthInBytes, greaterThan(0), reason: 'Asset ${item.imageAsset} should not be empty');
    }
  });

  test('quiz items include the correct answer among the options', () {
    for (final item in quizItems) {
      final options = item.getShuffledAnswers();
      expect(options, contains(item.correctAnswer));
      expect(options.length, item.wrongAnswers.length + 1);
    }
  });

  testWidgets('awards coins and updates score after a correct answer', (tester) async {
    SharedPreferences.setMockInitialValues({});
    final coinProvider = CoinProvider();

    await tester.pumpWidget(
      ChangeNotifierProvider<CoinProvider>.value(
        value: coinProvider,
        child: const MaterialApp(
          home: ImageQuizGame(),
        ),
      ),
    );

    await tester.pumpAndSettle();

    final correctAnswerFinder = find.text(quizItems.first.correctAnswer);
    expect(correctAnswerFinder, findsOneWidget);

    await tester.ensureVisible(correctAnswerFinder);
    await tester.tap(correctAnswerFinder, warnIfMissed: false);
    await tester.pumpAndSettle();

    expect(coinProvider.coins, greaterThanOrEqualTo(10));
    expect(find.textContaining('Great job!'), findsOneWidget);

    final nextButtonFinder = find.widgetWithText(ElevatedButton, 'Next question');
    expect(nextButtonFinder, findsOneWidget);
    await tester.ensureVisible(nextButtonFinder);
    final ElevatedButton nextButton = tester.widget(nextButtonFinder);
    expect(nextButton.onPressed, isNotNull);
  });

  testWidgets('hint removes one wrong answer per question', (tester) async {
    SharedPreferences.setMockInitialValues({});
    final coinProvider = CoinProvider();

    await tester.pumpWidget(
      ChangeNotifierProvider<CoinProvider>.value(
        value: coinProvider,
        child: const MaterialApp(
          home: ImageQuizGame(),
        ),
      ),
    );

    await tester.pumpAndSettle();

    expect(find.byType(AnswerButton), findsNWidgets(4));

    final hintButtonFinder = find.text('Get a hint');
    await tester.ensureVisible(hintButtonFinder);
    await tester.tap(hintButtonFinder, warnIfMissed: false);
    await tester.pumpAndSettle();

    expect(find.byType(AnswerButton), findsNWidgets(3));
    expect(find.text('Hint used'), findsOneWidget);

    await tester.tap(find.text('Hint used'));
    await tester.pumpAndSettle();

    expect(find.byType(AnswerButton), findsNWidgets(3));
  });
}
