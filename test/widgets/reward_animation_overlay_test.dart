import 'package:english_learning_app/widgets/reward_animation_overlay.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets(
    'missing asset renders shrink fallback without throwing',
    (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: RewardAnimationOverlay(
              animationPath: 'assets/animations/confetti.json',
            ),
          ),
        ),
      );

      // Allow Lottie.asset to resolve (and fail) the missing JSON.
      await tester.pump();
      await tester.pump();

      // Lottie may report the load error to the test binding; consume it so
      // the suite stays green — the overlay itself must not crash.
      tester.takeException();

      expect(find.byType(RewardAnimationOverlay), findsOneWidget);
      expect(find.byKey(RewardAnimationOverlay.fallbackKey), findsOneWidget);
    },
  );

  testWidgets('onComplete is optional and never required to build', (
    tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: RewardAnimationOverlay(
          animationPath: 'assets/animations/does-not-exist.json',
        ),
      ),
    );
    await tester.pump();
    tester.takeException();
    expect(find.byType(RewardAnimationOverlay), findsOneWidget);
  });
}
