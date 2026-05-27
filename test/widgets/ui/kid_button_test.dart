import 'package:english_learning_app/utils/app_theme.dart';
import 'package:english_learning_app/widgets/ui/kid_button.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const hapticMethod = 'HapticFeedback.vibrate';
  const hapticArg = 'HapticFeedbackType.lightImpact';

  setUp(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(SystemChannels.platform, (MethodCall call) async {
      return null;
    });
  });

  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(SystemChannels.platform, null);
  });

  Future<void> pumpKidButton(
    WidgetTester tester, {
    required String label,
    VoidCallback? onPressed,
    bool isLoading = false,
  }) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.lightTheme,
        home: Scaffold(
          body: Center(
            child: KidButton.primary(
              label: label,
              onPressed: onPressed,
              isLoading: isLoading,
            ),
          ),
        ),
      ),
    );
  }

  group('KidButton', () {
    testWidgets('renders with minimum height >= 64', (WidgetTester tester) async {
      await pumpKidButton(tester, label: 'Tap me', onPressed: () {});

      final size = tester.getSize(find.byType(KidButton));
      expect(size.height, greaterThanOrEqualTo(64));
    });

    testWidgets('tapping calls onPressed exactly once', (WidgetTester tester) async {
      var pressCount = 0;
      await pumpKidButton(tester, label: 'Tap me', onPressed: () => pressCount++);

      await tester.tap(find.byType(KidButton));
      await tester.pumpAndSettle();

      expect(pressCount, 1);

      await tester.tap(find.byType(KidButton));
      await tester.pumpAndSettle();

      expect(pressCount, 2);
    });

    testWidgets('when isLoading is true, tap does NOT call onPressed',
        (WidgetTester tester) async {
      var pressCount = 0;
      await pumpKidButton(
        tester,
        label: 'Loading',
        onPressed: () => pressCount++,
        isLoading: true,
      );

      await tester.tap(find.byType(KidButton));
      await tester.pump();

      expect(pressCount, 0);
      expect(find.byType(CircularProgressIndicator), findsOneWidget);
    });

    testWidgets('when onPressed is null, tap does NOT crash and produces no haptic',
        (WidgetTester tester) async {
      var hapticCount = 0;

      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(SystemChannels.platform, (MethodCall call) async {
        if (call.method == hapticMethod && call.arguments == hapticArg) {
          hapticCount++;
        }
        return null;
      });

      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.lightTheme,
          home: Scaffold(
            body: Center(
              child: KidButton.primary(
                label: 'Disabled',
                onPressed: null,
              ),
            ),
          ),
        ),
      );

      await tester.tap(find.byType(KidButton));
      await tester.pumpAndSettle();

      expect(hapticCount, 0);
    });

    testWidgets('HapticFeedback.lightImpact is called on tap-down',
        (WidgetTester tester) async {
      var hapticCount = 0;

      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(SystemChannels.platform, (MethodCall call) async {
        if (call.method == hapticMethod && call.arguments == hapticArg) {
          hapticCount++;
        }
        return null;
      });

      await pumpKidButton(tester, label: 'Tap me', onPressed: () {});

      final gesture = await tester.startGesture(
        tester.getCenter(find.byType(KidButton)),
      );
      await tester.pump();

      expect(hapticCount, 1);

      await gesture.up();
      await tester.pumpAndSettle();
    });
  });
}
