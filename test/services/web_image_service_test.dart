import 'dart:collection';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:english_learning_app/services/ai_image_validator.dart';
import 'package:english_learning_app/services/network/app_http_client.dart';
import 'package:english_learning_app/services/web_image_service.dart';
import 'package:flutter_test/flutter_test.dart';

import '../test_utils/test_http_adapter.dart';

class _FakeAiValidator implements AiImageValidator {
  _FakeAiValidator(List<bool> answers) : _answers = Queue<bool>.from(answers);

  final Queue<bool> _answers;
  final List<String> validatedWords = <String>[];
  int validationCount = 0;

  @override
  Future<bool> validate(
    Uint8List imageBytes,
    String word, {
    String? mimeType,
  }) async {
    validationCount += 1;
    validatedWords.add(word);
    return _answers.isEmpty ? true : _answers.removeFirst();
  }
}

void main() {
  test('returns the first validated image result', () async {
    final dio = Dio();
    dio.httpClientAdapter = TestHttpClientAdapter((options, _) async {
      if (options.uri.host == 'pixabay.com') {
        return ResponseBody.fromString(
          '{"hits":[{"webformatURL":"https://cdn.pixabay.com/photo1.jpg","tags":"Apple, Fruit"}]}',
          200,
          headers: {
            Headers.contentTypeHeader: ['application/json']
          },
        );
      }
      if (options.uri.toString() == 'https://cdn.pixabay.com/photo1.jpg') {
        return ResponseBody.fromBytes(
          List<int>.filled(4, 1),
          200,
          headers: {
            Headers.contentTypeHeader: ['image/jpeg']
          },
        );
      }
      return ResponseBody.fromString('not found', 404);
    });

    final validator = _FakeAiValidator(<bool>[true]);
    final service = WebImageService(
      apiKey: 'demo',
      imageValidator: validator,
      httpClient: AppHttpClient(dio: dio),
    );

    final result = await service.fetchImageForWord('apple');

    expect(result?.imageUrl, 'https://cdn.pixabay.com/photo1.jpg');
    expect(result?.inferredWord, 'Apple');
    expect(validator.validatedWords, equals(<String>['Apple']));

    service.dispose();
  });

  test('skips failing candidates until validation succeeds', () async {
    final dio = Dio();
    dio.httpClientAdapter = TestHttpClientAdapter((options, _) async {
      if (options.uri.host == 'pixabay.com') {
        return ResponseBody.fromString(
          '{"hits":[{"webformatURL":"https://cdn.pixabay.com/photo_bad.jpg","tags":"Stone"},'
          '{"webformatURL":"https://cdn.pixabay.com/photo_good.jpg","tags":"Banana"}]}',
          200,
          headers: {
            Headers.contentTypeHeader: ['application/json']
          },
        );
      }
      if (options.uri.toString() == 'https://cdn.pixabay.com/photo_bad.jpg') {
        return ResponseBody.fromBytes(
          List<int>.filled(4, 2),
          200,
          headers: {
            Headers.contentTypeHeader: ['image/jpeg']
          },
        );
      }
      if (options.uri.toString() == 'https://cdn.pixabay.com/photo_good.jpg') {
        return ResponseBody.fromBytes(
          List<int>.filled(4, 3),
          200,
          headers: {
            Headers.contentTypeHeader: ['image/jpeg']
          },
        );
      }
      return ResponseBody.fromString('not found', 404);
    });

    final validator = _FakeAiValidator(<bool>[false, true]);
    final service = WebImageService(
      apiKey: 'demo',
      imageValidator: validator,
      httpClient: AppHttpClient(dio: dio),
    );

    final result = await service.fetchImageForWord('banana');

    expect(result?.imageUrl, 'https://cdn.pixabay.com/photo_good.jpg');
    expect(result?.inferredWord, 'Banana');
    expect(validator.validationCount, 2);

    service.dispose();
  });

  test('returns null when api key is missing', () async {
    final dio = Dio();
    dio.httpClientAdapter = TestHttpClientAdapter(
      (options, _) async =>
          ResponseBody.fromString('should not be called', 500),
    );
    final validator = _FakeAiValidator(<bool>[]);
    final service = WebImageService(
      apiKey: '',
      imageValidator: validator,
      httpClient: AppHttpClient(dio: dio),
    );

    final result = await service.fetchImageForWord('cat');

    expect(result, isNull);
    expect(validator.validationCount, 0);

    service.dispose();
  });
}
