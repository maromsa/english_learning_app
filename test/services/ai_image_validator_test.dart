import 'dart:convert';
import 'dart:typed_data';

import 'package:english_learning_app/services/ai_image_validator.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

void main() {
  group('HttpFunctionAiImageValidator', () {
    final sampleBytes = Uint8List.fromList(List<int>.generate(6, (index) => index));
    final endpoint = Uri.parse('https://example.com/validate');

    test('returns approval when backend responds with approved flag', () async {
      late http.Request capturedRequest;
      final validator = HttpFunctionAiImageValidator(
        endpoint,
        client: MockClient((request) async {
          capturedRequest = request;
          return http.Response(jsonEncode({'approved': true, 'confidence': 0.92}), 200);
        }),
      );

      final approved = await validator.validate(sampleBytes, 'Apple', mimeType: 'image/png');

      expect(approved, isTrue);
      expect(validator.lastConfidence, closeTo(0.92, 1e-6));
      expect(validator.lastApproval, isTrue);

      final payload = jsonDecode(capturedRequest.body) as Map<String, dynamic>;
      expect(payload['word'], 'Apple');
      expect(payload['mimeType'], 'image/png');
      expect(payload['imageBase64'], base64Encode(sampleBytes));

      validator.dispose();
    });

    test('falls back to confidence threshold when approval flag missing', () async {
      final validator = HttpFunctionAiImageValidator(
        endpoint,
        client: MockClient((_) async {
          return http.Response(jsonEncode({'confidence': '0.73'}), 200);
        }),
      );

      final approved = await validator.validate(sampleBytes, 'Banana');

      expect(approved, isTrue);
      expect(validator.lastApproval, isTrue);
      expect(validator.lastConfidence, closeTo(0.73, 1e-6));

      validator.dispose();
    });

    test('respects custom minimumConfidence threshold', () async {
      final validator = HttpFunctionAiImageValidator(
        endpoint,
        minimumConfidence: 0.8,
        client: MockClient((_) async {
          return http.Response(jsonEncode({'confidence': 0.71}), 200);
        }),
      );

      final approved = await validator.validate(sampleBytes, 'Cherry');

      expect(approved, isFalse);
      expect(validator.lastApproval, isFalse);
      expect(validator.lastConfidence, closeTo(0.71, 1e-6));

      validator.dispose();
    });

    test('returns false on non-200 or malformed responses', () async {
      var firstCall = true;
      final validator = HttpFunctionAiImageValidator(
        endpoint,
        client: MockClient((_) async {
          if (firstCall) {
            firstCall = false;
            return http.Response('nope', 500);
          }
          return http.Response(jsonEncode({'unexpected': true}), 200);
        }),
      );

      final firstAttempt = await validator.validate(sampleBytes, 'Durian', mimeType: 'image/jpeg');
      expect(firstAttempt, isFalse);
      expect(validator.lastApproval, isNull);
      expect(validator.lastConfidence, isNull);

      final secondAttempt = await validator.validate(sampleBytes, 'Durian');
      expect(secondAttempt, isFalse);
      expect(validator.lastApproval, isNull);
      expect(validator.lastConfidence, isNull);

      validator.dispose();
    });
  });
}
