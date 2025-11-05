import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/word_data.dart';
import 'cloudinary_service.dart';
import 'web_image_service.dart';

class WordRepository {
  WordRepository({
    SharedPreferences? prefs,
    CloudinaryService? cloudinaryService,
    WebImageProvider? webImageProvider,
    Duration cacheDuration = const Duration(hours: 12),
  })  : _prefsFuture =
                prefs != null ? Future.value(prefs) : SharedPreferences.getInstance(),
            _cloudinaryService = cloudinaryService ?? CloudinaryService(),
            _webImageProvider = webImageProvider,
            _cacheDuration = cacheDuration;

  static const String cacheKey = 'word_repository.cache.words.v2';
  static const String cacheTimestampKey = 'word_repository.cache.timestamp.v2';
  static const String _defaultNamespace = 'default';
  static const String _namespacedKeyPrefix = 'word_repository.cache';

  final Future<SharedPreferences> _prefsFuture;
  final CloudinaryService _cloudinaryService;
  final WebImageProvider? _webImageProvider;
  final Duration _cacheDuration;

  Future<List<WordData>> loadWords({
    required bool remoteEnabled,
    required List<WordData> fallbackWords,
    String cloudName = '',
    String tagName = '',
    int maxResults = 50,
    String cacheNamespace = _defaultNamespace,
  }) async {
    final prefs = await _prefsFuture;
    final namespacedCacheKey = _cacheKey(cacheNamespace);
    final namespacedTimestampKey = _cacheTimestampKey(cacheNamespace);
    final cachedJson = prefs.getString(namespacedCacheKey);
    final cachedTimestamp = prefs.getInt(namespacedTimestampKey);
    final now = DateTime.now();

    List<WordData>? cachedWords;
    if (cachedJson != null) {
      cachedWords = _decodeWords(cachedJson);
      if (cachedWords != null &&
          cachedTimestamp != null &&
          now.difference(DateTime.fromMillisecondsSinceEpoch(cachedTimestamp)) <
              _cacheDuration) {
        return cachedWords;
      }
    }

    if (remoteEnabled && cloudName.isNotEmpty && tagName.isNotEmpty) {
      final remoteWords = await _cloudinaryService.fetchWords(
        cloudName: cloudName,
        tagName: tagName,
        maxResults: maxResults,
      );

      if (remoteWords.isNotEmpty) {
        await _saveCache(prefs, remoteWords, cacheNamespace);
        return remoteWords;
      }
    }

    if (cachedWords != null) {
      return cachedWords;
    }

    final enrichedFallback = await _maybeAddWebImages(fallbackWords);

    if (enrichedFallback.isNotEmpty) {
      await _saveCache(prefs, enrichedFallback, cacheNamespace);
    }

    return enrichedFallback;
  }

  Future<void> cacheWords(
    List<WordData> words, {
    String cacheNamespace = _defaultNamespace,
  }) async {
    final prefs = await _prefsFuture;
    await _saveCache(prefs, words, cacheNamespace);
  }

  Future<void> clearCache({String? cacheNamespace}) async {
    final prefs = await _prefsFuture;
    if (cacheNamespace != null) {
      await prefs.remove(_cacheKey(cacheNamespace));
      await prefs.remove(_cacheTimestampKey(cacheNamespace));
      return;
    }

    final keysToRemove = prefs.getKeys().where((key) {
      return key == cacheKey ||
          key == cacheTimestampKey ||
          key.startsWith('$_namespacedKeyPrefix.words.') ||
          key.startsWith('$_namespacedKeyPrefix.timestamp.');
    }).toList();

    for (final key in keysToRemove) {
      await prefs.remove(key);
    }
  }

  List<WordData>? _decodeWords(String jsonStr) {
    try {
      final decoded = jsonDecode(jsonStr) as List<dynamic>;
      return decoded
          .whereType<Map<String, dynamic>>()
          .map(WordData.fromJson)
          .toList();
    } catch (e) {
      debugPrint('Failed to decode cached words: $e');
      return null;
    }
  }

  Future<void> _saveCache(
    SharedPreferences prefs,
    List<WordData> words,
    String cacheNamespace,
  ) async {
    final jsonStr = jsonEncode(words.map((w) => w.toJson()).toList());
    await prefs.setString(_cacheKey(cacheNamespace), jsonStr);
    await prefs.setInt(
      _cacheTimestampKey(cacheNamespace),
      DateTime.now().millisecondsSinceEpoch,
    );
  }

  Future<List<WordData>> _maybeAddWebImages(List<WordData> words) async {
    final provider = _webImageProvider;
    if (provider == null || words.isEmpty) {
      return List<WordData>.from(words);
    }

    final List<WordData> results = [];

    for (final word in words) {
      if (_shouldSkipWebLookup(word)) {
        results.add(word);
        continue;
      }

      try {
        final result = await provider.fetchImageForWord(
          word.word,
          searchHint: word.searchHint,
        );

        if (result == null) {
          results.add(word);
          continue;
        }

        results.add(
          WordData(
            word: result.inferredWord.isNotEmpty ? result.inferredWord : word.word,
            searchHint: word.searchHint ?? word.word,
            publicId: word.publicId,
            imageUrl: result.imageUrl,
            isCompleted: word.isCompleted,
            stickerUnlocked: word.stickerUnlocked,
          ),
        );
      } catch (_) {
        results.add(word);
      }
    }

    return results;
  }

  bool _shouldSkipWebLookup(WordData word) {
    final imageUrl = word.imageUrl;

    if (imageUrl == null || imageUrl.isEmpty) {
      return false;
    }

    if (imageUrl.startsWith('assets/')) {
      return false;
    }

    return true;
  }

  static String _cacheKey(String namespace) {
    if (namespace == _defaultNamespace) {
      return cacheKey;
    }
    return '$_namespacedKeyPrefix.words.${_sanitizeNamespace(namespace)}.v2';
  }

  static String _cacheTimestampKey(String namespace) {
    if (namespace == _defaultNamespace) {
      return cacheTimestampKey;
    }
    return '$_namespacedKeyPrefix.timestamp.${_sanitizeNamespace(namespace)}.v2';
  }

  static String _sanitizeNamespace(String namespace) {
    return namespace.replaceAll(RegExp(r'[^a-zA-Z0-9_\-]'), '_');
  }
}
