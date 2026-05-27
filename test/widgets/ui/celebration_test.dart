import 'package:english_learning_app/l10n/spark_strings.dart';
import 'package:english_learning_app/services/sound_service.dart';
import 'package:english_learning_app/providers/spark_overlay_controller.dart';
import 'package:english_learning_app/utils/app_theme.dart';
import 'package:english_learning_app/widgets/ui/celebration.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late SoundService soundService;
  late SparkOverlayController sparkController;

  setUp(() {
    soundService = SoundService();
    soundService.debugOnPlaySoftChime = null;
    soundService.debugOnPlayPop = null;
    soundService.debugOnPlayFanfare = null;
    soundService.debugOnPlayEpic = null;
    sparkController = SparkOverlayController();
  });

  Future<void> pumpCelebrationHost(
    WidgetTester tester, {
    required Widget child,
    bool disableAnimations = false,
  }) async {
    await tester.pumpWidget(
      MultiProvider(
        providers: [
          Provider<SoundService>.value(value: soundService),
          ChangeNotifierProvider<SparkOverlayController>.value(
            value: sparkController,
          ),
        ],
        child: MaterialApp(
          theme: AppTheme.lightTheme,
          home: MediaQuery(
            data: MediaQueryData(disableAnimations: disableAnimations),
            child: Scaffold(body: child),
          ),
        ),
      ),
    );
  }

  group('Celebration.fire', () {
    testWidgets('micro plays soft chime, flashes Spark, returns within 700ms',
        (WidgetTester tester) async {
      var chimePlayed = false;
      soundService.debugOnPlaySoftChime = () => chimePlayed = true;

      await pumpCelebrationHost(
        tester,
        child: Builder(
          builder: (context) {
            return ElevatedButton(
              onPressed: () async {
                final stopwatch = Stopwatch()..start();
                await Celebration.fire(
                  context,
                  tier: CelebrationTier.micro,
                  word: 'cat',
                );
                stopwatch.stop();
                expect(stopwatch.elapsedMilliseconds, lessThan(700));
              },
              child: const Text('fire'),
            );
          },
        ),
      );

      await tester.tap(find.text('fire'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 650));

      expect(chimePlayed, isTrue);
      expect(sparkController.debugFlashCount, greaterThanOrEqualTo(1));
    });

    testWidgets('small plays pop SFX and renders no dialog',
        (WidgetTester tester) async {
      var popPlayed = false;
      soundService.debugOnPlayPop = () => popPlayed = true;

      await pumpCelebrationHost(
        tester,
        disableAnimations: true,
        child: Builder(
          builder: (context) {
            return ElevatedButton(
              onPressed: () => Celebration.fire(
                context,
                tier: CelebrationTier.small,
              ),
              child: const Text('small'),
            );
          },
        ),
      );

      await tester.tap(find.text('small'));
      await tester.pump();

      expect(popPlayed, isTrue);
      expect(find.byType(Dialog), findsNothing);
    });

    testWidgets('big shows dialog with supplied word visible',
        (WidgetTester tester) async {
      soundService.debugOnPlayFanfare = () {};

      await pumpCelebrationHost(
        tester,
        disableAnimations: true,
        child: Builder(
          builder: (context) {
            return ElevatedButton(
              onPressed: () async {
                await Celebration.fire(
                  context,
                  tier: CelebrationTier.big,
                  word: 'elephant',
                  compliment: 'great',
                  starsEarned: 3,
                );
              },
              child: const Text('big'),
            );
          },
        ),
      );

      await tester.tap(find.text('big'));
      await tester.pumpAndSettle();

      expect(find.text('elephant'), findsOneWidget);
      expect(find.text('great'), findsOneWidget);
    });

    testWidgets('epic pushes opaque false route', (WidgetTester tester) async {
      soundService.debugOnPlayEpic = () {};

      await pumpCelebrationHost(
        tester,
        disableAnimations: true,
        child: Builder(
          builder: (context) {
            return ElevatedButton(
              onPressed: () async {
                await Celebration.fire(
                  context,
                  tier: CelebrationTier.epic,
                );
              },
              child: const Text('epic'),
            );
          },
        ),
      );

      await tester.tap(find.text('epic'));
      await tester.pumpAndSettle();

      expect(find.text(SparkStrings.chapterDone), findsOneWidget);
      final route = ModalRoute.of(
        tester.element(find.text(SparkStrings.chapterDone)),
      );
      expect(route, isNotNull);
      expect(route!.opaque, isFalse);
    });
  });
}
