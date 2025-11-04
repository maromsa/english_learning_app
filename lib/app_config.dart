import 'package:flutter/foundation.dart';

/// Central place to access runtime configuration and API keys.
///
/// Values are read from `--dart-define` entries so that secrets do not live in
/// the codebase. Example usage when running the app:
///
/// ```bash
/// flutter run \
///   --dart-define=GEMINI_API_KEY=xxx \
///   --dart-define=CLOUDINARY_CLOUD_NAME=yyy
/// ```
class AppConfig {
  const AppConfig._();

  static const String geminiApiKey =
      String.fromEnvironment('GEMINI_API_KEY', defaultValue: '');
  static const String pixabayApiKey =
      String.fromEnvironment('PIXABAY_API_KEY', defaultValue: '');
  static const String firebaseUserIdForUpload = String.fromEnvironment(
    'FIREBASE_USER_ID_FOR_UPLOAD',
    defaultValue: '',
  );
  static const String cloudinaryCloudName = String.fromEnvironment(
    'CLOUDINARY_CLOUD_NAME',
    defaultValue: '',
  );
  static const String cloudinaryApiKey =
      String.fromEnvironment('CLOUDINARY_API_KEY', defaultValue: '');
  static const String cloudinaryApiSecret =
      String.fromEnvironment('CLOUDINARY_API_SECRET', defaultValue: '');
  static const String googleTtsApiKey =
      String.fromEnvironment('GOOGLE_TTS_API_KEY', defaultValue: '');

  static bool get hasGemini => geminiApiKey.isNotEmpty;
  static bool get hasPixabay => pixabayApiKey.isNotEmpty;
  static bool get hasCloudinary =>
      cloudinaryCloudName.isNotEmpty &&
      cloudinaryApiKey.isNotEmpty &&
      cloudinaryApiSecret.isNotEmpty;
  static bool get hasGoogleTts => googleTtsApiKey.isNotEmpty;
  static bool get hasFirebaseUserId => firebaseUserIdForUpload.isNotEmpty;

  static String? get cloudinaryUrl => hasCloudinary
      ? 'cloudinary://$cloudinaryApiKey:$cloudinaryApiSecret@$cloudinaryCloudName'
      : null;

  /// Provides a quick overview for debug logs/tests.
  static Map<String, bool> diagnostics() => {
        'gemini': hasGemini,
        'pixabay': hasPixabay,
        'cloudinary': hasCloudinary,
        'googleTts': hasGoogleTts,
        'firebaseUserId': hasFirebaseUserId,
      };

  /// Logs helpful hints when a required secret is missing.
  static void debugWarnIfMissing(String feature, bool isAvailable) {
    assert(() {
      if (!isAvailable) {
        debugPrint(
          '[AppConfig] "$feature" disabled – provide the relevant --dart-define to enable it.',
        );
      }
      return true;
    }());
  }
}
