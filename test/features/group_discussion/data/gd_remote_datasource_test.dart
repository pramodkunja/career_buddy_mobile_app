import 'dart:typed_data';

import 'package:career_buddy_lms/core/errors/exceptions.dart';
import 'package:career_buddy_lms/core/network/api_client.dart';
import 'package:career_buddy_lms/core/network/api_exceptions_interceptor.dart';
import 'package:career_buddy_lms/features/group_discussion/data/gd_remote_datasource.dart';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';

const _htmlHeaders = {
  'content-type': ['text/html'],
};
const _jsonHeaders = {
  'content-type': ['application/json'],
};

/// Returns one canned [Response] per call, in order — `createSession` makes
/// 2 requests (a GET to prime CSRF, then the POST itself), so a single
/// fixed-response fake isn't enough for that flow.
class _SequencedAdapter implements HttpClientAdapter {
  _SequencedAdapter(this.responses);

  final List<({int statusCode, String body, Map<String, List<String>>? headers})> responses;
  final List<RequestOptions> requests = [];
  int _index = 0;

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    requests.add(options);
    final response = responses[_index.clamp(0, responses.length - 1)];
    _index++;
    return ResponseBody.fromString(response.body, response.statusCode, headers: response.headers ?? _jsonHeaders);
  }

  @override
  void close({bool force = false}) {}
}

GdRemoteDataSource _dataSource(_SequencedAdapter adapter) {
  final dio = Dio(BaseOptions(baseUrl: 'http://test'))
    ..httpClientAdapter = adapter
    ..interceptors.add(ApiExceptionsInterceptor());
  return GdRemoteDataSource(ApiClient.forTesting(dio));
}

const _reportHtml = '''
<div class="score-ring-wrap">
  <div style="font-size:3rem;font-weight:900;color:#1e293b;line-height:1;">72</div>
</div>
<div class="dim-card"><div class="dim-score text-primary">20<span>/25</span></div><div class="dim-feedback">Good pace.</div></div>
<div class="dim-card"><div class="dim-score" style="color:#7c3aed;">15<span>/25</span></div><div class="dim-feedback">Some errors.</div></div>
<div class="dim-card"><div class="dim-score text-success">22<span>/25</span></div><div class="dim-feedback">Stayed on topic.</div></div>
<div class="dim-card"><div class="dim-score" style="color:#d97706;">15<span>/25</span></div><div class="dim-feedback">Hesitant at times.</div></div>
<div class="insight-card insight-dark">
  <p style="color:#94a3b8;margin:0;font-size:.88rem;line-height:1.5;">Clear points</p>
  <p style="color:#94a3b8;margin:0;font-size:.88rem;line-height:1.5;">Good listening</p>
</div>
<div class="insight-card insight-light">
  <p class="text-muted mb-0" style="font-size:.88rem;line-height:1.5;">Work on grammar</p>
</div>
<div class="verdict-quote">"A solid contribution overall."</div>
''';

void main() {
  group('GdRemoteDataSource.createSession', () {
    test('parses the new session id out of the Location header on success', () async {
      final adapter = _SequencedAdapter([
        (statusCode: 200, body: '', headers: _htmlHeaders),
        (
          statusCode: 302,
          body: '',
          headers: {
            'location': ['/gd/room/42/'],
          },
        ),
      ]);
      final ds = _dataSource(adapter);

      final session = await ds.createSession('AI will replace human jobs');

      expect(session.sessionId, 42);
      expect(session.topic, 'AI will replace human jobs');
    });

    test('sends the topic form-encoded with an X-CSRFToken header', () async {
      final adapter = _SequencedAdapter([
        (statusCode: 200, body: '', headers: _htmlHeaders),
        (
          statusCode: 302,
          body: '',
          headers: {
            'location': ['/gd/room/7/'],
          },
        ),
      ]);
      final ds = _dataSource(adapter);

      await ds.createSession('Work from home vs office');

      final postRequest = adapter.requests[1];
      expect(postRequest.path, '/gd/create/');
      expect(postRequest.data, isA<Map<String, dynamic>>());
      expect((postRequest.data as Map)['topic'], 'Work from home vs office');
      expect(postRequest.headers.containsKey('X-CSRFToken'), isTrue);
    });

    test('throws ForbiddenException when the redirect lands on the locked activities page', () async {
      final adapter = _SequencedAdapter([
        (statusCode: 200, body: '', headers: _htmlHeaders),
        (
          statusCode: 302,
          body: '',
          headers: {
            'location': ['/activities/?locked=1'],
          },
        ),
      ]);
      final ds = _dataSource(adapter);

      await expectLater(ds.createSession('Any topic'), throwsA(isA<ForbiddenException>()));
    });

    test('throws UnexpectedResponseException for a 200 (non-redirect) response', () async {
      final adapter = _SequencedAdapter([
        (statusCode: 200, body: '', headers: _htmlHeaders),
        (statusCode: 200, body: '<html></html>', headers: _htmlHeaders),
      ]);
      final ds = _dataSource(adapter);

      await expectLater(ds.createSession('Any topic'), throwsA(isA<UnexpectedResponseException>()));
    });

    test('a server error maps to a typed AppException via the shared interceptor', () async {
      final adapter = _SequencedAdapter([
        (statusCode: 200, body: '', headers: _htmlHeaders),
        (statusCode: 500, body: '', headers: null),
      ]);
      final ds = _dataSource(adapter);

      await expectLater(ds.createSession('Any topic'), throwsA(isA<ServerException>()));
    });
  });

  group('GdRemoteDataSource.getSessions', () {
    test('parses the sessions list from api_sessions', () async {
      final adapter = _SequencedAdapter([
        (
          statusCode: 200,
          body: '{"sessions": [{"id": 1, "topic": "AI jobs", "created_at": "2026-01-01T00:00:00Z", "is_active": false}]}',
          headers: _jsonHeaders,
        ),
      ]);
      final ds = _dataSource(adapter);

      final sessions = await ds.getSessions();

      expect(sessions, hasLength(1));
      expect(sessions.single.id, 1);
      expect(sessions.single.topic, 'AI jobs');
      expect(sessions.single.isActive, isFalse);
    });

    test('a server error maps to a typed AppException via the shared interceptor', () async {
      final adapter = _SequencedAdapter([(statusCode: 500, body: '', headers: null)]);
      final ds = _dataSource(adapter);

      await expectLater(ds.getSessions(), throwsA(isA<ServerException>()));
    });
  });

  group('GdRemoteDataSource.getSessionReport', () {
    test('parses the report fields from a rendered report.html', () async {
      final adapter = _SequencedAdapter([(statusCode: 200, body: _reportHtml, headers: _htmlHeaders)]);
      final ds = _dataSource(adapter);

      final report = await ds.getSessionReport(42);

      expect(report, isNotNull);
      expect(report!.overallScore, 72);
      expect(report.fluency.score, 20);
      expect(report.fluency.feedback, 'Good pace.');
      expect(report.grammar.score, 15);
      expect(report.relevance.score, 22);
      expect(report.confidence.score, 15);
      expect(report.strengths, ['Clear points', 'Good listening']);
      expect(report.improvements, ['Work on grammar']);
      expect(report.summary, 'A solid contribution overall.');
    });

    test('returns null for a session with no report yet', () async {
      final adapter = _SequencedAdapter([
        (statusCode: 200, body: '<div class="text-center">No analysis yet</div>', headers: _htmlHeaders),
      ]);
      final ds = _dataSource(adapter);

      final report = await ds.getSessionReport(42);

      expect(report, isNull);
    });
  });
}
