import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';

import '../l10n/spark_strings.dart';
import 'network/app_http_client.dart';

/// Normalized crop rectangle (0–1) sent with generate requests.
class AiImageCropRect {
  const AiImageCropRect({
    required this.x,
    required this.y,
    required this.width,
    required this.height,
  });

  final double x;
  final double y;
  final double width;
  final double height;

  Map<String, dynamic> toJson() => <String, dynamic>{
        'x': x,
        'y': y,
        'width': width,
        'height': height,
      };
}

/// Payload for `POST /api/v1/generate` on the Render-hosted backend.
class AiGenerateRequest {
  const AiGenerateRequest({
    required this.prompt,
    required this.imageBase64,
    this.mimeType = 'image/jpeg',
    this.crop,
  });

  final String prompt;
  final String imageBase64;
  final String mimeType;
  final AiImageCropRect? crop;

  Map<String, dynamic> toJson() => <String, dynamic>{
        'prompt': prompt.trim(),
        'imageBase64': imageBase64,
        'mimeType': mimeType,
        if (crop != null) 'crop': crop!.toJson(),
      };
}

/// Successful image generation response from the backend.
class AiGenerateResult {
  const AiGenerateResult({
    this.imageUrl,
    this.imageBase64,
  });

  final String? imageUrl;
  final String? imageBase64;

  bool get hasImage =>
      (imageUrl != null && imageUrl!.isNotEmpty) ||
      (imageBase64 != null && imageBase64!.isNotEmpty);
}

/// Machine-readable failure codes for UI and analytics.
enum AiServiceFailureCode {
  serverOverloaded,
  backendUnavailable,
  networkError,
  invalidResponse,
}

extension AiServiceFailureCodeX on AiServiceFailureCode {
  /// Stable string keys (e.g. `server_overloaded`).
  String get code => switch (this) {
        AiServiceFailureCode.serverOverloaded => 'server_overloaded',
        AiServiceFailureCode.backendUnavailable => 'backend_unavailable',
        AiServiceFailureCode.networkError => 'network_error',
        AiServiceFailureCode.invalidResponse => 'invalid_response',
      };

  String get userMessage => SparkStrings.aiFailureMessageForCode(code);
}

/// Thrown when the AI backend cannot fulfill a generate request.
class AiServiceException implements Exception {
  const AiServiceException(
    this.failureCode, {
    this.statusCode,
    this.message,
  });

  final AiServiceFailureCode failureCode;
  final int? statusCode;
  final String? message;

  String get code => failureCode.code;

  @override
  String toString() =>
      'AiServiceException(${failureCode.code}, status: $statusCode, message: $message)';
}

/// HTTP client for the Render `onrender.com` image-generation API.
class AiService {
  AiService({
    required Uri baseUrl,
    AppHttpClient? httpClient,
    Duration timeout = const Duration(seconds: 30),
    int max502Attempts = 3,
  })  : _generateUri = _resolveGenerateUri(baseUrl),
        _max502Attempts = max502Attempts.clamp(1, 5),
        _httpClient = httpClient ??
            AppHttpClient(
              dio: Dio(
                BaseOptions(
                  connectTimeout: timeout,
                  receiveTimeout: timeout,
                  sendTimeout: timeout,
                  contentType: Headers.jsonContentType,
                  responseType: ResponseType.json,
                ),
              ),
            );

  static const Set<int> _gatewayStatuses = {502, 503, 504};

  final Uri _generateUri;
  final int _max502Attempts;
  final AppHttpClient _httpClient;

  static Uri _resolveGenerateUri(Uri baseUrl) {
    final normalized = baseUrl.path.endsWith('/')
        ? baseUrl.path.substring(0, baseUrl.path.length - 1)
        : baseUrl.path;
    if (normalized.endsWith('/api/v1/generate')) {
      return baseUrl;
    }
    return baseUrl.replace(
      path: '${normalized.isEmpty ? '' : normalized}/api/v1/generate',
    );
  }

  /// Calls `POST /api/v1/generate`, retrying 502 responses with exponential backoff.
  Future<AiGenerateResult> generate(AiGenerateRequest request) async {
    DioException? lastDioError;

    for (var attempt = 0; attempt < _max502Attempts; attempt++) {
      try {
        final response = await _httpClient.dio.postUri<Map<String, dynamic>>(
          _generateUri,
          data: request.toJson(),
          options: Options(
            contentType: Headers.jsonContentType,
            responseType: ResponseType.json,
          ),
        );

        if (response.statusCode != 200) {
          throw _mapHttpStatus(response.statusCode ?? 0, response.data);
        }

        final decoded = response.data;
        if (decoded is! Map<String, dynamic>) {
          throw const AiServiceException(AiServiceFailureCode.invalidResponse);
        }

        final imageUrl = decoded['imageUrl'] as String? ??
            decoded['image_url'] as String?;
        final imageBase64 = decoded['imageBase64'] as String? ??
            decoded['image_base64'] as String?;

        final result = AiGenerateResult(
          imageUrl: imageUrl?.trim().isEmpty == true ? null : imageUrl?.trim(),
          imageBase64: imageBase64?.trim().isEmpty == true
              ? null
              : imageBase64?.trim(),
        );

        if (!result.hasImage) {
          throw const AiServiceException(AiServiceFailureCode.invalidResponse);
        }

        return result;
      } on AiServiceException {
        rethrow;
      } on DioException catch (error) {
        lastDioError = error;
        final status = error.response?.statusCode;

        if (status == 502 && attempt < _max502Attempts - 1) {
          final delayMs = 400 * (1 << attempt);
          debugPrint(
            '[AiService] 502 Bad Gateway — retry ${attempt + 1}/'
            '$_max502Attempts after ${delayMs}ms',
          );
          await Future<void>.delayed(Duration(milliseconds: delayMs));
          continue;
        }

        throw _mapDioException(error);
      } catch (error) {
        if (error is AiServiceException) {
          rethrow;
        }
        debugPrint('[AiService] Unexpected error: $error');
        throw const AiServiceException(AiServiceFailureCode.networkError);
      }
    }

    if (lastDioError != null) {
      throw _mapDioException(lastDioError!);
    }

    throw const AiServiceException(AiServiceFailureCode.backendUnavailable);
  }

  void dispose() {
    _httpClient.close();
  }

  Never _mapHttpStatus(int status, Object? body) {
    debugPrint('[AiService] HTTP $status body: $body');
    throw _exceptionForGatewayStatus(status);
  }

  AiServiceException _mapDioException(DioException error) {
    final status = error.response?.statusCode;
    if (status != null && _gatewayStatuses.contains(status)) {
      return _exceptionForGatewayStatus(status);
    }

    if (error.type == DioExceptionType.connectionTimeout ||
        error.type == DioExceptionType.sendTimeout ||
        error.type == DioExceptionType.receiveTimeout ||
        error.type == DioExceptionType.connectionError) {
      debugPrint('[AiService] Network error (${error.type}): ${error.message}');
      return const AiServiceException(AiServiceFailureCode.networkError);
    }

    if (error.type == DioExceptionType.badResponse && status != null) {
      return _exceptionForGatewayStatus(status);
    }

    debugPrint('[AiService] Dio error (${error.type}): ${error.message}');
    return const AiServiceException(AiServiceFailureCode.networkError);
  }

  AiServiceException _exceptionForGatewayStatus(int status) {
    switch (status) {
      case 502:
      case 503:
        return AiServiceException(
          AiServiceFailureCode.serverOverloaded,
          statusCode: status,
        );
      case 504:
        return AiServiceException(
          AiServiceFailureCode.backendUnavailable,
          statusCode: status,
        );
      default:
        if (status >= 500) {
          return AiServiceException(
            AiServiceFailureCode.backendUnavailable,
            statusCode: status,
          );
        }
        return AiServiceException(
          AiServiceFailureCode.invalidResponse,
          statusCode: status,
        );
    }
  }
}
