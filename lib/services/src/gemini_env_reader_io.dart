import 'dart:io';

String? readGeminiApiKey() {
  try {
    return Platform.environment['GEMINI_API_KEY'];
  } catch (_) {
    return null;
  }
}
