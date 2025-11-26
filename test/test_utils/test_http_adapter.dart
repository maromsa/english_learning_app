import 'package:dio/dio.dart';

typedef DioRequestHandler = Future<ResponseBody> Function(
  RequestOptions options,
  Stream<List<int>>? requestStream,
);

class TestHttpClientAdapter implements HttpClientAdapter {
  TestHttpClientAdapter(this._handler);

  final DioRequestHandler _handler;

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<List<int>>? requestStream,
    Future<void>? cancelFuture,
  ) {
    return _handler(options, requestStream);
  }

  @override
  void close({bool force = false}) {}
}
