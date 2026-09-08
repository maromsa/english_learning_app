// test/widgets/weekly_recap_card_test.dart

import 'package:english_learning_app/l10n/spark_strings.dart';
import 'package:english_learning_app/models/parent_dashboard_stats.dart';
import 'package:english_learning_app/models/weekly_recap.dart';
import 'package:english_learning_app/widgets/weekly_recap_card.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// Builds a 7-day recap; [wordsByDay] is oldest-first, padded/truncated to 7.
WeeklyRecap _recap({
  List<int> wordsByDay = const [0, 0, 0, 0, 0, 0, 0],
  List<int> minutesByDay = const [0, 0, 0, 0, 0, 0, 0],
  int coins = 0,
  int mastered = 0,
}) {
  final base = DateTime(2026, 9, 8);
  final days = List.generate(7, (i) {
    return DailyActivity(
      date: base.subtract(Duration(days: 6 - i)),
      words: i < wordsByDay.length ? wordsByDay[i] : 0,
      minutes: i < minutesByDay.length ? minutesByDay[i] : 0,
    );
  });
  return WeeklyRecap(
    days: days,
    coinsEarned: coins,
    wordsMasteredThisWeek: mastered,
  );
}

Widget _host(WeeklyRecap recap) => MaterialApp(
      home: Scaffold(
        body: SingleChildScrollView(child: WeeklyRecapCard(recap: recap)),
      ),
    );

void main() {
  testWidgets('renders the four headline numbers', (tester) async {
    await tester.pumpWidget(_host(_recap(
      wordsByDay: const [2, 0, 4, 0, 3, 0, 1], // 4 active days, 10 words
      minutesByDay: const [3, 0, 5, 0, 4, 0, 2], // 14 minutes
      coins: 85,
    )));

    expect(find.text(SparkStrings.weeklyRecapTitle), findsOneWidget);
    expect(find.text('4/7'), findsOneWidget); // active days
    expect(find.text('10'), findsOneWidget); // words practiced
    expect(find.text('14'), findsOneWidget); // minutes
    expect(find.text('85'), findsOneWidget); // coins
  });

  testWidgets('shows the best-day line when there was activity',
      (tester) async {
    await tester
        .pumpWidget(_host(_recap(wordsByDay: const [1, 0, 9, 0, 0, 0, 2])));
    expect(find.textContaining('היום החזק ביותר'), findsOneWidget);
    expect(find.textContaining('9'), findsWidgets);
  });

  testWidgets('hides the mastery line at zero, shows it above zero',
      (tester) async {
    await tester
        .pumpWidget(_host(_recap(wordsByDay: const [1, 1, 1, 1, 1, 1, 1])));
    expect(find.textContaining('לשליטה מלאה השבוע'), findsNothing);

    await tester.pumpWidget(_host(_recap(
      wordsByDay: const [1, 1, 1, 1, 1, 1, 1],
      mastered: 3,
    )));
    expect(find.text(SparkStrings.weeklyRecapMastered(3)), findsOneWidget);
  });

  testWidgets('shows the empty-state nudge when the week was idle',
      (tester) async {
    await tester.pumpWidget(_host(_recap()));

    expect(find.text(SparkStrings.weeklyRecapEmpty), findsOneWidget);
    expect(find.text('0/7'), findsNothing); // tiles are hidden in empty state
  });
}
