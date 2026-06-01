import 'package:english_learning_app/services/spark_voice_disk_cache.dart';

class SparkVoiceDiskCacheStub implements SparkVoiceDiskCache {
  @override
  Future<List<int>?> read(String cacheKey) async => null;

  @override
  Future<void> write(String cacheKey, List<int> bytes) async {}
}

SparkVoiceDiskCache createSparkVoiceDiskCache() => SparkVoiceDiskCacheStub();
