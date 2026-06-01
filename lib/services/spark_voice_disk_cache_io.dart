import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:english_learning_app/services/spark_voice_disk_cache.dart';
import 'package:path_provider/path_provider.dart';

class SparkVoiceDiskCacheImpl implements SparkVoiceDiskCache {
  @override
  Future<List<int>?> read(String cacheKey) async {
    final file = File(await _pathFor(cacheKey));
    if (!await file.exists()) {
      return null;
    }
    return file.readAsBytes();
  }

  @override
  Future<void> write(String cacheKey, List<int> bytes) async {
    final file = File(await _pathFor(cacheKey));
    await file.writeAsBytes(bytes);
  }

  Future<String> _pathFor(String cacheKey) async {
    final dir = await getTemporaryDirectory();
    final hash = sha256.convert(utf8.encode(cacheKey)).toString();
    return '${dir.path}/tts_$hash.mp3';
  }
}

SparkVoiceDiskCache createSparkVoiceDiskCache() => SparkVoiceDiskCacheImpl();
