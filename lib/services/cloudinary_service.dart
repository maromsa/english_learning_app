import 'dart:convert';

import 'package:http/http.dart' as http;

import '../models/word_data.dart';

class CloudinaryService {
  CloudinaryService({http.Client? httpClient})
      : _httpClient = httpClient ?? http.Client();

  final http.Client _httpClient;

  Future<List<WordData>> fetchWords({
    required String cloudName,
    required String tagName,
    int maxResults = 50,
  }) async {
    final url = Uri.parse(
      'https://res.cloudinary.com/$cloudName/image/list/$tagName.json',
    );

    try {
      final response = await _httpClient
          .get(url)
          .timeout(const Duration(seconds: 10));

      if (response.statusCode != 200) {
        return const <WordData>[];
      }

      final body = jsonDecode(response.body);
      final resources = (body['resources'] as List<dynamic>? ?? [])
          .take(maxResults)
          .toList();

      final List<WordData> results = [];

      for (final resource in resources) {
        if (resource is! Map<String, dynamic>) {
          continue;
        }

        final tags = List<String>.from(resource['tags'] ?? []);
        final wordTag = tags.firstWhere(
          (tag) => tag != tagName,
          orElse: () => '',
        );

        if (wordTag.isEmpty) {
          continue;
        }

        final secureUrl = resource['secure_url'] as String?;
        final publicId = resource['public_id'] as String?;
        final format = resource['format'] as String?;
        final version = resource['version'];

        final fallbackUrl = (publicId != null && format != null)
            ? 'https://res.cloudinary.com/$cloudName/image/upload/v$version/$publicId.$format'
            : null;

        final imageUrl = secureUrl ?? fallbackUrl;

        if (imageUrl == null) {
          continue;
        }

        results.add(
          WordData(
            word: wordTag[0].toUpperCase() + wordTag.substring(1),
            imageUrl: imageUrl,
            publicId: publicId,
          ),
        );
      }

      return results;
    } catch (_) {
      return const <WordData>[];
    }
  }
}
