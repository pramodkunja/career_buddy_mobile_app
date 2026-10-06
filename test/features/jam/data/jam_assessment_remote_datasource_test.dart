import 'dart:typed_data';

import 'package:career_buddy_lms/core/errors/exceptions.dart';
import 'package:career_buddy_lms/core/network/api_client.dart';
import 'package:career_buddy_lms/core/network/api_exceptions_interceptor.dart';
import 'package:career_buddy_lms/features/jam/data/jam_remote_datasource.dart';
import 'package:career_buddy_lms/features/jam/domain/entities/jam_assessment.dart';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../support/fake_http_client_adapter.dart';

const _htmlHeaders = {
  'content-type': ['text/html'],
};

// Trimmed fixtures — same anchors real `session.html`/`history.html`/
// `assessment_result.html` markup exposes, mirroring
// `jam_remote_datasource_test.dart`'s existing fixture style.

const _stage1Html = '''
<h1 id="headerTopicTitle">My Family</h1>
<span class="badge-jam badge-jam-easy">easy</span>
<div class="text-xs font-serif font-bold text-slate-400 mt-1" id="labelStage">Stage 1 of 3</div>
<svg><circle id="timerRing" /></svg>
<script>const SESSION_ID = Number("501");</script>
''';

const _stage2Html = '''
<h1 id="headerTopicTitle">Climate Change</h1>
<span class="badge-jam badge-jam-medium">medium</span>
<div class="text-xs font-serif font-bold text-slate-400 mt-1" id="labelStage">Stage 2 of 3</div>
<svg><circle id="timerRing" /></svg>
<script>const SESSION_ID = Number("502");</script>
''';

const _dashboardHtml = '<html><body>redirected to dashboard, no session here</body></html>';

const _assessmentResultHtml = '''
<h1 class="text-4xl md:text-5xl font-bold text-slate-900 font-serif mb-4 leading-tight">Diagnostic Performance Report</h1>
<span class="text-5xl font-bold font-serif text-slate-900 block">61</span>
<div class="text-[10px] font-bold text-slate-400 uppercase tracking-widest mb-2">Easy Stage</div>
<div class="text-sm font-bold font-serif text-slate-900">My Family</div>
<div class="text-xs text-emerald-500 font-bold mt-1">★ 21/25</div>
<div class="text-[10px] font-bold text-slate-400 uppercase tracking-widest mb-2">Medium Stage</div>
<div class="text-sm font-bold font-serif text-slate-900">Climate Change</div>
<div class="text-xs text-amber-500 font-bold mt-1">★ 20/25</div>
<div class="text-[10px] font-bold text-slate-400 uppercase tracking-widest mb-2">Hard Stage</div>
<div class="text-sm font-bold font-serif text-slate-900">AI Ethics</div>
<div class="text-xs text-rose-500 font-bold mt-1">★ 20/25</div>
<div class="prose prose-slate max-w-none font-serif text-slate-700 leading-relaxed jam-feedback-content">
<h4 class='feedback-highlight'><b>🏆 Result Level: Intermediate</b></h4>
<li><b>Average Duration</b>: 48s per topic</li>
<li><b>Average Fluency Consistency</b>: 4.0/5 → <b>Intermediate</b></li>
</div>

<!-- Per-Stage Transcripts accordion -->
''';

const _historyHtml = '''
<div id="content-regular">
  <span class="badge-jam badge-jam-easy">easy</span>
  <span class="badge-jam badge-jam-medium">medium</span>
  <span class="badge-jam badge-jam-hard">hard</span>
</div>
<div id="content-assessments"></div>
''';

class _CapturingHttpClientAdapter implements HttpClientAdapter {
  _CapturingHttpClientAdapter({required this.statusCode, this.body = ''});

  final int statusCode;
  final String body;
  RequestOptions? lastRequest;

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    lastRequest = options;
    return ResponseBody.fromString(body, statusCode, headers: _htmlHeaders);
  }

  @override
  void close({bool force = false}) {}
}

JamRemoteDataSource _dataSource({required int statusCode, required String body}) {
  final dio = Dio(BaseOptions(baseUrl: 'http://test'))
    ..httpClientAdapter = FakeHttpClientAdapter(statusCode: statusCode, body: body, headers: _htmlHeaders)
    ..interceptors.add(ApiExceptionsInterceptor());
  return JamRemoteDataSource(ApiClient.forTesting(dio));
}

void main() {
  group('JamRemoteDataSource.startAssessment', () {
    test('follows the redirect to stage 1 and parses it as an assessment session', () async {
      final ds = _dataSource(statusCode: 200, body: _stage1Html);

      final session = await ds.startAssessment();

      expect(session.sessionId, 501);
      expect(session.topicTitle, 'My Family');
      expect(session.topicDifficulty, 'easy');
      expect(session.stage, 1);
    });

    test('requests the documented start_assessment path', () async {
      final adapter = _CapturingHttpClientAdapter(statusCode: 200, body: _stage1Html);
      final dio = Dio(BaseOptions(baseUrl: 'http://test'))
        ..httpClientAdapter = adapter
        ..interceptors.add(ApiExceptionsInterceptor());
      final ds = JamRemoteDataSource(ApiClient.forTesting(dio));

      await ds.startAssessment();

      expect(adapter.lastRequest!.path, '/jam/assessment/start/');
    });

    test('throws a ValidationException when redirected back to the dashboard (not yet eligible)', () async {
      final ds = _dataSource(statusCode: 200, body: _dashboardHtml);

      await expectLater(ds.startAssessment(), throwsA(isA<ValidationException>()));
    });

    test('a server error maps to a typed AppException via the shared interceptor', () async {
      final ds = _dataSource(statusCode: 500, body: '');
      await expectLater(ds.startAssessment(), throwsA(isA<ServerException>()));
    });
  });

  group('JamRemoteDataSource.completeAssessmentStage', () {
    test('stage 1→2: parses the next stage session as JamAssessmentNextStage', () async {
      final ds = _dataSource(statusCode: 200, body: _stage2Html);

      final outcome = await ds.completeAssessmentStage(501);

      expect(outcome, isA<JamAssessmentNextStage>());
      final next = (outcome as JamAssessmentNextStage).session;
      expect(next.sessionId, 502);
      expect(next.topicTitle, 'Climate Change');
      expect(next.stage, 2);
    });

    test('stage 3 done: parses the final report as JamAssessmentFinished', () async {
      final ds = _dataSource(statusCode: 200, body: _assessmentResultHtml);

      final outcome = await ds.completeAssessmentStage(503);

      expect(outcome, isA<JamAssessmentFinished>());
      final result = (outcome as JamAssessmentFinished).result;
      expect(result.level, 'Intermediate');
      expect(result.totalScore, 61);
      expect(result.stages, hasLength(3));
    });

    test('throws UnexpectedResponseException when the response is neither shape', () async {
      final ds = _dataSource(statusCode: 200, body: '<html><body>huh</body></html>');

      await expectLater(ds.completeAssessmentStage(501), throwsA(isA<UnexpectedResponseException>()));
    });

    test('a server error maps to a typed AppException via the shared interceptor', () async {
      final ds = _dataSource(statusCode: 500, body: '');
      await expectLater(ds.completeAssessmentStage(501), throwsA(isA<ServerException>()));
    });
  });

  group('JamRemoteDataSource.getHistory', () {
    test('parses every regular-session difficulty badge', () async {
      final ds = _dataSource(statusCode: 200, body: _historyHtml);

      final sessions = await ds.getHistory();

      expect(sessions.map((s) => s.difficulty).toSet(), {'easy', 'medium', 'hard'});
    });

    test('a server error maps to a typed AppException via the shared interceptor', () async {
      final ds = _dataSource(statusCode: 500, body: '');
      await expectLater(ds.getHistory(), throwsA(isA<ServerException>()));
    });
  });
}
