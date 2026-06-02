/// Google Cloud TTS voice names for Spark's warm, encouraging persona.
///
/// Hebrew uses Wavenet (SSML-capable). English SSML paths use Neural2 because
/// Journey voices do not support SSML; plain-text synthesis may try Journey first.
class TtsVoiceConfig {
  TtsVoiceConfig._();

  static const String englishLanguageCode = 'en-US';
  static const String hebrewLanguageCode = 'he-IL';

  /// Warm female Journey voice for plain-text Google TTS (no SSML).
  static const String englishPlainTextPrimary = 'en-US-Journey-F';

  /// SSML-capable English voice used by [SparkVoiceService].
  static const String englishSsmlPrimary = 'en-US-Neural2-F';

  /// Natural female Hebrew Wavenet voice (SSML-capable).
  static const String hebrewPrimary = 'he-IL-Wavenet-A';

  static const String hebrewSecondary = 'he-IL-Wavenet-C';

  /// Ordered fallbacks when a voice is unavailable in the caller's region/key.
  static const List<String> hebrewVoicePreference = [
    hebrewPrimary,
    hebrewSecondary,
    'he-IL-Wavenet-B',
  ];

  static const List<String> englishPlainTextPreference = [
    englishPlainTextPrimary,
    englishSsmlPrimary,
    'en-US-Wavenet-F',
  ];

  static String languageCodeFor({required bool isEnglish}) =>
      isEnglish ? englishLanguageCode : hebrewLanguageCode;

  static String ssmlVoiceFor({required bool isEnglish}) =>
      isEnglish ? englishSsmlPrimary : hebrewPrimary;
}
