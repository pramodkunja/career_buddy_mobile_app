import 'dart:convert';
import 'dart:typed_data';

import 'package:career_buddy_lms/core/errors/exceptions.dart';
import 'package:career_buddy_lms/core/network/api_client.dart';
import 'package:career_buddy_lms/core/network/api_exceptions_interceptor.dart';
import 'package:career_buddy_lms/features/mock_tests/amcat/data/datasources/amcat_remote_datasource.dart';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../../support/fake_http_client_adapter.dart';

const _jsonHeaders = {
  'content-type': ['application/json'],
};

class _CapturingHttpClientAdapter implements HttpClientAdapter {
  _CapturingHttpClientAdapter({required this.statusCode, this.body = ''});

  final int statusCode;
  final String body;
  RequestOptions? lastRequest;

  @override
  Future<ResponseBody> fetch(RequestOptions options, Stream<Uint8List>? requestStream, Future<void>? cancelFuture) async {
    lastRequest = options;
    return ResponseBody.fromString(body, statusCode, headers: _jsonHeaders);
  }

  @override
  void close({bool force = false}) {}
}

AmcatRemoteDataSource _dataSourceReturning({required int statusCode, required String body, HttpClientAdapter? adapter}) {
  final dio = Dio(BaseOptions(baseUrl: 'http://test'))
    ..httpClientAdapter = adapter ?? FakeHttpClientAdapter(statusCode: statusCode, body: body, headers: _jsonHeaders)
    ..interceptors.add(ApiExceptionsInterceptor());
  return AmcatRemoteDataSource(
    ApiClient.forTesting(dio),
    questionsPath: '/activities/amcat/questions/',
    submitPath: '/activities/amcat/submit/',
  );
}

void main() {
  group('AmcatRemoteDataSource.getSections', () {
    test('parses all 5 sections on a valid response', () async {
      final ds = _dataSourceReturning(
        statusCode: 200,
        body: jsonEncode({
          'sections': [
            {'key': 'quant', 'name': 'Quantitative Ability', 'timeSec': 1080, 'type': 'mcq', 'questions': <Map<String, dynamic>>[]},
          ],
        }),
      );

      final sections = await ds.getSections();

      expect(sections, hasLength(1));
      expect(sections.single.key, 'quant');
    });

    test('throws UnexpectedResponseException when the body is not a JSON object', () async {
      final ds = _dataSourceReturning(statusCode: 200, body: '"just a string"');
      await expectLater(ds.getSections(), throwsA(isA<UnexpectedResponseException>()));
    });

    test('a server error maps to a typed AppException via the shared interceptor', () async {
      final ds = _dataSourceReturning(statusCode: 500, body: '');
      await expectLater(ds.getSections(), throwsA(isA<ServerException>()));
    });
  });

  group('AmcatRemoteDataSource.submit', () {
    test('parses score/total/sections/results on a valid response', () async {
      final ds = _dataSourceReturning(
        statusCode: 200,
        body: jsonEncode({'score': 10, 'total': 153, 'sections': <String, dynamic>{}, 'results': <String, dynamic>{}}),
      );

      final result = await ds.submit({1: 0});

      expect(result.score, 10);
      expect(result.total, 153);
    });

    test('sends no X-CSRFToken header — amcat_submit is @csrf_exempt', () async {
      final adapter = _CapturingHttpClientAdapter(
        statusCode: 200,
        body: jsonEncode({'score': 0, 'total': 1, 'sections': <String, dynamic>{}, 'results': <String, dynamic>{}}),
      );
      final ds = _dataSourceReturning(statusCode: 200, body: '', adapter: adapter);

      await ds.submit({1: -1});

      expect(adapter.lastRequest, isNotNull);
      expect(adapter.lastRequest!.headers.containsKey('X-CSRFToken'), isFalse);
    });
  });
}
