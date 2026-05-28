import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../app_config.dart';
import '../models/level_data.dart';
import '../models/offline_pack_progress.dart';
import '../models/word_data.dart';
import '../utils/device_connectivity.dart';
import 'level_repository.dart';
import 'level_unlock_service.dart';
import 'offline_image_cache.dart';
import 'spark_voice_service.dart';
import 'word_repository.dart';

/// Optional hook for tests to observe TTS prefetch without calling Google APIs.
typedef OfflineTtsPrefetcher = Future<bool> Function(
  String word, {
  bool networkAllowed,
});

/// Downloads words, images, and TTS audio for unlocked levels so practice works offline.
class OfflinePracticeService {
  OfflinePracticeService({
    LevelRepository? levelRepository,
    LevelUnlockService? levelUnlockService,
    WordRepository? wordRepository,
    OfflineImageCache? imageCache,
    SparkVoiceService? sparkVoice,
    DeviceConnectivity? connectivity,
    SharedPreferences? prefs,
    OfflineTtsPrefetcher? ttsPrefetcher,
  })  : _levelRepository = levelRepository ?? LevelRepository(),
        _levelUnlockService = levelUnlockService ?? LevelUnlockService(),
        _wordRepository = wordRepository ?? WordRepository(),
        _imageCache = imageCache ?? OfflineImageCache(),
        _sparkVoice = sparkVoice ?? SparkVoiceService(),
        _connectivity = connectivity ?? DeviceConnectivity.current,
        _ttsPrefetcher = ttsPrefetcher,
        _prefsFuture =
            prefs != null ? Future.value(prefs) : SharedPreferences.getInstance();

  static const String manifestKey = 'offline_pack.manifest.v1';

  final LevelRepository _levelRepository;
  final LevelUnlockService _levelUnlockService;
  final WordRepository _wordRepository;
  final OfflineImageCache _imageCache;
  final SparkVoiceService _sparkVoice;
  final DeviceConnectivity _connectivity;
  final OfflineTtsPrefetcher? _ttsPrefetcher;
  final Future<SharedPreferences> _prefsFuture;

  final StreamController<OfflinePackProgress> _progressController =
      StreamController<OfflinePackProgress>.broadcast();

  OfflinePackProgress _latestProgress = const OfflinePackProgress(
    phase: OfflinePackPhase.idle,
  );

  bool _isDownloading = false;

  Stream<OfflinePackProgress> get progressStream => _progressController.stream;

  OfflinePackProgress get latestProgress => _latestProgress;

  void _emit(OfflinePackProgress progress) {
    _latestProgress = progress;
    if (!_progressController.isClosed) {
      _progressController.add(progress);
    }
  }

  Future<OfflinePackManifest?> loadManifest() async {
    final prefs = await _prefsFuture;
    final raw = prefs.getString(manifestKey);
    if (raw == null || raw.isEmpty) {
      return null;
    }
    try {
      return OfflinePackManifest.fromJson(
        jsonDecode(raw) as Map<String, dynamic>,
      );
    } catch (e) {
      debugPrint('OfflinePracticeService: invalid manifest: $e');
      return null;
    }
  }

  Future<List<LevelData>> unlockedLevelsForUser({
    required String userId,
    bool isLocalUser = true,
  }) async {
    final levels = await _levelRepository.loadLevels();
    await _levelUnlockService.applyUnlockStatuses(
      levels,
      userId: userId,
      isLocalUser: isLocalUser,
    );
    return _levelUnlockService.unlockedLevels(levels);
  }

  Future<void> downloadAllUnlocked({
    required String userId,
    bool isLocalUser = true,
  }) async {
    if (_isDownloading) {
      return;
    }
    _isDownloading = true;

    try {
      final unlocked = await unlockedLevelsForUser(
        userId: userId,
        isLocalUser: isLocalUser,
      );

      if (unlocked.isEmpty) {
        _emit(
          const OfflinePackProgress(
            phase: OfflinePackPhase.complete,
            message: 'אין שלבים פתוחים להורדה',
          ),
        );
        return;
      }

      final online = await _connectivity.isOnline();
      final remoteEnabled =
          online && AppConfig.hasCloudinary && AppConfig.cloudinaryCloudName.isNotEmpty;

      var totalItems = 0;
      for (final level in unlocked) {
        totalItems += level.words.length;
      }

      _emit(
        OfflinePackProgress(
          phase: OfflinePackPhase.preparing,
          totalLevels: unlocked.length,
          totalItems: totalItems,
          message: online
              ? 'מכינים חבילת תרגול לאופליין...'
              : 'מורידים מהמטמון המקומי (ללא אינטרנט)...',
        ),
      );

      var completedLevels = 0;
      var completedItems = 0;
      final packedLevelIds = <String>[];

      for (final level in unlocked) {
        _emit(
          OfflinePackProgress(
            phase: OfflinePackPhase.downloading,
            completedLevels: completedLevels,
            totalLevels: unlocked.length,
            currentLevelName: level.name,
            completedItems: completedItems,
            totalItems: totalItems,
            message: 'מורידים: ${level.name}',
          ),
        );

        final packedWords = await _packLevel(
          level: level,
          remoteEnabled: remoteEnabled,
          onWordPacked: () {
            completedItems++;
            _emit(
              OfflinePackProgress(
                phase: OfflinePackPhase.downloading,
                completedLevels: completedLevels,
                totalLevels: unlocked.length,
                currentLevelName: level.name,
                completedItems: completedItems,
                totalItems: totalItems,
                message: 'מורידים: ${level.name}',
              ),
            );
          },
        );

        await _wordRepository.cacheWords(
          packedWords,
          cacheNamespace: level.id,
        );
        packedLevelIds.add(level.id);
        completedLevels++;
      }

      final manifest = OfflinePackManifest(
        userId: userId,
        levelIds: packedLevelIds,
        downloadedAt: DateTime.now(),
        includesRemoteWords: remoteEnabled,
      );
      await _saveManifest(manifest);

      _emit(
        OfflinePackProgress(
          phase: OfflinePackPhase.complete,
          completedLevels: completedLevels,
          totalLevels: unlocked.length,
          completedItems: completedItems,
          totalItems: totalItems,
          message: 'ההורדה הושלמה! אפשר לתרגל גם בלי אינטרנט',
        ),
      );
    } catch (e, stack) {
      debugPrint('OfflinePracticeService download failed: $e\n$stack');
      _emit(
        OfflinePackProgress(
          phase: OfflinePackPhase.failed,
          errorMessage: e.toString(),
          message: 'ההורדה נכשלה. נסו שוב כשיש חיבור',
        ),
      );
    } finally {
      _isDownloading = false;
    }
  }

  Future<List<WordData>> _packLevel({
    required LevelData level,
    required bool remoteEnabled,
    required VoidCallback onWordPacked,
  }) async {
    var words = await _wordRepository.loadWords(
      remoteEnabled: remoteEnabled,
      fallbackWords: level.words,
      cloudName: AppConfig.cloudinaryCloudName,
      tagName: 'english_kids_app',
      maxResults: 50,
      cacheNamespace: level.id,
      preferCacheOnly: !remoteEnabled,
    );

    if (words.isEmpty) {
      words = List<WordData>.from(level.words);
    }

    final List<WordData> packed = [];
    for (final word in words) {
      var imageUrl = word.imageUrl;
      if (OfflineImageCache.shouldDownload(imageUrl)) {
        final local = await _imageCache.downloadAndCache(imageUrl!);
        if (local != null) {
          imageUrl = local;
        }
      }

      final packedWord = WordData(
        word: word.word,
        searchHint: word.searchHint,
        publicId: word.publicId,
        imageUrl: imageUrl,
        isCompleted: word.isCompleted,
        stickerUnlocked: word.stickerUnlocked,
        masteryLevel: word.masteryLevel,
        lastReviewed: word.lastReviewed,
      );

      final prefetcher = _ttsPrefetcher;
      if (prefetcher != null) {
        await prefetcher(packedWord.word, networkAllowed: remoteEnabled);
      } else if (AppConfig.hasGoogleTts) {
        await _sparkVoice.prefetch(
          text: packedWord.word,
          isEnglish: true,
          emotion: SparkEmotion.teaching,
          networkAllowed: remoteEnabled,
        );
      }

      packed.add(packedWord);
      onWordPacked();
    }

    return packed;
  }

  Future<void> _saveManifest(OfflinePackManifest manifest) async {
    final prefs = await _prefsFuture;
    await prefs.setString(manifestKey, jsonEncode(manifest.toJson()));
  }

  /// Rewrites network image URLs to on-disk paths when available.
  Future<List<WordData>> localizeWordsForOffline(List<WordData> words) =>
      _imageCache.localizeWords(words);

  Future<void> clearAll() async {
    final prefs = await _prefsFuture;
    await prefs.remove(manifestKey);
    await _imageCache.clear();
    _emit(const OfflinePackProgress(phase: OfflinePackPhase.idle));
  }

  Future<void> dispose() async {
    await _progressController.close();
    _imageCache.dispose();
  }
}

class OfflinePackManifest {
  const OfflinePackManifest({
    required this.userId,
    required this.levelIds,
    required this.downloadedAt,
    required this.includesRemoteWords,
  });

  final String userId;
  final List<String> levelIds;
  final DateTime downloadedAt;
  final bool includesRemoteWords;

  factory OfflinePackManifest.fromJson(Map<String, dynamic> json) {
    return OfflinePackManifest(
      userId: json['userId'] as String? ?? '',
      levelIds: (json['levelIds'] as List<dynamic>? ?? [])
          .map((e) => e.toString())
          .toList(),
      downloadedAt: DateTime.tryParse(json['downloadedAt'] as String? ?? '') ??
          DateTime.fromMillisecondsSinceEpoch(0),
      includesRemoteWords: json['includesRemoteWords'] as bool? ?? false,
    );
  }

  Map<String, dynamic> toJson() => {
        'userId': userId,
        'levelIds': levelIds,
        'downloadedAt': downloadedAt.toIso8601String(),
        'includesRemoteWords': includesRemoteWords,
      };
}
