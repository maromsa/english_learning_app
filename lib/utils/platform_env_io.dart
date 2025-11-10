import 'dart:io';

String readPlatformEnvironment(String key) {
  try {
    return Platform.environment[key] ?? '';
  } catch (_) {
    return '';
  }
}
