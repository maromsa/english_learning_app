import 'dart:async';
import 'dart:convert';

import 'package:english_learning_app/app_config.dart';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

/// Resolves the Gemini API key by preferring a local dart-define and falling back
/// to a GitHub-hosted secret when necessary.
class GeminiApiKeyResolver {
  GeminiApiKeyResolver._();

  static String? _cachedKey;
  static DateTime? _cachedExpiry;
  static Future<String>? _pending;

  /// Returns the Gemini API key, fetching it from GitHub if required.
  static Future<String> resolve({Duration timeout = const Duration(seconds: 10)}) async {
    final cached = _cachedKey;
    if (cached != null && !_isCacheExpired()) {
      return cached;
    }

    _clearCacheIfExpired();

    final directKey = AppConfig.geminiApiKey.trim();
    if (directKey.isNotEmpty) {
      _cacheKey(directKey, null);
      return directKey;
    }

    final pending = _pending;
    if (pending != null) {
      return pending;
    }

    final future = _resolveFromRemoteSources(timeout);
    _pending = future;

    try {
      final key = await future;
      return key;
    } finally {
      _pending = null;
    }
  }

  static Future<String> _resolveFromRemoteSources(Duration timeout) async {
    final endpoint = AppConfig.geminiTokenEndpoint.trim();
    if (endpoint.isNotEmpty) {
      final result = await _fetchFromSecureEndpoint(endpoint, timeout: timeout);
      if (result.$1.isNotEmpty) {
        _cacheKey(result.$1, result.$2);
        return result.$1;
      }
    }

    final secretUrl = AppConfig.githubGeminiSecretUrl.trim();
    if (secretUrl.isNotEmpty) {
      final key = await _fetchFromGitHub(secretUrl, timeout: timeout);
      _cacheKey(key, null);
      return key;
    }

    return '';
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

  static Future<(String, DateTime?)> _fetchFromSecureEndpoint(
    String rawUrl, {
    required Duration timeout,
  }) async {
    try {
      final uri = Uri.parse(rawUrl);
      final headers = <String, String>{'Accept': 'application/json'};
      final serviceKey = AppConfig.geminiServiceKey.trim();
      if (serviceKey.isNotEmpty) {
        headers['x-service-key'] = serviceKey;
      }

      final response = await http.get(uri, headers: headers).timeout(timeout);

      if (response.statusCode == 200) {
        final decoded = jsonDecode(response.body);
        if (decoded is Map<String, dynamic>) {
          final token = (decoded['token'] ?? decoded['key'] ?? decoded['apiKey'])?.toString().trim() ?? '';
          DateTime? expiry;

          final expiresAt = decoded['expiresAt'];
          if (expiresAt is num) {
            expiry =
                DateTime.fromMillisecondsSinceEpoch((expiresAt * 1000).toInt(), isUtc: true).toLocal();
          } else if (expiresAt is String) {
            final parsed = DateTime.tryParse(expiresAt);
            if (parsed != null) {
              expiry = parsed;
            }
          }

          return (token, expiry);
        }
      } else {
        debugPrint(
          '[GeminiApiKeyResolver] Secure endpoint fetch failed: ${response.statusCode} ${response.reasonPhrase}',
        );
      }
    } on TimeoutException {
      debugPrint('[GeminiApiKeyResolver] Secure endpoint request timed out.');
    } catch (error, stackTrace) {
      debugPrint('[GeminiApiKeyResolver] Secure endpoint error: $error');
      debugPrint(stackTrace.toString());
    }

    return ('', null);
  }

  static bool _isCacheExpired() {
    final expiry = _cachedExpiry;
    if (expiry == null) {
      return false;
    }
    return DateTime.now().isAfter(expiry);
  }

  static void _clearCacheIfExpired() {
    if (_isCacheExpired()) {
      _cachedKey = null;
      _cachedExpiry = null;
    }
  }

  static void _cacheKey(String key, DateTime? expiry) {
    if (key.isEmpty) {
      _cachedKey = null;
      _cachedExpiry = null;
      return;
    }

    _cachedKey = key;
    _cachedExpiry = expiry;
  }

  @visibleForTesting
  static void resetCache() {
    _cachedKey = null;
    _cachedExpiry = null;
    _pending = null;
  }
}
