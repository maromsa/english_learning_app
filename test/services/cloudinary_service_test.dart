import 'dart:convert';

import 'package:english_learning_app/services/cloudinary_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

void main() {
  const cloudName = 'sample-cloud';
  const tagName = 'english_kids_app';

  group('CloudinaryService.fetchWords', () {
    test(
      'returns parsed words when Cloudinary responds successfully',
      () async {
        final mockClient = MockClient((request) async {
          expect(
            request.url,
            Uri.parse(
              'https://res.cloudinary.com/$cloudName/image/list/$tagName.json',
            ),
          );

          final body = jsonEncode({
            'resources': [
              {
                'tags': [tagName, 'apple'],
                'secure_url': 'https://res.cloudinary.com/demo/apple.png',
                'public_id': 'apple_image',
              },
            ],
          });

          return http.Response(
            body,
            200,
            headers: {'content-type': 'application/json'},
          );
        });

        final service = CloudinaryService(httpClient: mockClient);

        final words = await service.fetchWords(
          cloudName: cloudName,
          tagName: tagName,
          maxResults: 10,
        );

        expect(words, hasLength(1));
        expect(words.first.word, 'Apple');
        expect(
          words.first.imageUrl,
          'https://res.cloudinary.com/demo/apple.png',
        );
        expect(words.first.publicId, 'apple_image');
      },
    );

    test('falls back to constructed URL when secure_url is missing', () async {
      final mockClient = MockClient((request) async {
        final body = jsonEncode({
          'resources': [
            {
              'tags': [tagName, 'banana'],
              'public_id': 'fruits/banana',
              'format': 'jpg',
              'version': 1717171,
            },
          ],
        });

        return http.Response(
          body,
          200,
          headers: {'content-type': 'application/json'},
        );
      });

      final service = CloudinaryService(httpClient: mockClient);

      final words = await service.fetchWords(
        cloudName: cloudName,
        tagName: tagName,
      );

      expect(words, hasLength(1));
      expect(words.first.word, 'Banana');
      expect(
        words.first.imageUrl,
        'https://res.cloudinary.com/$cloudName/image/upload/v1717171/fruits/banana.jpg',
      );
    });

    test('returns empty list on non-200 response', () async {
      final mockClient = MockClient((request) async {
        return http.Response('Error', 500);
      });

      final service = CloudinaryService(httpClient: mockClient);

      final words = await service.fetchWords(
        cloudName: cloudName,
        tagName: tagName,
      );

      expect(words, isEmpty);
    });

    test('ignores malformed resources and keeps valid ones', () async {
      final mockClient = MockClient((request) async {
        final body = jsonEncode({
          'resources': [
            'invalid',
            {
              'tags': [tagName],
              'secure_url': 'https://res.cloudinary.com/demo/invalid.png',
            },
            {
              'tags': [tagName, 'car'],
              'secure_url': 'https://res.cloudinary.com/demo/car.png',
            },
          ],
        });

        return http.Response(
          body,
          200,
          headers: {'content-type': 'application/json'},
        );
      });

      final service = CloudinaryService(httpClient: mockClient);

      final words = await service.fetchWords(
        cloudName: cloudName,
        tagName: tagName,
      );

      expect(words, hasLength(1));
      expect(words.first.word, 'Car');
    });
  });
}
