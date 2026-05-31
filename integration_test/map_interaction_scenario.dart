import 'package:english_learning_app/screens/home_page.dart';
import 'package:english_learning_app/screens/map_screen.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

import 'support/app_bootstrap.dart';
import 'support/map_bridge_test_tools.dart';

/// Level at index 1 in [assets/data/levels.json] (and fallback levels).
const kMapEnterLevelIndex = 1;
const kMapEnterLevelTitle = 'שלב 2: חיות';

/// Registers the map postMessage bridge scenario (used by [map_interaction_test.dart]).
void registerMapInteractionTests({IntegrationTestWidgetsFlutterBinding? binding}) {
  testWidgets(
    'enter_level postMessage from 3D map navigates to level screen',
    (WidgetTester tester) async {
      if (!kIsWeb) {
        return;
      }

      await bootstrapMapIntegrationApp();

      await _pumpUntil(
        tester,
        () => find.byType(MapScreen).evaluate().isNotEmpty,
        label: 'MapScreen',
      );

      await _pumpUntil(
        tester,
        () => find.byType(CircularProgressIndicator).evaluate().isEmpty,
        label: 'MapScreen level data',
        maxPumps: 200,
      );

      expect(
        await waitForMap3dIframe(timeout: const Duration(seconds: 60)),
        isTrue,
        reason: '3D map iframe (HtmlElementView) did not appear in the DOM',
      );

      await _pumpUntil(
        tester,
        () {
          return find
              .descendant(
                of: find.byType(MapScreen),
                matching: find.byType(HtmlElementView),
              )
              .evaluate()
              .isNotEmpty;
        },
        label: 'HtmlElementView',
      );

      signalMap3dLoaded();
      await _pumpFrames(tester, count: 10);

      simulateMap3dPostMessage({
        'type': 'enter_level',
        'index': kMapEnterLevelIndex,
      });

      await _pumpUntil(
        tester,
        () => find.byType(MyHomePage).evaluate().isNotEmpty,
        label: 'MyHomePage after enter_level',
        maxPumps: 120,
      );

      expect(find.byType(MyHomePage), findsOneWidget);
      expect(find.text(kMapEnterLevelTitle), findsAtLeastNWidgets(1));

      // Let the fadeScale route transition (300 ms) finish before teardown.
      await tester.pump(const Duration(milliseconds: 350));
    },
    skip: !kIsWeb,
  );
}

Future<void> _pumpFrames(WidgetTester tester, {required int count}) async {
  for (var i = 0; i < count; i++) {
    await tester.pump(const Duration(milliseconds: 100));
  }
}

Future<void> _pumpUntil(
  WidgetTester tester,
  bool Function() condition, {
  required String label,
  int maxPumps = 100,
}) async {
  for (var i = 0; i < maxPumps; i++) {
    await tester.pump(const Duration(milliseconds: 100));
    if (condition()) {
      return;
    }
  }
  fail('Timed out waiting for $label');
}
