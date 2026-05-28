import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/word_data.dart';

/// Persists remote word images on disk and maps source URLs to local paths.
class OfflineImageCache {
  OfflineImageCache({
    SharedPreferences? prefs,
    http.Client? httpClient,
    Future<Directory> Function()? directoryProvider,
  })  : _prefsFuture =
            prefs != null ? Future.value(prefs) : SharedPreferences.getInstance(),
        _httpClient = httpClient ?? http.Client(),
        _directoryProvider = directoryProvider ?? _defaultImageDirectory;

  static const String _mapKey = 'offline_pack.image_map.v1';

  final Future<SharedPreferences> _prefsFuture;
  final http.Client _httpClient;
  final Future<Directory> Function() _directoryProvider;

  static Future<Directory> _defaultImageDirectory() async {
    final docs = await getApplicationDocumentsDirectory();
    final dir = Directory('${docs.path}/offline_pack/images');
    if (!await dir.exists()) {
      await dir.create(recursive: true);
    }
    return dir;
  }

  Future<Map<String, String>> _loadMap() async {
    final prefs = await _prefsFuture;
    final raw = prefs.getString(_mapKey);
    if (raw == null || raw.isEmpty) {
      return <String, String>{};
    }
    try {
      final decoded = jsonDecode(raw) as Map<String, dynamic>;
      return decoded.map(
        (key, value) => MapEntry(key, value as String),
      );
    } catch (e) {
      debugPrint('OfflineImageCache: corrupt map, resetting: $e');
      return <String, String>{};
    }
  }

  Future<void> _saveMap(Map<String, String> map) async {
    final prefs = await _prefsFuture;
    await prefs.setString(_mapKey, jsonEncode(map));
  }

  static bool shouldDownload(String? imageUrl) {
    if (imageUrl == null || imageUrl.isEmpty) {
      return false;
    }
    if (imageUrl.startsWith('assets/')) {
      return false;
    }
    if (!imageUrl.startsWith('http://') && !imageUrl.startsWith('https://')) {
      return false;
    }
    return true;
  }

  Future<String?> getLocalPath(String sourceUrl) async {
    final map = await _loadMap();
    final local = map[sourceUrl];
    if (local == null || local.isEmpty) {
      return null;
    }
    final file = File(local);
    if (await file.exists()) {
      return local;
    }
    return null;
  }

  Future<String?> downloadAndCache(String sourceUrl) async {
    if (!shouldDownload(sourceUrl)) {
      return null;
    }

    final existing = await getLocalPath(sourceUrl);
    if (existing != null) {
      return existing;
    }

    try {
      final response = await _httpClient
          .get(Uri.parse(sourceUrl))
          .timeout(const Duration(seconds: 30));
      if (response.statusCode < 200 || response.statusCode >= 300) {
        debugPrint(
          'OfflineImageCache: HTTP ${response.statusCode} for $sourceUrl',
        );
        return null;
      }

      final bytes = response.bodyBytes;
      if (bytes.isEmpty) {
        return null;
      }

      final dir = await _directoryProvider();
      final hash = sha256.convert(utf8.encode(sourceUrl)).toString();
      final extension = _extensionFromUrl(sourceUrl, response.headers['content-type']);
      final file = File('${dir.path}/$hash$extension');
      await file.writeAsBytes(bytes, flush: true);

      final map = await _loadMap();
      map[sourceUrl] = file.path;
      await _saveMap(map);
      return file.path;
    } catch (e) {
      debugPrint('OfflineImageCache: download failed for $sourceUrl: $e');
      return null;
    }
  }

  String _extensionFromUrl(String url, String? contentType) {
    final lower = url.toLowerCase();
    if (lower.endsWith('.png')) {
      return '.png';
    }
    if (lower.endsWith('.webp')) {
      return '.webp';
    }
    if (lower.endsWith('.gif')) {
      return '.gif';
    }
    if (contentType != null && contentType.contains('png')) {
      return '.png';
    }
    return '.jpg';
  }

  Future<List<WordData>> localizeWords(List<WordData> words) async {
    final List<WordData> localized = [];
    for (final word in words) {
      final imageUrl = word.imageUrl;
      if (!shouldDownload(imageUrl)) {
        localized.add(word);
        continue;
      }
      final localPath = await getLocalPath(imageUrl!);
      if (localPath == null) {
        localized.add(word);
        continue;
      }
      localized.add(
        WordData(
          word: word.word,
          searchHint: word.searchHint,
          publicId: word.publicId,
          imageUrl: localPath,
          isCompleted: word.isCompleted,
          stickerUnlocked: word.stickerUnlocked,
          masteryLevel: word.masteryLevel,
          lastReviewed: word.lastReviewed,
        ),
      );
    }
    return localized;
  }

  Future<void> clear() async {
    final prefs = await _prefsFuture;
    await prefs.remove(_mapKey);
    try {
      final dir = await _directoryProvider();
      if (await dir.exists()) {
        await dir.delete(recursive: true);
      }
    } catch (e) {
      debugPrint('OfflineImageCache: clear directory failed: $e');
    }
  }

  void dispose() {
    _httpClient.close();
  }
}
