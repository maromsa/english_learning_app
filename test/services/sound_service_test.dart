import 'package:english_learning_app/services/audio_settings.dart';
import 'package:english_learning_app/services/sound_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  late SoundService sound;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    sound = SoundService();
    sound.resetDebugState();
    sound.debugSkipPlayback = true;
    await sound.setMuted(false);
  });

  tearDown(() async {
    sound.resetDebugState();
    await sound.setMuted(false);
  });

  group('SoundService.normalizeAssetPath', () {
    test('leaves a single assets/ prefix unchanged', () {
      expect(
        SoundService.normalizeAssetPath('assets/audio/ui_click.wav'),
        'assets/audio/ui_click.wav',
      );
    });

    test('collapses doubled assets/assets/ prefix', () {
      expect(
        SoundService.normalizeAssetPath('assets/assets/audio/bubble_pop.mp3'),
        'assets/audio/bubble_pop.mp3',
      );
    });

    test('collapses multiple accidental doublings', () {
      expect(
        SoundService.normalizeAssetPath(
          'assets/assets/assets/audio/ui_click.wav',
        ),
        'assets/audio/ui_click.wav',
      );
    });
  });

  group('SoundService.fallbackSoundAsset', () {
    test('micro and pop feedback never fall back to startup chime', () {
      expect(sound.fallbackSoundAsset(SoundService.softChime), isNull);
      expect(sound.fallbackSoundAsset(SoundService.pop), isNull);
      expect(sound.fallbackSoundAsset('success'), isNull);
      expect(sound.fallbackSoundAsset('coin'), isNull);
      expect(sound.fallbackSoundAsset('error'), isNull);
    });

    test('big celebrations fall back to ui click when music fails', () {
      expect(
        sound.fallbackSoundAsset(SoundService.fanfare),
        SoundService.uiClickAsset,
      );
      expect(
        sound.fallbackSoundAsset(SoundService.epic),
        SoundService.uiClickAsset,
      );
    });
  });

  group('SoundService mute and SFX methods', () {
    test('isMuted follows AudioSettings', () async {
      expect(sound.isMuted, isFalse);
      await sound.setMuted(true);
      expect(sound.isMuted, isTrue);
      expect(AudioSettings().muted, isTrue);
      await sound.setMuted(false);
      expect(sound.isMuted, isFalse);
    });

    test('playSuccessSound / playCoinSound / playErrorSound record types',
        () async {
      var success = 0;
      var coin = 0;
      var error = 0;
      sound.debugOnPlaySuccess = () => success++;
      sound.debugOnPlayCoin = () => coin++;
      sound.debugOnPlayError = () => error++;

      sound.playSuccessSound();
      sound.playCoinSound();
      sound.playErrorSound();
      await Future<void>.delayed(Duration.zero);

      expect(success, 1);
      expect(coin, 1);
      expect(error, 1);
      expect(sound.playedTypes, ['success', 'coin', 'error']);
    });

    test('muted SFX never reach the playback log', () async {
      await sound.setMuted(true);

      sound.playSuccessSound();
      sound.playCoinSound();
      sound.playErrorSound();
      await Future<void>.delayed(Duration.zero);

      expect(sound.playedTypes, isEmpty);
    });

    test('unknown types do not throw when playback is skipped', () async {
      await sound.playSound('not-a-real-sfx');
      expect(sound.playedTypes, ['not-a-real-sfx']);
    });
  });
}
