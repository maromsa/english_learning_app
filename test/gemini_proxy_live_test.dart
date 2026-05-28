// Live integration test — hits your real GEMINI_PROXY_URL (not mocked).
//
// Run only when you want to verify cloud connectivity:
//   set -a && source .env && set +a
//   flutter test test/gemini_proxy_live_test.dart
//
// Skips automatically when GEMINI_PROXY_URL is unset.

import 'dart:io';

import 'package:english_learning_app/services/gemini_proxy_service.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  final proxyUrl = Platform.environment['GEMINI_PROXY_URL']?.trim() ?? '';

  test(
    'GEMINI_PROXY_URL returns non-empty text for mode text',
    () async {
      final endpoint = Uri.tryParse(proxyUrl);
      expect(endpoint, isNotNull);
      expect(endpoint!.hasScheme, isTrue);
      expect(endpoint.hasAuthority, isTrue);

      final service = GeminiProxyService(
        endpoint,
        timeout: const Duration(seconds: 30),
      );

      addTearDown(service.dispose);

      final text = await service.generateText(
        'Say hello in one short English sentence.',
        systemInstruction:
            'You are Spark, a friendly tutor. Reply in plain text only.',
      );

      expect(
        text,
        isNotNull,
        reason: 'Proxy returned null — check logs and function deployment.',
      );
      expect(text!.trim().isNotEmpty, isTrue);
    },
    skip: proxyUrl.isEmpty
        ? 'GEMINI_PROXY_URL not set'
        : false,
  );
}
