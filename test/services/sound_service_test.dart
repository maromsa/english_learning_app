import 'package:english_learning_app/services/sound_service.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
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
    final service = SoundService();

    test('micro and pop feedback never fall back to startup chime', () {
      expect(service.fallbackSoundAsset(SoundService.softChime), isNull);
      expect(service.fallbackSoundAsset(SoundService.pop), isNull);
      expect(service.fallbackSoundAsset('success'), isNull);
    });

    test('big celebrations fall back to ui click when music fails', () {
      expect(
        service.fallbackSoundAsset(SoundService.fanfare),
        SoundService.uiClickAsset,
      );
      expect(
        service.fallbackSoundAsset(SoundService.epic),
        SoundService.uiClickAsset,
      );
    });
  });
}
