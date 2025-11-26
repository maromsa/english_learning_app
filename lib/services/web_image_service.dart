import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';

import 'ai_image_validator.dart';
import 'network/app_http_client.dart';

/// Contract for fetching web images for a given word.
abstract class WebImageProvider {
  Future<WebImageResult?> fetchImageForWord(String word, {String? searchHint});
}

class WebImageService implements WebImageProvider {
  WebImageService({
    required String apiKey,
    AiImageValidator? imageValidator,
    AppHttpClient? httpClient,
  })  : _apiKey = apiKey,
        _httpClient = httpClient ??
            AppHttpClient(
              connectTimeout: _requestTimeout,
              receiveTimeout: _requestTimeout,
            ),
        _imageValidator = imageValidator;

  static const Duration _requestTimeout = Duration(seconds: 8);
  static const int _maxCandidates = 8;

  final String _apiKey;
  final AppHttpClient _httpClient;
  final AiImageValidator? _imageValidator;

  @override
  Future<WebImageResult?> fetchImageForWord(
    String word, {
    String? searchHint,
  }) async {
    if (_apiKey.isEmpty) {
      return null;
    }

    final query = (searchHint ?? word).trim();
    if (query.isEmpty) {
      return null;
    }

    final candidates = await _searchPixabay(query);
    if (candidates.isEmpty) {
      return null;
    }

    for (final candidate in candidates) {
      final imageUrl = _extractImageUrl(candidate);
      if (imageUrl == null) {
        continue;
      }

      final inferredWord = _extractLabel(candidate) ?? word;

      if (_imageValidator == null) {
        return WebImageResult(imageUrl: imageUrl, inferredWord: inferredWord);
      }

      final downloaded = await _downloadImage(imageUrl);
      if (downloaded == null) {
        continue;
      }

      final matches = await _imageValidator!.validate(
        downloaded.bytes,
        inferredWord,
        mimeType: downloaded.mimeType,
      );

      if (matches) {
        return WebImageResult(imageUrl: imageUrl, inferredWord: inferredWord);
      }
    }

    return null;
  }

  void dispose() {
    _httpClient.close();
  }

  Future<List<Map<String, dynamic>>> _searchPixabay(String word) async {
    final queryParameters = <String, String>{
      'key': _apiKey,
      'q': word,
      'image_type': 'photo',
      'orientation': 'horizontal',
      'per_page': '$_maxCandidates',
      'safesearch': 'true',
    };

    final uri = Uri.https('pixabay.com', '/api/', queryParameters);

    try {
      final response = await _httpClient.dio.getUri<Map<String, dynamic>>(
        uri,
        options: Options(responseType: ResponseType.json),
      );
      if (response.statusCode != 200) {
        return const <Map<String, dynamic>>[];
      }

      final decoded = response.data;
      if (decoded == null) {
        return const <Map<String, dynamic>>[];
      }

      final hits = decoded['hits'] as List<dynamic>?;
      if (hits == null) {
        return const <Map<String, dynamic>>[];
      }

      return hits.whereType<Map<String, dynamic>>().toList(growable: false);
    } catch (_) {
      return const <Map<String, dynamic>>[];
    }
  }

  Future<_DownloadedImage?> _downloadImage(String url) async {
    try {
      final response = await _httpClient.dio.getUri<List<int>>(
        Uri.parse(url),
        options: Options(responseType: ResponseType.bytes),
      );
      if (response.statusCode != 200) {
        return null;
      }

      final contentTypeHeader = response.headers.value('content-type');
      final mimeType = contentTypeHeader?.split(';').first;

      final data = response.data;
      if (data == null) {
        return null;
      }

      return _DownloadedImage(Uint8List.fromList(data), mimeType);
    } catch (error) {
      debugPrint('WebImageService download failed: $error');
      return null;
    }
  }

  String? _extractImageUrl(Map<String, dynamic> candidate) {
    final url = candidate['webformatURL'] as String? ??
        candidate['largeImageURL'] as String? ??
        candidate['previewURL'] as String?;

    if (url == null || url.isEmpty) {
      return null;
    }

    return url;
  }

  String? _extractLabel(Map<String, dynamic> candidate) {
    final tags = candidate['tags'] as String?;
    if (tags == null || tags.isEmpty) {
      return null;
    }

    final firstTag = tags
        .split(',')
        .map((tag) => tag.trim())
        .firstWhere((tag) => tag.isNotEmpty, orElse: () => '');

    return firstTag.isEmpty ? null : _normalizeLabel(firstTag);
  }

  String _normalizeLabel(String label) {
    final words = label
        .split(RegExp(r'[\s_-]+'))
        .where((part) => part.trim().isNotEmpty)
        .map((part) {
      final lowercase = part.toLowerCase();
      if (lowercase.length <= 1) {
        return lowercase.toUpperCase();
      }
      return lowercase[0].toUpperCase() + lowercase.substring(1);
    }).toList();

    return words.isEmpty ? label : words.join(' ');
  }
}

class _DownloadedImage {
  _DownloadedImage(this.bytes, this.mimeType);

  final Uint8List bytes;
  final String? mimeType;
}

class WebImageResult {
  const WebImageResult({required this.imageUrl, required this.inferredWord});

  final String imageUrl;
  final String inferredWord;
}
