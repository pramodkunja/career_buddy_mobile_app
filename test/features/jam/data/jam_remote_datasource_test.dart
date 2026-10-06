import 'dart:io';
import 'dart:typed_data';

import 'package:career_buddy_lms/core/errors/exceptions.dart';
import 'package:career_buddy_lms/core/network/api_client.dart';
import 'package:career_buddy_lms/core/network/api_exceptions_interceptor.dart';
import 'package:career_buddy_lms/features/jam/data/jam_remote_datasource.dart';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../support/fake_http_client_adapter.dart';

const _htmlHeaders = {
  'content-type': ['text/html'],
};
const _jsonHeaders = {
  'content-type': ['application/json'],
};

const _sessionStartHtml = '''
<h1 id="headerTopicTitle">My Family
</h1>
<span class="badge-jam badge-jam-easy">easy</span>
<p id="headerTopicDesc">Talk about your family.</p>
<svg><circle id="timerRing" /></svg>
<script>const SESSION_ID = Number("55");</script>
''';

const _sessionDetailHtml = '''
<div id="resultCard">
  <span class="px-4 py-1.5 bg-white text-slate-400 rounded-full text-[10px] font-bold uppercase tracking-widest border border-slate-100">Feb 10 2026</span>
  <h1 class="text-4xl md:text-5xl font-bold text-slate-900 font-serif mb-4 leading-tight">My Family</h1>
  <span class="px-4 py-1 bg-slate-50 text-slate-500 rounded-full text-xs font-bold font-serif border border-slate-100 capitalize">easy Difficulty</span>
  <span class="px-4 py-1 bg-slate-50 text-slate-500 rounded-full text-xs font-bold font-serif border border-slate-100">30s spoken</span>
  <span class="text-xs font-bold text-slate-400 uppercase tracking-widest">Confidence</span><span class="text-sm font-bold font-serif text-slate-900">3/5</span>
  <span class="text-xs font-bold text-slate-400 uppercase tracking-widest">Fluency</span><span class="text-sm font-bold font-serif text-slate-900">3/5</span>
  <span class="text-xs font-bold text-slate-400 uppercase tracking-widest">Language</span><span class="text-sm font-bold font-serif text-slate-900">3/5</span>
  <span class="text-xs font-bold text-slate-400 uppercase tracking-widest">Pronunciation</span><span class="text-sm font-bold font-serif text-slate-900">3/5</span>
  <span class="text-xs font-bold text-slate-400 uppercase tracking-widest">Time Management</span><span class="text-sm font-bold font-serif text-slate-900">3/5</span>
  <span class="text-5xl font-bold font-serif text-slate-900 block">15</span>
  <div class="prose prose-slate max-w-none font-serif text-slate-700 leading-relaxed jam-feedback-content">Nice work.</div>
  <div class="mt-10 pt-8 border-t border-slate-50">
    <h4 class="text-[10px] font-bold text-slate-400 uppercase tracking-[0.2em] mb-4">Speech Transcript</h4>
    <div class="bg-slate-50/50 rounded-3xl p-6 border border-slate-100 text-sm font-serif text-slate-600 leading-relaxed">My family is great.</div>
  </div>
</div>
''';

const _topicsHtml = '''
<section id="easy">
  <h3 class="font-serif text-2xl font-bold text-slate-900 mb-4 group-hover:text-emerald-600 transition-colors leading-tight">My Family</h3>
  <p class="text-slate-500 font-serif leading-relaxed mb-10 flex-1">Talk about your family.</p>
  <a href="/jam/session/start/1/">Practice Session</a>
</section>
<section id="medium"></section>
<section id="hard"></section>
''';

class _CapturingHttpClientAdapter implements HttpClientAdapter {
  _CapturingHttpClientAdapter({required this.statusCode, this.body = '', this.headers});

  final int statusCode;
  final String body;
  final Map<String, List<String>>? headers;
  RequestOptions? lastRequest;

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    lastRequest = options;
    return ResponseBody.fromString(body, statusCode, headers: headers ?? _jsonHeaders);
  }

  @override
  void close({bool force = false}) {}
}

JamRemoteDataSource _dataSource({required int statusCode, required String body, HttpClientAdapter? adapter, Map<String, List<String>>? headers}) {
  final dio = Dio(BaseOptions(baseUrl: 'http://test'))
    ..httpClientAdapter = adapter ?? FakeHttpClientAdapter(statusCode: statusCode, body: body, headers: headers ?? _jsonHeaders)
    ..interceptors.add(ApiExceptionsInterceptor());
  return JamRemoteDataSource(ApiClient.forTesting(dio));
}

void main() {
  late String audioFilePath;

  setUpAll(() async {
    final file = File('${Directory.systemTemp.path}/jam_datasource_test.m4a');
    await file.writeAsBytes([0, 1, 2, 3]);
    audioFilePath = file.path;
  });

  group('JamRemoteDataSource.getTopics', () {
    test('parses the topics list on a successful response', () async {
      final ds = _dataSource(statusCode: 200, body: _topicsHtml, headers: _htmlHeaders);

      final topics = await ds.getTopics();

      expect(topics, hasLength(1));
      expect(topics.single.title, 'My Family');
      expect(topics.single.difficulty, 'easy');
    });

    test('a server error maps to a typed AppException via the shared interceptor', () async {
      final ds = _dataSource(statusCode: 500, body: '');
      await expectLater(ds.getTopics(), throwsA(isA<ServerException>()));
    });
  });

  group('JamRemoteDataSource.startSession', () {
    test('parses the started session on a successful response', () async {
      final ds = _dataSource(statusCode: 200, body: _sessionStartHtml, headers: _htmlHeaders);

      final session = await ds.startSession();

      expect(session.sessionId, 55);
      expect(session.topicTitle, 'My Family');
      expect(session.topicDifficulty, 'easy');
    });

    test('requests the specific-topic path when topicId is given', () async {
      final adapter = _CapturingHttpClientAdapter(statusCode: 200, body: _sessionStartHtml, headers: _htmlHeaders);
      final ds = _dataSource(statusCode: 200, body: '', adapter: adapter);

      await ds.startSession(topicId: 9);

      expect(adapter.lastRequest!.path, '/jam/session/start/9/');
    });

    test('requests the random-topic path when topicId is null', () async {
      final adapter = _CapturingHttpClientAdapter(statusCode: 200, body: _sessionStartHtml, headers: _htmlHeaders);
      final ds = _dataSource(statusCode: 200, body: '', adapter: adapter);

      await ds.startSession();

      expect(adapter.lastRequest!.path, '/jam/session/start/');
    });

    test('throws a ValidationException when the page is not a real session.html render (no topics available)', () async {
      final ds = _dataSource(statusCode: 200, body: '<html><body>redirected to dashboard</body></html>', headers: _htmlHeaders);

      await expectLater(ds.startSession(), throwsA(isA<ValidationException>()));
    });
  });

  group('JamRemoteDataSource.saveAudio', () {
    test('succeeds on {"status": "ok", ...}', () async {
      final ds = _dataSource(statusCode: 200, body: '{"status": "ok", "session_id": 55}');

      await ds.saveAudio(sessionId: 55, audioFilePath: audioFilePath, durationSeconds: 40, language: 'english');
    });

    test('throws UnexpectedResponseException on an unexpected 200 body shape', () async {
      final ds = _dataSource(statusCode: 200, body: '{"status": "unexpected"}');

      await expectLater(
        ds.saveAudio(sessionId: 55, audioFilePath: audioFilePath, durationSeconds: 40, language: 'english'),
        throwsA(isA<UnexpectedResponseException>()),
      );
    });

    test('a 404 (session not found) maps to NotFoundException via the shared interceptor', () async {
      final ds = _dataSource(statusCode: 404, body: '{"status": "error", "message": "Session not found"}');

      await expectLater(
        ds.saveAudio(sessionId: 999, audioFilePath: audioFilePath, durationSeconds: 40, language: 'english'),
        throwsA(isA<NotFoundException>()),
      );
    });

    test('sends the request as multipart form data with the documented fields, including X-CSRFToken', () async {
      final adapter = _CapturingHttpClientAdapter(statusCode: 200, body: '{"status": "ok", "session_id": 55}');
      final ds = _dataSource(statusCode: 200, body: '', adapter: adapter);

      await ds.saveAudio(sessionId: 55, audioFilePath: audioFilePath, durationSeconds: 42, language: 'vietnam', transcript: '');

      final sent = adapter.lastRequest!.data as FormData;
      final fields = {for (final entry in sent.fields) entry.key: entry.value};
      expect(fields['session_id'], '55');
      expect(fields['duration'], '42');
      expect(fields['transcript'], '');
      expect(fields['language'], 'vietnam');
      expect(sent.files, hasLength(1));
      expect(sent.files.single.key, 'audio');
      expect(adapter.lastRequest!.headers.containsKey('X-CSRFToken'), isTrue);
    });

    test('omits the audio field entirely when no recording file exists', () async {
      final adapter = _CapturingHttpClientAdapter(statusCode: 200, body: '{"status": "ok", "session_id": 55}');
      final ds = _dataSource(statusCode: 200, body: '', adapter: adapter);

      await ds.saveAudio(sessionId: 55, durationSeconds: 42, language: 'english');

      final sent = adapter.lastRequest!.data as FormData;
      expect(sent.files, isEmpty);
    });
  });

  group('JamRemoteDataSource.completeSession', () {
    test('parses the final result HTML (as if followed through the redirect)', () async {
      final ds = _dataSource(statusCode: 200, body: _sessionDetailHtml, headers: _htmlHeaders);

      final result = await ds.completeSession(55);

      expect(result.sessionId, 55);
      expect(result.overallScore, 15);
      expect(result.transcript, 'My family is great.');
    });

    test('throws UnexpectedResponseException when the response is not a real session_detail.html render', () async {
      final ds = _dataSource(statusCode: 200, body: '<html><body>huh</body></html>', headers: _htmlHeaders);

      await expectLater(ds.completeSession(55), throwsA(isA<UnexpectedResponseException>()));
    });

    test('a server error maps to a typed AppException via the shared interceptor', () async {
      final ds = _dataSource(statusCode: 500, body: '');
      await expectLater(ds.completeSession(55), throwsA(isA<ServerException>()));
    });
  });
}
