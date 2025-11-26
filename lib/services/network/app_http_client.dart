import 'package:dio/dio.dart';
import 'package:dio_smart_retry/dio_smart_retry.dart';
import 'package:flutter/foundation.dart';

/// Shared Dio wrapper with sensible defaults, retry logic, and debug logging.
class AppHttpClient {
  AppHttpClient({
    Dio? dio,
    Duration? connectTimeout,
    Duration? receiveTimeout,
    Duration? sendTimeout,
  })  : _dio = dio ??
            _createDio(
              connectTimeout: connectTimeout,
              receiveTimeout: receiveTimeout,
              sendTimeout: sendTimeout,
            ),
        _ownsClient = dio == null;

  final Dio _dio;
  final bool _ownsClient;

  Dio get dio => _dio;

  void close() {
    if (_ownsClient) {
      _dio.close(force: true);
    }
  }

  static Dio _createDio({
    Duration? connectTimeout,
    Duration? receiveTimeout,
    Duration? sendTimeout,
  }) {
    final dio = Dio(
      BaseOptions(
        connectTimeout: connectTimeout ?? const Duration(seconds: 10),
        receiveTimeout: receiveTimeout ?? const Duration(seconds: 10),
        sendTimeout: sendTimeout ?? const Duration(seconds: 10),
        responseType: ResponseType.json,
        contentType: Headers.jsonContentType,
        followRedirects: true,
        validateStatus: (status) =>
            status != null && status >= 200 && status < 500,
      ),
    );

    dio.interceptors.add(
      RetryInterceptor(
        dio: dio,
        retries: 2,
        retryDelays: const [
          Duration(milliseconds: 300),
          Duration(milliseconds: 700),
        ],
        logPrint: (message) => debugPrint('[HTTP retry] $message'),
        retryEvaluator: (error, attempt) {
          if (error.type == DioExceptionType.cancel) {
            return false;
          }
          if (error.type == DioExceptionType.badResponse) {
            final status = error.response?.statusCode ?? 0;
            return status >= 500 || status == 408;
          }
          return true;
        },
      ),
    );

    if (kDebugMode) {
      dio.interceptors.add(
        LogInterceptor(
          requestBody: true,
          responseBody: true,
          logPrint: (line) => debugPrint('[HTTP] $line'),
        ),
      );
    }

    return dio;
  }
}

