// test/widgets/streak_badge_test.dart
//
// Widget tests for StreakBadge (lib/widgets/streak_badge.dart) — the 🔥
// daily-streak pill shown in the map HUD and next to the coin counter.

import 'package:english_learning_app/widgets/streak_badge.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('StreakBadge', () {
    testWidgets('renders the flame icon and the streak number', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(body: StreakBadge(streakCount: 7)),
        ),
      );

      expect(find.byIcon(Icons.local_fire_department), findsOneWidget);
      expect(find.text('7'), findsOneWidget);
    });

    testWidgets('lights the flame orange-red when streak > 0', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(body: StreakBadge(streakCount: 3)),
        ),
      );

      final icon = tester.widget<Icon>(
        find.byIcon(Icons.local_fire_department),
      );
      expect(icon.color, StreakBadge.activeColor);
    });

    testWidgets('uses a warm background when streak > 0', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(body: StreakBadge(streakCount: 4)),
        ),
      );

      final container = tester.widget<Container>(
        find.descendant(
          of: find.byType(StreakBadge),
          matching: find.byType(Container),
        ),
      );
      final decoration = container.decoration! as BoxDecoration;
      expect(decoration.color, StreakBadge.warmBackground);
    });

    testWidgets('renders grey when streak == 0', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(body: StreakBadge(streakCount: 0)),
        ),
      );

      final icon = tester.widget<Icon>(
        find.byIcon(Icons.local_fire_department),
      );
      expect(icon.color, Colors.grey.shade500);
      expect(find.text('0'), findsOneWidget);
    });

    testWidgets('exposes the streak to accessibility tools', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(body: StreakBadge(streakCount: 5)),
        ),
      );

      expect(find.bySemanticsLabel('רצף יומי: 5'), findsOneWidget);
    });

    testWidgets('does not overflow in a tight HUD slot', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: Center(
              child: SizedBox(
                width: 48,
                height: 24,
                child: StreakBadge(streakCount: 123456),
              ),
            ),
          ),
        ),
      );

      expect(tester.takeException(), isNull);
      expect(find.byType(StreakBadge), findsOneWidget);
      expect(find.text('123456'), findsOneWidget);
    });

    testWidgets('bounces when the streak count updates', (tester) async {
      Widget harness(int count) {
        return MaterialApp(
          home: Scaffold(body: StreakBadge(streakCount: count)),
        );
      }

      await tester.pumpWidget(harness(1));
      await tester.pumpWidget(harness(2));
      await tester.pump(const Duration(milliseconds: 80));

      final scale = tester.widget<ScaleTransition>(
        find.byKey(const ValueKey<String>('streak-badge-scale')),
      );
      expect(scale.scale.value, isNot(1.0));

      await tester.pumpAndSettle();
      expect(find.text('2'), findsOneWidget);
    });
  });
}
