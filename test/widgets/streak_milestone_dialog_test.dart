import 'package:english_learning_app/l10n/spark_strings.dart';
import 'package:english_learning_app/widgets/streak_milestone_dialog.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('shows the fire icon, streak day, and bonus coins',
      (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) {
            return Scaffold(
              body: ElevatedButton(
                onPressed: () {
                  StreakMilestoneDialog.show(context, day: 3, coins: 20);
                },
                child: const Text('open'),
              ),
            );
          },
        ),
      ),
    );

    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();

    expect(find.byKey(StreakMilestoneDialog.dialogKey), findsOneWidget);
    expect(find.byKey(StreakMilestoneDialog.fireIconKey), findsOneWidget);
    expect(find.text(SparkStrings.streakMilestoneTitle(3)), findsOneWidget);
    expect(find.text(SparkStrings.streakMilestoneCoins(20)), findsOneWidget);
  });

  testWidgets('tapping the CTA dismisses the dialog', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) {
            return Scaffold(
              body: ElevatedButton(
                onPressed: () {
                  StreakMilestoneDialog.show(context, day: 7, coins: 50);
                },
                child: const Text('open'),
              ),
            );
          },
        ),
      ),
    );

    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
    await tester.tap(find.text(SparkStrings.streakMilestoneCta));
    await tester.pumpAndSettle();

    expect(find.byKey(StreakMilestoneDialog.dialogKey), findsNothing);
  });
}
