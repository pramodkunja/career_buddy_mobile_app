import 'package:career_buddy_lms/core/errors/exceptions.dart';
import 'package:career_buddy_lms/core/network/api_client.dart';
import 'package:career_buddy_lms/core/network/api_exceptions_interceptor.dart';
import 'package:career_buddy_lms/features/grammar/data/grammar_media_datasource.dart';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../support/fake_http_client_adapter.dart';

void main() {
  group('GrammarMediaDataSource.fetchIllustrationSvg', () {
    test('returns the raw SVG text on a successful authenticated response', () async {
      const svg = '<svg viewBox="0 0 10 10"><rect width="10" height="10"/></svg>';
      final dio = Dio(BaseOptions(baseUrl: 'https://example.test'))
        ..httpClientAdapter = FakeHttpClientAdapter(statusCode: 200, body: svg);
      final datasource = GrammarMediaDataSource(ApiClient.forTesting(dio));

      expect(await datasource.fetchIllustrationSvg('noun', 1), svg);
    });

    test('requests the exact slug/index URL', () async {
      RequestOptions? captured;
      final dio = Dio(BaseOptions(baseUrl: 'https://example.test'))
        ..httpClientAdapter = FakeHttpClientAdapter(statusCode: 200, body: '<svg></svg>', onRequest: (o) => captured = o);
      final datasource = GrammarMediaDataSource(ApiClient.forTesting(dio));

      await datasource.fetchIllustrationSvg('noun', 2);

      expect(captured!.path, '/subject/illustrations/noun/2.svg');
    });

    test('throws UnauthorizedException on a 401 (matches @login_required on the real endpoint)', () async {
      final dio = Dio(BaseOptions(baseUrl: 'https://example.test'))
        ..interceptors.add(ApiExceptionsInterceptor())
        ..httpClientAdapter = FakeHttpClientAdapter(statusCode: 401, body: '');
      final datasource = GrammarMediaDataSource(ApiClient.forTesting(dio));

      await expectLater(datasource.fetchIllustrationSvg('noun', 1), throwsA(isA<UnauthorizedException>()));
    });
  });
}
