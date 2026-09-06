// test/widgets/user/child_profile_create_dialog_test.dart
//
// Widget tests for ChildProfileCreateDialog — the name + colour + animal-emoji
// picker shared by the profile selection screen and the quick switcher sheet.

import 'package:english_learning_app/models/child_profile.dart';
import 'package:english_learning_app/widgets/user/child_profile_create_dialog.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// Host that opens the dialog and captures whatever it pops.
class _Host extends StatelessWidget {
  const _Host(this.onResult);
  final ValueChanged<ChildProfileDraft?> onResult;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      home: Scaffold(
        body: Builder(
          builder: (context) => Center(
            child: ElevatedButton(
              onPressed: () async {
                onResult(
                  await showDialog<ChildProfileDraft>(
                    context: context,
                    builder: (_) => const ChildProfileCreateDialog(),
                  ),
                );
              },
              child: const Text('open'),
            ),
          ),
        ),
      ),
    );
  }
}

Future<void> _open(WidgetTester tester, ValueChanged<ChildProfileDraft?> onResult)
    async {
  await tester.pumpWidget(_Host(onResult));
  await tester.tap(find.text('open'));
  await tester.pumpAndSettle();
}

/// The emoji chip for [glyph] inside the horizontal animal strip (not the
/// preview avatar, which can show the same glyph once selected).
Finder _animalChip(String glyph) => find.descendant(
      of: find.byType(ListView),
      matching: find.text(glyph),
    );

void main() {
  testWidgets('renders the name field, colour swatches and animal picker',
      (tester) async {
    await _open(tester, (_) {});

    expect(find.byType(TextField), findsOneWidget);
    expect(find.text('בחרו צבע'), findsOneWidget);
    expect(find.text('בחרו חיה'), findsOneWidget);
    expect(find.text(ChildProfile.avatarChoices.first), findsWidgets);
  });

  testWidgets('does not submit until a name is entered', (tester) async {
    ChildProfileDraft? result;
    var popped = false;
    await _open(tester, (r) {
      popped = true;
      result = r;
    });

    await tester.tap(find.text('צור'));
    await tester.pumpAndSettle();
    expect(popped, isFalse); // still open, no name
    expect(find.byType(ChildProfileCreateDialog), findsOneWidget);

    await tester.enterText(find.byType(TextField), 'נועה');
    await tester.pump();
    await tester.tap(find.text('צור'));
    await tester.pumpAndSettle();

    expect(popped, isTrue);
    expect(result, isNotNull);
    expect(result!.displayName, 'נועה');
    expect(result!.avatarId, isNull); // no animal picked → coloured initial
    expect(result!.avatarColor, ChildProfile.defaultAvatarColors.first);
  });

  testWidgets('picking an animal returns it as the draft avatarId',
      (tester) async {
    ChildProfileDraft? result;
    await _open(tester, (r) => result = r);

    await tester.enterText(find.byType(TextField), 'איתי');
    await tester.pump();
    await tester.tap(_animalChip('🦁'));
    await tester.pump();
    await tester.tap(find.text('צור'));
    await tester.pumpAndSettle();

    expect(result, isNotNull);
    expect(result!.avatarId, '🦁');
    expect(result!.displayName, 'איתי');
  });

  testWidgets('re-tapping the chosen animal clears it back to null',
      (tester) async {
    ChildProfileDraft? result;
    await _open(tester, (r) => result = r);

    await tester.enterText(find.byType(TextField), 'מיה');
    await tester.pump();
    await tester.tap(_animalChip('🦊'));
    await tester.pump();
    await tester.tap(_animalChip('🦊')); // toggle off
    await tester.pump();
    await tester.tap(find.text('צור'));
    await tester.pumpAndSettle();

    expect(result, isNotNull);
    expect(result!.avatarId, isNull);
  });
}
