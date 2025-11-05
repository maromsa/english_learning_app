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
  }) async {
    final prefs = await _prefsFuture;
    final cachedJson = prefs.getString(cacheKey);
    final cachedTimestamp = prefs.getInt(cacheTimestampKey);
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
        await _saveCache(prefs, remoteWords);
        return remoteWords;
      }
    }

    if (cachedWords != null) {
      return cachedWords;
    }

    final enrichedFallback = await _maybeAddWebImages(fallbackWords);

    if (enrichedFallback.isNotEmpty) {
      await _saveCache(prefs, enrichedFallback);
    }

    return enrichedFallback;
  }

  Future<void> cacheWords(List<WordData> words) async {
    final prefs = await _prefsFuture;
    await _saveCache(prefs, words);
  }

  Future<void> clearCache() async {
    final prefs = await _prefsFuture;
    await prefs.remove(cacheKey);
    await prefs.remove(cacheTimestampKey);
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

  Future<void> _saveCache(SharedPreferences prefs, List<WordData> words) async {
    final jsonStr = jsonEncode(words.map((w) => w.toJson()).toList());
    await prefs.setString(cacheKey, jsonStr);
    await prefs.setInt(cacheTimestampKey, DateTime.now().millisecondsSinceEpoch);
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
        final remoteUrl = await provider.fetchImageForWord(word.word);
        if (remoteUrl == null) {
          results.add(word);
          continue;
        }

        results.add(
          WordData(
            word: word.word,
            publicId: word.publicId,
            imageUrl: remoteUrl,
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
}
