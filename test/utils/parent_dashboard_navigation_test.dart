import 'package:english_learning_app/l10n/spark_strings.dart';
import 'package:english_learning_app/utils/parent_dashboard_navigation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

int _answerFromGateQuestion(WidgetTester tester) {
  final question = tester.widget<Text>(
    find.byWidgetPredicate(
      (widget) =>
          widget is Text && widget.data != null && widget.data!.contains('×'),
    ),
  );
  final match =
      RegExp(r'מה התשובה ל-(\d+) × (\d+)\?').firstMatch(question.data!);
  expect(match, isNotNull);
  final a = int.parse(match!.group(1)!);
  final b = int.parse(match.group(2)!);
  return a * b;
}

void main() {
  testWidgets('openParentDashboard navigates after correct gate answer',
      (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) {
            return Scaffold(
              body: ElevatedButton(
                onPressed: () => openParentDashboard(
                  context,
                  dashboardBuilder: (_) => const Scaffold(
                    key: Key('parent-dashboard-stub'),
                    body: Text('dashboard'),
                  ),
                ),
                child: const Text('parents'),
              ),
            );
          },
        ),
      ),
    );

    await tester.tap(find.text('parents'));
    await tester.pumpAndSettle();

    final answer = _answerFromGateQuestion(tester);
    await tester.enterText(find.byType(TextField), answer.toString());
    await tester.tap(find.text(SparkStrings.parentGateContinue));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('parent-dashboard-stub')), findsOneWidget);
  });

  testWidgets('openParentDashboard stays on map when gate is cancelled',
      (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) {
            return Scaffold(
              body: ElevatedButton(
                onPressed: () => openParentDashboard(
                  context,
                  dashboardBuilder: (_) => const Scaffold(
                    key: Key('parent-dashboard-stub'),
                    body: Text('dashboard'),
                  ),
                ),
                child: const Text('parents'),
              ),
            );
          },
        ),
      ),
    );

    await tester.tap(find.text('parents'));
    await tester.pumpAndSettle();

    await tester.tap(find.text(SparkStrings.parentGateCancel));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('parent-dashboard-stub')), findsNothing);
    expect(find.text('parents'), findsOneWidget);
  });
}
