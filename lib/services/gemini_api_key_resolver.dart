import 'package:flutter/foundation.dart';

import '../app_config.dart';
import 'src/gemini_env_reader_stub.dart'
    if (dart.library.io) 'src/gemini_env_reader_io.dart' as env_reader;

/// Provides a consistent way to access the Gemini API key across platforms.
class GeminiApiKeyResolver {
  const GeminiApiKeyResolver._();

  static String? _cached;
  static bool _warnedMissing = false;

  /// Resolves the Gemini API key, returning `null` when it is unavailable.
  ///
  /// The resolver first checks compile-time configuration (`--dart-define`)
  /// via [AppConfig], and then falls back to environment variables when
  /// running in environments such as `dart test` where `--dart-define` values
  /// are not supplied. The key is cached for the lifetime of the process.
  static Future<String?> resolve({bool warnIfMissing = true}) async {
    final key = peek();
    if (key == null && warnIfMissing) {
      _warnOnce();
    }
    return key;
  }

  /// Returns the cached key if available, without triggering warnings.
  static String? peek() {
    _cached ??= _loadKey();
    if (_cached != null && _cached!.trim().isEmpty) {
      _cached = null;
    }
    return _cached;
  }

  /// Clears the memoized key. Primarily useful for tests.
  static void clearCache() {
    _cached = null;
    _warnedMissing = false;
  }

  static String? _loadKey() {
    final fromDefines = AppConfig.geminiApiKey.trim();
    if (fromDefines.isNotEmpty) {
      return fromDefines;
    }

    final fromEnv = env_reader.readGeminiApiKey();
    if (fromEnv != null && fromEnv.trim().isNotEmpty) {
      return fromEnv.trim();
    }

    return null;
  }

  static void _warnOnce() {
    if (_warnedMissing) {
      return;
    }
    _warnedMissing = true;
    assert(() {
      AppConfig.debugWarnIfMissing('GEMINI_API_KEY', false);
      debugPrint(
        '[GeminiApiKeyResolver] Missing Gemini API key. '
        'Provide --dart-define=GEMINI_API_KEY=your_key or set the GEMINI_API_KEY env var.',
      );
      return true;
    }());
  }
}
