import 'package:career_buddy_lms/core/errors/exceptions.dart';
import 'package:career_buddy_lms/core/media/protected_media_remote_datasource.dart';
import 'package:career_buddy_lms/core/network/api_client.dart';
import 'package:career_buddy_lms/core/network/api_exceptions_interceptor.dart';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../support/fake_http_client_adapter.dart';

Dio _dio(int statusCode, {String body = ''}) {
  return Dio(BaseOptions(baseUrl: 'https://example.test'))
    ..interceptors.add(ApiExceptionsInterceptor())
    ..httpClientAdapter = FakeHttpClientAdapter(statusCode: statusCode, body: body);
}

void main() {
  group('ProtectedMediaRemoteDataSource.downloadBytes', () {
    test('returns the raw bytes on a successful authenticated response', () async {
      final datasource = ProtectedMediaRemoteDataSource(ApiClient.forTesting(_dio(200, body: '%PDF-fake-bytes')));

      final bytes = await datasource.downloadBytes('/media/resumes/x.pdf');

      expect(bytes, isNotEmpty);
      expect(String.fromCharCodes(bytes), '%PDF-fake-bytes');
    });

    test('throws UnauthorizedException on a 401 (expired/missing session)', () async {
      final datasource = ProtectedMediaRemoteDataSource(ApiClient.forTesting(_dio(401)));

      await expectLater(datasource.downloadBytes('/media/resumes/x.pdf'), throwsA(isA<UnauthorizedException>()));
    });

    test('throws ForbiddenException on a 403 (not this user\'s file)', () async {
      final datasource = ProtectedMediaRemoteDataSource(ApiClient.forTesting(_dio(403)));

      await expectLater(datasource.downloadBytes('/media/resumes/x.pdf'), throwsA(isA<ForbiddenException>()));
    });

    test('throws ServerException on a 5xx', () async {
      final datasource = ProtectedMediaRemoteDataSource(ApiClient.forTesting(_dio(500)));

      await expectLater(datasource.downloadBytes('/media/resumes/x.pdf'), throwsA(isA<ServerException>()));
    });
  });
}
