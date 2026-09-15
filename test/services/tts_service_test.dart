import 'package:english_learning_app/services/audio_settings.dart';
import 'package:english_learning_app/services/tts_service.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const channel = MethodChannel('flutter_tts');
  final messenger =
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
  final calls = <MethodCall>[];

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    await AudioSettings().setMuted(false);
    calls.clear();
    messenger.setMockMethodCallHandler(channel, (call) async {
      calls.add(call);
      return 1;
    });
  });

  tearDown(() {
    messenger.setMockMethodCallHandler(channel, null);
  });

  test('speak configures en-US at a slow kid rate then speaks the text',
      () async {
    final tts = TtsService();

    await tts.speak('The cat is sleeping');

    expect(calls.map((c) => c.method),
        ['setLanguage', 'setSpeechRate', 'stop', 'speak']);
    expect(calls[0].arguments, TtsService.language);
    expect(calls[1].arguments, TtsService.speechRate);
    expect(calls[3].arguments, 'The cat is sleeping');
  });

  test('speak is a no-op for blank text', () async {
    final tts = TtsService();

    await tts.speak('   ');

    expect(calls, isEmpty);
  });

  test('speak is a no-op while audio is muted', () async {
    await AudioSettings().setMuted(true);
    addTearDown(() => AudioSettings().setMuted(false));
    final tts = TtsService();

    await tts.speak('Hello there');

    expect(calls, isEmpty);
  });

  test('stop invokes the plugin stop method', () async {
    final tts = TtsService();

    await tts.stop();

    expect(calls.map((c) => c.method), ['stop']);
  });

  test('a plugin error is swallowed so children never see a crash', () async {
    messenger.setMockMethodCallHandler(channel, (call) async {
      throw PlatformException(code: 'error', message: 'engine missing');
    });
    final tts = TtsService();

    await tts.speak('I drink water');
    await tts.stop();
  });
}
