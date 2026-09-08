// test/widgets/word_speaker_button_test.dart
//
// Widget tests for WordSpeakerButton — the 🔊 button that pronounces an
// English word with a subtle pulse while the audio plays. A fake `speak`
// callback stands in for SparkVoiceService so no network / TTS is involved.

import 'dart:async';

import 'package:english_learning_app/l10n/spark_strings.dart';
import 'package:english_learning_app/services/audio_settings.dart';
import 'package:english_learning_app/widgets/word_speaker_button.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

Widget _host(Widget child) =>
    MaterialApp(home: Scaffold(body: Center(child: child)));

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() async {
    // AudioSettings.setMuted() persists via SharedPreferences — mock it so the
    // platform channel resolves instead of hanging.
    SharedPreferences.setMockInitialValues({});
    // WordSpeakerButton honours the global mute setting; keep it unmuted.
    await AudioSettings().setMuted(false);
  });

  testWidgets('renders an idle speaker icon with an accessible label',
      (tester) async {
    await tester.pumpWidget(
      _host(WordSpeakerButton(word: 'Apple', speak: (_) async => true)),
    );

    expect(find.byIcon(Icons.volume_up_rounded), findsOneWidget);
    expect(find.byIcon(Icons.graphic_eq_rounded), findsNothing);
    expect(
      find.bySemanticsLabel(SparkStrings.hearWordSemantics('Apple')),
      findsOneWidget,
    );
  });

  testWidgets('tapping calls speak() with the word', (tester) async {
    String? spoken;
    await tester.pumpWidget(
      _host(WordSpeakerButton(
        word: 'Banana',
        speak: (w) async {
          spoken = w;
          return true;
        },
      )),
    );

    await tester.tap(find.byType(WordSpeakerButton));
    await tester.pump(); // start
    await tester
        .pump(const Duration(milliseconds: 50)); // let the future settle

    expect(spoken, 'Banana');
  });

  testWidgets('shows the playing icon while audio is in flight, then resets',
      (tester) async {
    final completer = Completer<bool>();
    await tester.pumpWidget(
      _host(WordSpeakerButton(word: 'Orange', speak: (_) => completer.future)),
    );

    await tester.tap(find.byType(WordSpeakerButton));
    await tester.pump(); // enter playing state

    expect(find.byIcon(Icons.graphic_eq_rounded), findsOneWidget);
    expect(find.byIcon(Icons.volume_up_rounded), findsNothing);

    completer.complete(true);
    await tester.pump(); // finally block
    await tester.pump(const Duration(milliseconds: 50));

    expect(find.byIcon(Icons.volume_up_rounded), findsOneWidget);
    expect(find.byIcon(Icons.graphic_eq_rounded), findsNothing);
  });

  testWidgets('a second tap while still playing is ignored', (tester) async {
    var calls = 0;
    final completer = Completer<bool>();
    await tester.pumpWidget(
      _host(WordSpeakerButton(
        word: 'Grape',
        speak: (_) {
          calls++;
          return completer.future;
        },
      )),
    );

    await tester.tap(find.byType(WordSpeakerButton));
    await tester.pump();
    await tester.tap(find.byType(WordSpeakerButton));
    await tester.pump();

    expect(calls, 1);

    completer.complete(true);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));
  });

  testWidgets('does nothing for an empty word', (tester) async {
    var called = false;
    await tester.pumpWidget(
      _host(WordSpeakerButton(
        word: '   ',
        speak: (_) async {
          called = true;
          return true;
        },
      )),
    );

    await tester.tap(find.byType(WordSpeakerButton));
    await tester.pump();

    expect(called, isFalse);
  });

  testWidgets('is a no-op while audio is muted', (tester) async {
    await AudioSettings().setMuted(true);
    addTearDown(() => AudioSettings().setMuted(false));

    var called = false;
    await tester.pumpWidget(
      _host(WordSpeakerButton(
        word: 'Lemon',
        speak: (_) async {
          called = true;
          return true;
        },
      )),
    );

    await tester.tap(find.byType(WordSpeakerButton));
    await tester.pump();

    expect(called, isFalse);
    expect(find.byIcon(Icons.volume_up_rounded), findsOneWidget);
  });

  testWidgets('recovers to idle when speak() throws', (tester) async {
    await tester.pumpWidget(
      _host(WordSpeakerButton(
        word: 'Cherry',
        speak: (_) async => throw Exception('tts down'),
      )),
    );

    await tester.tap(find.byType(WordSpeakerButton));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));

    expect(find.byIcon(Icons.volume_up_rounded), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
