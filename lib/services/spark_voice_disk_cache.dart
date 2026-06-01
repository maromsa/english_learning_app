/// Disk-backed TTS cache (mobile/desktop only).
abstract class SparkVoiceDiskCache {
  Future<List<int>?> read(String cacheKey);
  Future<void> write(String cacheKey, List<int> bytes);
}
