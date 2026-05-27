import 'package:english_learning_app/utils/app_theme.dart';
import 'package:english_learning_app/widgets/ui/spark_orb.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  Future<void> pumpOrb(
    WidgetTester tester, {
    required OrbState state,
    double soundLevel = 0.0,
    VoidCallback? onTap,
    double size = 120,
    bool disableAnimations = true,
  }) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.lightTheme,
        home: MediaQuery(
          data: MediaQueryData(
            disableAnimations: disableAnimations,
          ),
          child: Scaffold(
            body: Center(
              child: SparkOrb(
                state: state,
                soundLevel: soundLevel,
                onTap: onTap,
                size: size,
              ),
            ),
          ),
        ),
      ),
    );
  }

  Future<void> disposeTree(WidgetTester tester) async {
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(const Duration(seconds: 4));
  }

  group('SparkOrb', () {
    testWidgets('preview helper builds four orbs', (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: MediaQuery(
            data: const MediaQueryData(disableAnimations: true),
            child: Scaffold(body: Center(child: SparkOrb.preview())),
          ),
        ),
      );

      expect(find.byType(SparkOrb), findsNWidgets(4));
      await disposeTree(tester);
    });

    testWidgets('renders mic icon for each OrbState', (WidgetTester tester) async {
      for (final state in OrbState.values) {
        await pumpOrb(tester, state: state);
        expect(find.byIcon(Icons.mic_rounded), findsOneWidget);
        await disposeTree(tester);
      }
    });

    testWidgets('onTap fires when tapped', (WidgetTester tester) async {
      var taps = 0;
      await pumpOrb(tester, state: OrbState.idle, onTap: () => taps++);

      await tester.tap(find.byType(SparkOrb));
      await tester.pump();

      expect(taps, 1);
      await disposeTree(tester);
    });

    testWidgets('reduce motion shows static orb without pulse rings',
        (WidgetTester tester) async {
      await pumpOrb(
        tester,
        state: OrbState.listening,
        soundLevel: 0.8,
        disableAnimations: true,
      );

      expect(find.byType(AnimatedScale), findsNothing);
      await disposeTree(tester);
    });
  });
}
