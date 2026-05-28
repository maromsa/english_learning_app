import 'dart:convert';

import 'package:crypto/crypto.dart';

/// In-memory LRU cache for deterministic Gemini proxy text responses.
class GeminiProxyResponseCache {
  GeminiProxyResponseCache({
    this.maxEntries = 64,
    this.ttl = const Duration(hours: 12),
  });

  final int maxEntries;
  final Duration ttl;

  final Map<String, _CacheEntry> _entries = <String, _CacheEntry>{};
  final List<String> _lruKeys = <String>[];

  /// Returns a stable cache key for [payload], or `null` when not cacheable.
  static String? cacheKeyForPayload(Map<String, dynamic> payload) {
    if (!_isCacheablePayload(payload)) {
      return null;
    }
    final canonical = _canonicalJson(payload);
    final digest = sha256.convert(utf8.encode(canonical));
    return digest.toString();
  }

  Map<String, dynamic>? get(String key) {
    final entry = _entries[key];
    if (entry == null) {
      return null;
    }
    if (DateTime.now().difference(entry.storedAt) > ttl) {
      _removeKey(key);
      return null;
    }
    _touch(key);
    return Map<String, dynamic>.from(entry.response);
  }

  void put(String key, Map<String, dynamic> response) {
    if (_entries.containsKey(key)) {
      _entries[key] = _CacheEntry(
        response: Map<String, dynamic>.from(response),
        storedAt: DateTime.now(),
      );
      _touch(key);
      return;
    }

    while (_entries.length >= maxEntries && _lruKeys.isNotEmpty) {
      _removeKey(_lruKeys.first);
    }

    _entries[key] = _CacheEntry(
      response: Map<String, dynamic>.from(response),
      storedAt: DateTime.now(),
    );
    _lruKeys.add(key);
  }

  void clear() {
    _entries.clear();
    _lruKeys.clear();
  }

  static bool _isCacheablePayload(Map<String, dynamic> payload) {
    if (payload.containsKey('imageBase64')) {
      return false;
    }
    final mode = payload['mode'];
    if (mode == null) {
      // validateImageMatch — not cacheable (unique images).
      return payload.containsKey('word') && !payload.containsKey('prompt');
    }
    return mode == 'text' || mode == 'story';
  }

  static String _canonicalJson(Map<String, dynamic> map) {
    final sorted = _sortMap(map);
    return jsonEncode(sorted);
  }

  static Map<String, dynamic> _sortMap(Map<String, dynamic> map) {
    final keys = map.keys.toList()..sort();
    final result = <String, dynamic>{};
    for (final key in keys) {
      final value = map[key];
      if (value is Map<String, dynamic>) {
        result[key] = _sortMap(value);
      } else if (value is List) {
        result[key] = value;
      } else {
        result[key] = value;
      }
    }
    return result;
  }

  void _touch(String key) {
    _lruKeys.remove(key);
    _lruKeys.add(key);
  }

  void _removeKey(String key) {
    _entries.remove(key);
    _lruKeys.remove(key);
  }
}

class _CacheEntry {
  _CacheEntry({required this.response, required this.storedAt});

  final Map<String, dynamic> response;
  final DateTime storedAt;
}
