// test/widgets/score_display_test.dart
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter/material.dart';
import 'package:english_learning_app/widgets/score_display.dart';

void main() {
  group('ScoreDisplay', () {
    testWidgets('should display coins correctly', (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ScoreDisplay(coins: 100),
          ),
        ),
      );

      expect(find.text('100'), findsOneWidget);
    });

    testWidgets('should display zero coins', (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ScoreDisplay(coins: 0),
          ),
        ),
      );

      expect(find.text('0'), findsOneWidget);
    });

    testWidgets('should update when coins change', (WidgetTester tester) async {
      int coins = 50;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: StatefulBuilder(
              builder: (context, setState) {
                return ScoreDisplay(coins: coins);
              },
            ),
          ),
        ),
      );

      expect(find.text('50'), findsOneWidget);

      coins = 150;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ScoreDisplay(coins: coins),
          ),
        ),
      );

      expect(find.text('150'), findsOneWidget);
    });
  });
}
