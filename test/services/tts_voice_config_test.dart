import 'package:english_learning_app/services/tts_voice_config.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('TtsVoiceConfig', () {
    test('Hebrew SSML voice uses premium Wavenet', () {
      expect(
        TtsVoiceConfig.ssmlVoiceFor(isEnglish: false),
        'he-IL-Wavenet-A',
      );
    });

    test('English SSML voice uses Neural2 for SSML compatibility', () {
      expect(
        TtsVoiceConfig.ssmlVoiceFor(isEnglish: true),
        'en-US-Neural2-F',
      );
    });

    test('languageCodeFor maps English and Hebrew correctly', () {
      expect(
        TtsVoiceConfig.languageCodeFor(isEnglish: true),
        'en-US',
      );
      expect(
        TtsVoiceConfig.languageCodeFor(isEnglish: false),
        'he-IL',
      );
    });

    test('hebrewVoicePreference prioritizes Wavenet voices', () {
      expect(
        TtsVoiceConfig.hebrewVoicePreference.first,
        TtsVoiceConfig.hebrewPrimary,
      );
      expect(
        TtsVoiceConfig.hebrewVoicePreference,
        contains('he-IL-Wavenet-C'),
      );
      expect(
        TtsVoiceConfig.hebrewVoicePreference,
        isNot(contains('he-IL-Standard-B')),
      );
    });

    test('englishPlainTextPreference leads with Journey voice', () {
      expect(
        TtsVoiceConfig.englishPlainTextPreference.first,
        'en-US-Journey-F',
      );
    });
  });
}
