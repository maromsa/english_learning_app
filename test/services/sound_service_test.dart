import 'package:english_learning_app/services/sound_service.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('SoundService.normalizeAssetPath', () {
    test('leaves a single assets/ prefix unchanged', () {
      expect(
        SoundService.normalizeAssetPath('assets/audio/startup_chime.wav'),
        'assets/audio/startup_chime.wav',
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
          'assets/assets/assets/sfx/pop.mp3',
        ),
        'assets/sfx/pop.mp3',
      );
    });
  });
}
