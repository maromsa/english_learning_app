import 'package:flutter/foundation.dart';

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

  static const String _defineGeminiProxyUrl = String.fromEnvironment(
    'GEMINI_PROXY_URL',
    defaultValue: '',
  );
  static const String _defineCloudinaryCloudName = String.fromEnvironment(
    'CLOUDINARY_CLOUD_NAME',
    defaultValue: '',
  );
  static const String _defineGoogleTtsApiKey = String.fromEnvironment(
    'GOOGLE_TTS_API_KEY',
    defaultValue: '',
  );
  static const String _defineAiImageValidationUrl = String.fromEnvironment(
    'AI_IMAGE_VALIDATION_URL',
    defaultValue: '',
  );
  static const String _defineAiBackendUrl = String.fromEnvironment(
    'AI_BACKEND_URL',
    defaultValue: '',
  );

  static final String geminiProxyUrl = _readSecret(
    'GEMINI_PROXY_URL',
    _defineGeminiProxyUrl,
  );
  static final String cloudinaryCloudName = _readSecret(
    'CLOUDINARY_CLOUD_NAME',
    _defineCloudinaryCloudName,
  );
  static final String googleTtsApiKey = _readSecret(
    'GOOGLE_TTS_API_KEY',
    _defineGoogleTtsApiKey,
  );
  static final String aiImageValidationUrl = _readSecret(
    'AI_IMAGE_VALIDATION_URL',
    _defineAiImageValidationUrl,
  );
  static final String aiBackendUrl = _readSecret(
    'AI_BACKEND_URL',
    _defineAiBackendUrl,
  );

  static bool get hasGeminiProxy =>
      true; // Always available via geminiProxyEndpoint

  /// TTS is served through the proxy (key stays server-side), so it is always
  /// available as long as the proxy is reachable. The dart-define key is only
  /// kept as a legacy direct-call fallback inside SparkVoiceService.
  static bool get hasGoogleTts => true;

  /// Fetching the public image list only requires the cloud name.
  /// API key/secret were removed from the client on purpose: secrets compiled
  /// into the app binary can be extracted. Signed operations (uploads) must go
  /// through a server-side endpoint instead.
  static bool get hasCloudinary => cloudinaryCloudName.isNotEmpty;
  static bool get hasAiImageValidation => aiImageValidationUrl.isNotEmpty;
  static bool get hasAiBackend => aiBackendUrl.isNotEmpty;

  /// Checks if Firebase is properly configured and accessible
  static bool get isFirebaseConfigured {
    try {
      final projectId = _firebaseProjectId;
      return projectId != null && projectId.isNotEmpty;
    } catch (_) {
      return false;
    }
  }

  static Uri? get aiImageValidationEndpoint =>
      hasAiImageValidation ? Uri.tryParse(aiImageValidationUrl) : null;

  static Uri? get aiBackendEndpoint =>
      hasAiBackend ? Uri.tryParse(aiBackendUrl) : null;

  static Uri get geminiProxyEndpoint {
    // If explicit URL is provided, use it
    if (geminiProxyUrl.isNotEmpty) {
      final uri = Uri.tryParse(geminiProxyUrl);
      if (uri != null && uri.hasScheme && uri.hasAuthority) {
        return uri;
      }
      // If invalid, fall through to construct from project ID
    }

    // Always construct from Firebase project ID
    String projectId;
    try {
      projectId = _firebaseProjectId ?? '';
    } catch (e) {
      debugPrint('Error getting Firebase project ID: $e');
      projectId = '';
    }

    // Fallback to hardcoded project ID if needed
    if (projectId.isEmpty) {
      projectId = 'englishkidsapp-916be';
      debugPrint('Using fallback project ID: $projectId');
    }

    // Always return a valid URI - this should never fail
    return Uri.parse(
      'https://us-central1-$projectId.cloudfunctions.net/geminiProxy',
    );
  }

  static Uri requireGeminiProxyEndpoint() {
    // Always returns a valid endpoint, so this is just an alias
    return geminiProxyEndpoint;
  }

  /// Provides a quick overview for debug logs/tests.
  static Map<String, bool> diagnostics() => {
        'geminiProxy': hasGeminiProxy,
        'cloudinary': hasCloudinary,
        'googleTts': hasGoogleTts,
        'aiImageValidation': hasAiImageValidation,
        'aiBackend': hasAiBackend,
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

  static String _readSecret(String key, String defineValue) {
    if (defineValue.isNotEmpty) {
      return defineValue;
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
