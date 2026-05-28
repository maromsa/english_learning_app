import '../models/word_data.dart';
import '../services/offline_practice_service.dart';
import '../services/word_repository.dart';
import '../utils/device_connectivity.dart';

/// Loads lesson words with offline-first behavior (cache + on-disk images).
class OfflineWordLoader {
  OfflineWordLoader({
    WordRepository? wordRepository,
    OfflinePracticeService? offlinePracticeService,
    DeviceConnectivity? connectivity,
  })  : _wordRepository = wordRepository ?? WordRepository(),
        _offlinePractice = offlinePracticeService ?? OfflinePracticeService(),
        _connectivity = connectivity ?? DeviceConnectivity.current;

  final WordRepository _wordRepository;
  final OfflinePracticeService _offlinePractice;
  final DeviceConnectivity _connectivity;

  Future<List<WordData>> loadWords({
    required bool remoteCapable,
    required List<WordData> fallbackWords,
    required String cacheNamespace,
    String cloudName = '',
    String tagName = '',
    int maxResults = 50,
  }) async {
    final online = await _connectivity.isOnline();
    final remoteEnabled = remoteCapable && online;

    var words = await _wordRepository.loadWords(
      remoteEnabled: remoteEnabled,
      fallbackWords: fallbackWords,
      cloudName: cloudName,
      tagName: tagName,
      maxResults: maxResults,
      cacheNamespace: cacheNamespace,
      preferCacheOnly: !online,
    );

    if (words.isEmpty) {
      words = List<WordData>.from(fallbackWords);
    }

    return _offlinePractice.localizeWordsForOffline(words);
  }
}
