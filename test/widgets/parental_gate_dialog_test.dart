import 'package:english_learning_app/widgets/parental_gate_dialog.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('parental gate accepts correct answer', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) {
            return Scaffold(
              body: ElevatedButton(
                onPressed: () {
                  showDialog<void>(
                    context: context,
                    builder: (_) => const ParentalGateDialog(
                      factorA: 8,
                      factorB: 4,
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

    await tester.enterText(find.byType(TextField), '32');
    await tester.tap(find.text('המשך'));
    await tester.pumpAndSettle();

    expect(find.byType(ParentalGateDialog), findsNothing);
  });

  testWidgets('parental gate rejects wrong answer', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) {
            return Scaffold(
              body: ElevatedButton(
                onPressed: () {
                  showDialog<void>(
                    context: context,
                    builder: (_) => const ParentalGateDialog(
                      factorA: 8,
                      factorB: 4,
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

    await tester.enterText(find.byType(TextField), '9');
    await tester.tap(find.text('המשך'));
    await tester.pumpAndSettle();

    expect(find.byType(ParentalGateDialog), findsOneWidget);
    expect(find.text('לא נכון. ננסה שוב?'), findsOneWidget);
  });
}
