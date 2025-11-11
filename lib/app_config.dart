import 'package:flutter/foundation.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

import 'firebase_options.dart';
import 'utils/platform_env_stub.dart'
    if (dart.library.io) 'utils/platform_env_io.dart';

/// Central place to access runtime configuration and API keys.
///
/// Values are read from `--dart-define` entries so that secrets do not live in
/// the codebase. Example usage when running the app:
///
/// ```bash
/// flutter run \
///   --dart-define=GEMINI_PROXY_URL=https://<region>-<project>.cloudfunctions.net/geminiProxy \
///   --dart-define=CLOUDINARY_CLOUD_NAME=yyy
/// ```
class AppConfig {
  const AppConfig._();

  static final String geminiProxyUrl = _readSecret('GEMINI_PROXY_URL');
  static final String pixabayApiKey = _readSecret('PIXABAY_API_KEY');
  static final String firebaseUserIdForUpload = _readSecret(
    'FIREBASE_USER_ID_FOR_UPLOAD',
  );
  static final String cloudinaryCloudName = _readSecret(
    'CLOUDINARY_CLOUD_NAME',
  );
  static final String cloudinaryApiKey = _readSecret('CLOUDINARY_API_KEY');
  static final String cloudinaryApiSecret = _readSecret(
    'CLOUDINARY_API_SECRET',
  );
  static final String googleTtsApiKey = _readSecret('GOOGLE_TTS_API_KEY');
  static final String aiImageValidationUrl = _readSecret(
    'AI_IMAGE_VALIDATION_URL',
  );

  static bool get hasGeminiProxy => geminiProxyUrl.isNotEmpty;
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

  static Uri? get geminiProxyEndpoint {
    if (geminiProxyUrl.isNotEmpty) {
      return Uri.tryParse(geminiProxyUrl);
    }
    final projectId = _firebaseProjectId;
    if (projectId == null || projectId.isEmpty) {
      return null;
    }
    return Uri.tryParse(
      'https://us-central1-$projectId.cloudfunctions.net/geminiProxy',
    );
  }

  static Uri requireGeminiProxyEndpoint() {
    final endpoint = geminiProxyEndpoint;
    if (endpoint == null) {
      throw StateError(
        'Gemini proxy endpoint is not configured. Ensure your Firebase project ID is available or set GEMINI_PROXY_URL explicitly.',
      );
    }
    return endpoint;
  }

  /// Provides a quick overview for debug logs/tests.
  static Map<String, bool> diagnostics() => {
    'geminiProxy': hasGeminiProxy,
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

  static String _readSecret(String key) {
    final fromDefines = String.fromEnvironment(key, defaultValue: '');
    if (fromDefines.isNotEmpty) {
      return fromDefines;
    }

    if (dotenv.isInitialized) {
      try {
        final fromDotEnv = dotenv.maybeGet(key);
        if (fromDotEnv != null && fromDotEnv.isNotEmpty) {
          return fromDotEnv;
        }
      } catch (_) {
        // Ignore dotenv errors when not configured.
      }
    }

    final fromPlatform = readPlatformEnvironment(key);
    if (fromPlatform.isNotEmpty) {
      return fromPlatform;
    }

    return '';
  }

  static String? get _firebaseProjectId {
    try {
      return DefaultFirebaseOptions.currentPlatform.projectId;
    } catch (_) {
      return null;
    }
  }
}
