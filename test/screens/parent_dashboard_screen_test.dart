import 'package:english_learning_app/l10n/spark_strings.dart';
import 'package:english_learning_app/models/daily_streak.dart';
import 'package:english_learning_app/models/learned_word.dart';
import 'package:english_learning_app/providers/coin_provider.dart';
import 'package:english_learning_app/providers/daily_streak_provider.dart';
import 'package:english_learning_app/providers/word_bank_provider.dart';
import 'package:english_learning_app/screens/parent_dashboard_screen.dart';
import 'package:english_learning_app/services/user_data_service.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

LearnedWord _word(String english) => LearnedWord(
      word: english,
      translation: english,
      dateLearned: DateTime(2026, 9, 17),
    );

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  testWidgets('reads vocabulary, streak, and coins from providers',
      (tester) async {
    final coins = CoinProvider(
      userDataService: UserDataService(firestore: FakeFirebaseFirestore()),
    );
    await coins.setCoins(37);

    final bank = WordBankProvider(
      initial: [_word('cat'), _word('dog'), _word('sun')],
    );
    final streak = DailyStreakProvider(
      initial: const DailyStreak(currentStreak: 6),
    );

    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider.value(value: bank),
          ChangeNotifierProvider.value(value: streak),
          ChangeNotifierProvider.value(value: coins),
        ],
        child: const MaterialApp(
          home: ParentDashboardScreen(),
        ),
      ),
    );
    await tester.pump();

    expect(find.text(SparkStrings.parentDashboardTitle), findsOneWidget);
    expect(
        find.text(SparkStrings.parentDashboardLiveVocabulary), findsOneWidget);
    expect(
        find.byKey(ParentDashboardScreen.vocabularyValueKey), findsOneWidget);
    expect(
      tester
          .widget<Text>(find.byKey(ParentDashboardScreen.vocabularyValueKey))
          .data,
      '3',
    );
    expect(
      tester
          .widget<Text>(find.byKey(ParentDashboardScreen.streakValueKey))
          .data,
      SparkStrings.parentDashboardStreakDays(6),
    );
    expect(
      tester.widget<Text>(find.byKey(ParentDashboardScreen.coinsValueKey)).data,
      '37',
    );
  });
}
