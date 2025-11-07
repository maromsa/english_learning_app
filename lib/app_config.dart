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
  static const String _enableGeminiStubFlag =
      String.fromEnvironment('ENABLE_GEMINI_STUB', defaultValue: 'false');
  static const String geminiProxyUrl =
      String.fromEnvironment('GEMINI_PROXY_URL', defaultValue: '');
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
  static const String aiImageValidationUrl =
      String.fromEnvironment('AI_IMAGE_VALIDATION_URL', defaultValue: '');

  static bool get hasGemini => geminiApiKey.isNotEmpty;
  static bool get hasGeminiProxy => geminiProxyUrl.isNotEmpty;
  static bool get hasGeminiStub => _parseBool(_enableGeminiStubFlag);
  static bool get hasPixabay => pixabayApiKey.isNotEmpty;
  static bool get hasCloudinary =>
      cloudinaryCloudName.isNotEmpty &&
      cloudinaryApiKey.isNotEmpty &&
      cloudinaryApiSecret.isNotEmpty;
  static bool get hasGoogleTts => googleTtsApiKey.isNotEmpty;
  static bool get hasFirebaseUserId => firebaseUserIdForUpload.isNotEmpty;
  static bool get hasAiImageValidation => aiImageValidationUrl.isNotEmpty;

  static String? get cloudinaryUrl => hasCloudinary
      ? 'cloudinary://$cloudinaryApiKey:$cloudinaryApiSecret@$cloudinaryCloudName'
      : null;

  static Uri? get aiImageValidationEndpoint =>
      hasAiImageValidation ? Uri.tryParse(aiImageValidationUrl) : null;

  static Uri? get geminiProxyEndpoint =>
      hasGeminiProxy ? Uri.tryParse(geminiProxyUrl) : null;

    /// Provides a quick overview for debug logs/tests.
    static Map<String, bool> diagnostics() => {
          'gemini': hasGemini,
          'geminiProxy': hasGeminiProxy,
          'geminiStub': hasGeminiStub,
          'pixabay': hasPixabay,
          'cloudinary': hasCloudinary,
          'googleTts': hasGoogleTts,
          'firebaseUserId': hasFirebaseUserId,
          'aiImageValidation': hasAiImageValidation,
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

  static bool _parseBool(String value) {
    final normalized = value.trim().toLowerCase();
    return normalized == 'true' || normalized == '1' || normalized == 'yes';
  }
}
