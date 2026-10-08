import 'dart:typed_data';

import 'package:dio/dio.dart';

/// A minimal [HttpClientAdapter] that always returns one canned response,
/// so datasource/repository tests can exercise the real [Dio] pipeline
/// (including [ApiExceptionsInterceptor]) without a network call.
class FakeHttpClientAdapter implements HttpClientAdapter {
  FakeHttpClientAdapter({required this.statusCode, this.body = '', this.headers, this.onRequest});

  final int statusCode;
  final String body;
  final Map<String, List<String>>? headers;

  /// Lets a test inspect the real outgoing [RequestOptions] (e.g. its
  /// headers) that Dio's pipeline produced, without needing a real network
  /// call.
  final void Function(RequestOptions options)? onRequest;

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    onRequest?.call(options);
    return ResponseBody.fromString(body, statusCode, headers: headers);
  }

  @override
  void close({bool force = false}) {}
}

/// A handful of datasources (`AuthRemoteDataSource.sendOtp`/`register`,
/// `EmployerAuthRemoteDataSource.sendOtp`/`register`,
/// `PasswordResetRemoteDataSource.requestReset`) GET their own page first to
/// prime the `csrftoken` cookie before POSTing — on the real server that GET
/// always returns a plain 200 (it's just the page), only the POST can
/// redirect/error. [FakeHttpClientAdapter] returns one canned response for
/// every request, which would make that priming GET fail too if the test's
/// configured status isn't 2xx — this adapter fixes that by always
/// returning 200 for a GET and only applying the configured status/body to
/// POST (or any other non-GET method).
class GetPrimesCsrfAdapter implements HttpClientAdapter {
  GetPrimesCsrfAdapter({required this.postStatusCode, this.postBody = '', this.onPostRequest});

  final int postStatusCode;
  final String postBody;

  /// Lets a test inspect the real outgoing POST [RequestOptions] (e.g. its
  /// [FormData] fields) without needing a real network call — same purpose
  /// as [FakeHttpClientAdapter.onRequest], just scoped to the POST only
  /// (the priming GET carries no form body worth inspecting).
  final void Function(RequestOptions options)? onPostRequest;

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    if (options.method == 'GET') {
      return ResponseBody.fromString('', 200);
    }
    onPostRequest?.call(options);
    return ResponseBody.fromString(postBody, postStatusCode);
  }

  @override
  void close({bool force = false}) {}
}
