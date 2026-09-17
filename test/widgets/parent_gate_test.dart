import 'dart:math';

import 'package:english_learning_app/l10n/spark_strings.dart';
import 'package:english_learning_app/widgets/parent_gate.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('ParentGateMath', () {
    test('generateFactors stays in 5–12 inclusive', () {
      final random = Random(42);
      for (var i = 0; i < 80; i++) {
        final (a, b) = ParentGateMath.generateFactors(random);
        expect(
            a,
            inInclusiveRange(
                ParentGateMath.minFactor, ParentGateMath.maxFactor));
        expect(
            b,
            inInclusiveRange(
                ParentGateMath.minFactor, ParentGateMath.maxFactor));
      }
    });
  });

  testWidgets('correct answer pops true and closes the gate', (tester) async {
    bool? result;
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) {
            return Scaffold(
              body: ElevatedButton(
                onPressed: () async {
                  result = await showDialog<bool>(
                    context: context,
                    builder: (_) => const ParentGateDialog(
                      factorA: 6,
                      factorB: 7,
                    ),
                  );
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

    expect(find.byKey(ParentGateDialog.dialogKey), findsOneWidget);
    expect(find.text(SparkStrings.parentGateQuestion(6, 7)), findsOneWidget);

    await tester.enterText(find.byKey(ParentGateDialog.answerFieldKey), '42');
    await tester.tap(find.text(SparkStrings.parentGateContinue));
    await tester.pumpAndSettle();

    expect(find.byType(ParentGateDialog), findsNothing);
    expect(result, isTrue);
  });

  testWidgets('wrong answer clears the field, shows an error, and stays open',
      (tester) async {
    bool? result;
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) {
            return Scaffold(
              body: ElevatedButton(
                onPressed: () async {
                  result = await showDialog<bool>(
                    context: context,
                    builder: (_) => const ParentGateDialog(
                      factorA: 8,
                      factorB: 9,
                    ),
                  );
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

    await tester.enterText(find.byKey(ParentGateDialog.answerFieldKey), '10');
    await tester.tap(find.text(SparkStrings.parentGateContinue));
    await tester.pumpAndSettle();

    expect(find.byType(ParentGateDialog), findsOneWidget);
    expect(find.text(SparkStrings.parentGateWrong), findsOneWidget);
    expect(tester.widget<TextField>(find.byType(TextField)).controller!.text,
        isEmpty);
    expect(result, isNull);
  });

  testWidgets('cancel pops false', (tester) async {
    bool? result;
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) {
            return Scaffold(
              body: ElevatedButton(
                onPressed: () async {
                  result = await showDialog<bool>(
                    context: context,
                    builder: (_) => const ParentGateDialog(
                      factorA: 5,
                      factorB: 5,
                    ),
                  );
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
    await tester.tap(find.text(SparkStrings.parentGateCancel));
    await tester.pumpAndSettle();

    expect(result, isFalse);
  });

  testWidgets('random questions use factors between 5 and 12', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: ParentGateDialog(random: Random(11)),
      ),
    );
    await tester.pump();

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
    expect(a, inInclusiveRange(5, 12));
    expect(b, inInclusiveRange(5, 12));
  });
}
