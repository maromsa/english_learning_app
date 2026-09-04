// test/widgets/streak_badge_test.dart
//
// Widget tests for StreakBadge (lib/widgets/streak_badge.dart) — the 🔥
// daily-streak pill shown next to the coin counter on the practice screen.

import 'package:english_learning_app/widgets/streak_badge.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('StreakBadge', () {
    testWidgets('renders the flame icon and the streak number', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(home: Scaffold(body: StreakBadge(streak: 7))),
      );

      expect(find.byIcon(Icons.local_fire_department), findsOneWidget);
      expect(find.text('7'), findsOneWidget);
    });

    testWidgets('lights the flame orange-red when streak > 0', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(home: Scaffold(body: StreakBadge(streak: 3))),
      );

      final icon = tester.widget<Icon>(
        find.byIcon(Icons.local_fire_department),
      );
      expect(icon.color, StreakBadge.activeColor);
    });

    testWidgets('renders grey when streak == 0', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(home: Scaffold(body: StreakBadge(streak: 0))),
      );

      final icon = tester.widget<Icon>(
        find.byIcon(Icons.local_fire_department),
      );
      expect(icon.color, Colors.grey.shade500);
      expect(find.text('0'), findsOneWidget);
    });

    testWidgets('exposes the streak to accessibility tools', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(home: Scaffold(body: StreakBadge(streak: 5))),
      );

      expect(find.bySemanticsLabel('רצף יומי: 5'), findsOneWidget);
    });
  });
}
