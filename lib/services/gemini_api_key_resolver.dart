import 'dart:async';

import 'package:english_learning_app/app_config.dart';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

/// Resolves the Gemini API key by preferring a local dart-define and falling back
/// to a GitHub-hosted secret when necessary.
class GeminiApiKeyResolver {
  GeminiApiKeyResolver._();

  static String? _cachedKey;
  static Future<String>? _pending;

  /// Returns the Gemini API key, fetching it from GitHub if required.
  static Future<String> resolve({Duration timeout = const Duration(seconds: 10)}) async {
    final cached = _cachedKey;
    if (cached != null) {
      return cached;
    }

    final directKey = AppConfig.geminiApiKey.trim();
    if (directKey.isNotEmpty) {
      _cachedKey = directKey;
      return directKey;
    }

    final secretUrl = AppConfig.githubGeminiSecretUrl.trim();
    if (secretUrl.isEmpty) {
      _cachedKey = '';
      return '';
    }

    final pending = _pending;
    if (pending != null) {
      return pending;
    }

    final future = _fetchFromGitHub(secretUrl, timeout: timeout);
    _pending = future;

    try {
      final key = await future;
      _cachedKey = key;
      return key;
    } finally {
      _pending = null;
    }
  }

  static Future<String> _fetchFromGitHub(String rawUrl, {required Duration timeout}) async {
    try {
      final uri = Uri.parse(rawUrl);
      final headers = <String, String>{'Accept': 'application/vnd.github.v3.raw'};
      final token = AppConfig.githubAccessToken.trim();
      if (token.isNotEmpty) {
        headers['Authorization'] = 'Bearer $token';
      }

      final response = await http.get(uri, headers: headers).timeout(timeout);

      if (response.statusCode == 200) {
        final key = response.body.trim();
        if (key.isEmpty) {
          debugPrint('[GeminiApiKeyResolver] GitHub response was empty.');
        }
        return key;
      }

      debugPrint(
        '[GeminiApiKeyResolver] GitHub fetch failed: ${response.statusCode} ${response.reasonPhrase}',
      );
    } on TimeoutException {
      debugPrint('[GeminiApiKeyResolver] GitHub request timed out.');
    } catch (error, stackTrace) {
      debugPrint('[GeminiApiKeyResolver] GitHub fetch error: $error');
      debugPrint(stackTrace.toString());
    }

    return '';
  }

  @visibleForTesting
  static void resetCache() {
    _cachedKey = null;
    _pending = null;
  }
}
