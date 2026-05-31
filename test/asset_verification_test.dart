import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// Paths that must exist even if directory scanning would catch them — clearer
/// failures and guards runtime-critical 3D map assets referenced in
/// [assets/map_3d/js/main.js].
const _criticalAssetPaths = <String>[
  'assets/map_3d/models/map_island.glb',
  'assets/map_3d/models/spark.glb',
  'assets/map_3d/index.html',
  'assets/map_3d/js/main.js',
  'assets/data/levels.json',
];

void main() {
  late Directory projectRoot;

  setUpAll(() {
    projectRoot = _findProjectRoot();
  });

  test('critical runtime assets exist on disk', () {
    final missing = <String>[];
    for (final relativePath in _criticalAssetPaths) {
      final file = File('${projectRoot.path}/$relativePath');
      if (!file.existsSync()) {
        missing.add(relativePath);
      }
    }
    expect(
      missing,
      isEmpty,
      reason:
          'Critical assets missing (commit them and ensure pubspec.yaml lists '
          'their parent directories):\n${missing.join('\n')}',
    );
  });

  test('every asset declared in pubspec.yaml exists on disk', () {
    final pubspec = File('${projectRoot.path}/pubspec.yaml');
    expect(pubspec.existsSync(), isTrue, reason: 'pubspec.yaml not found');

    final declared = _parseFlutterAssetEntries(pubspec.readAsStringSync());
    expect(declared, isNotEmpty, reason: 'No flutter.assets entries in pubspec');

    final missing = <String>[];
    for (final entry in declared) {
      missing.addAll(_missingForDeclaredEntry(projectRoot, entry));
    }

    expect(
      missing,
      isEmpty,
      reason:
          'Declared pubspec assets missing on disk:\n${missing.join('\n')}',
    );
  });
}

Directory _findProjectRoot() {
  var dir = Directory.current;
  while (true) {
    if (File('${dir.path}/pubspec.yaml').existsSync()) {
      return dir;
    }
    final parent = dir.parent;
    if (parent.path == dir.path) {
      fail('Could not locate project root (pubspec.yaml) from ${dir.path}');
    }
    dir = parent;
  }
}

/// Reads `flutter: assets:` list entries from [pubspec.yaml].
List<String> _parseFlutterAssetEntries(String content) {
  final lines = content.split('\n');
  var inFlutter = false;
  var inAssets = false;
  final entries = <String>[];

  for (final line in lines) {
    if (line == 'flutter:') {
      inFlutter = true;
      inAssets = false;
      continue;
    }

    if (inFlutter && line.isNotEmpty && !line.startsWith(' ') && !line.startsWith('#')) {
      inFlutter = false;
      inAssets = false;
    }

    if (!inFlutter) {
      continue;
    }

    if (line.trim() == 'assets:') {
      inAssets = true;
      continue;
    }

    if (!inAssets) {
      continue;
    }

    final trimmed = line.trim();
    if (trimmed.startsWith('- ')) {
      entries.add(trimmed.substring(2).trim());
      continue;
    }

    // Next flutter: key at two-space indent ends the assets block.
    if (RegExp(r'^  \S').hasMatch(line) && !line.startsWith('    ')) {
      inAssets = false;
    }
  }

  return entries;
}

List<String> _missingForDeclaredEntry(Directory projectRoot, String entry) {
  final normalized = entry.endsWith('/') ? entry : entry;
  final target = FileSystemEntity.typeSync('${projectRoot.path}/$normalized');

  if (normalized.endsWith('/')) {
    if (target == FileSystemEntityType.notFound) {
      return ['$normalized (directory missing)'];
    }
    if (target != FileSystemEntityType.directory) {
      return ['$normalized (expected directory)'];
    }

    final dir = Directory('${projectRoot.path}/$normalized');
    final files = _listAssetFiles(dir);
    return files
        .where((path) => !File(path).existsSync())
        .map((path) => _relativeToProject(projectRoot, path))
        .toList();
  }

  final file = File('${projectRoot.path}/$normalized');
  if (!file.existsSync()) {
    return [normalized];
  }
  return const [];
}

List<String> _listAssetFiles(Directory directory) {
  final result = <String>[];
  if (!directory.existsSync()) {
    return result;
  }

  for (final entity in directory.listSync(recursive: true, followLinks: false)) {
    if (entity is! File) {
      continue;
    }
    final name = entity.uri.pathSegments.last;
    if (name.startsWith('.')) {
      continue;
    }
    result.add(entity.path);
  }
  return result;
}

String _relativeToProject(Directory projectRoot, String absolutePath) {
  final root = projectRoot.path.endsWith('/')
      ? projectRoot.path
      : '${projectRoot.path}/';
  if (absolutePath.startsWith(root)) {
    return absolutePath.substring(root.length);
  }
  return absolutePath;
}
