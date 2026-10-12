import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:career_buddy_lms/core/errors/exceptions.dart';
import 'package:career_buddy_lms/core/network/api_client.dart';
import 'package:career_buddy_lms/core/network/api_endpoints.dart';
import 'package:career_buddy_lms/core/network/api_exceptions_interceptor.dart';
import 'package:career_buddy_lms/features/mock_interview/data/datasources/mock_interview_remote_datasource.dart';
import 'package:career_buddy_lms/features/mock_interview/domain/entities/malpractice.dart';
import 'package:career_buddy_lms/features/mock_interview/domain/entities/next_question_outcome.dart';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../support/fake_http_client_adapter.dart';

const _jsonHeaders = {
  'content-type': ['application/json'],
};
const _htmlHeaders = {
  'content-type': ['text/html'],
};

const _sessionPageHtml = '''
<html><body>
<div id="camera-gate-screen" class="camera-gate-screen">Camera Access Required</div>
</body></html>
''';

const _blockedPageHtml = '''
<html><body>
<div class="messages-container">
    <div class="alert alert-info alert-dismissible fade show toast-message" role="alert">
        <i class="fas fa-info-circle me-2"></i>
        AI Mock Interview is available only on Premium plans.
        <button type="button" class="btn-close" data-bs-dismiss="alert"></button>
    </div>
</div>
</body></html>
''';

const _analyticsHtml = '''
<html><body>
<div class="stat-value" style="color:#15803d;">
    72
</div>
<div class="stat-label">Total Score / 100</div>
<div class="badge bg-white bg-opacity-20 text-white mb-2 px-3 py-1 rounded-pill">
    <i class="fas fa-check-circle me-1"></i> Qualified Candidate (Score &ge; 70/100)
</div>
<div class="stat-value text-success">4</div>
<div class="stat-label">Answered</div>
<div class="stat-value">
    5
</div>
<div class="stat-label">Total Questions</div>
<div class="stat-value" style="color:#9d174d;">
    2.5 yrs
</div>
<div class="stat-label">Experience Level</div>
<span class="muted">Overall Score</span>
<span class="fw-bold" style="color:#0ea5e9;">3.6/5</span>
<script id="analytics-data" type="application/json">[{"topic": "Python", "difficulty": "Easy", "question": "What is a list?", "answer": "An ordered collection.", "score": 4, "feedback": "Good answer."}]</script>
<div class="card border-0 rounded-4 shadow-sm p-4 mb-4 bg-white">
  <small class="text-muted">Matched for candidate experience (2.5 years) &amp; verified skills.</small>
  <div class="row g-3">
    <div class="col-md-4">
      <div class="job-card border rounded-3 p-3 h-100">
        <h6 class="fw-bold mb-0 text-truncate" title="Backend Developer">Backend Developer</h6>
        <small class="text-muted">Globex Inc</small>
        <span class="badge bg-light text-dark border">Python</span>
        <span class="badge bg-light text-dark border">Django</span>
        <span class="text-muted"><i class="fas fa-map-marker-alt me-1"></i>Bengaluru</span>
        <span class="badge bg-primary bg-opacity-10 text-primary">Full-time</span>
        <span class="text-muted"><i class="fas fa-briefcase me-1"></i>1-2 years</span>
        <small class="fw-bold text-success"><i class="fas fa-rupee-sign me-1"></i>₹6L - ₹9L</small>
        <a href="/employer/jobs/77/"
            class="btn btn-primary btn-sm w-100 rounded-3 fw-bold" target="_blank">
            View &amp; Apply
        </a>
      </div>
    </div>
  </div>
</div>
</body></html>
''';

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

/// Routes by request path — needed whenever a test wants the CSRF-priming
/// GET (`_ensureCsrfCookie`, fired before every POST call since
/// `ApiClient.forTesting`'s in-memory cookie jar is never actually
/// populated by these fake adapters) to succeed while the POST/GET under
/// test itself returns a specific non-2xx status; [FakeHttpClientAdapter]
/// alone can't express that (it returns one canned response for every URL).
class _RoutedHttpClientAdapter implements HttpClientAdapter {
  _RoutedHttpClientAdapter(this._responses);

  final Map<String, ({int status, String body})> _responses;

  @override
  Future<ResponseBody> fetch(RequestOptions options, Stream<Uint8List>? requestStream, Future<void>? cancelFuture) async {
    final match = _responses[options.path];
    return ResponseBody.fromString(match?.body ?? '', match?.status ?? 200, headers: _jsonHeaders);
  }

  @override
  void close({bool force = false}) {}
}

MockInterviewRemoteDataSource _dataSource({
  required int statusCode,
  required String body,
  Map<String, List<String>> headers = _jsonHeaders,
  HttpClientAdapter? adapter,
}) {
  final dio = Dio(BaseOptions(baseUrl: 'http://test'))
    ..httpClientAdapter = adapter ?? FakeHttpClientAdapter(statusCode: statusCode, body: body, headers: headers)
    ..interceptors.add(ApiExceptionsInterceptor());
  return MockInterviewRemoteDataSource(ApiClient.forTesting(dio));
}

void main() {
  group('MockInterviewRemoteDataSource.startInterview', () {
    test('completes normally when the response lands on the real interview session page', () async {
      final ds = _dataSource(statusCode: 200, body: _sessionPageHtml, headers: _htmlHeaders);
      await ds.startInterview(); // does not throw
    });

    test('throws ValidationException with the flashed message when blocked (e.g. no Premium plan)', () async {
      final ds = _dataSource(statusCode: 200, body: _blockedPageHtml, headers: _htmlHeaders);
      await expectLater(
        ds.startInterview(),
        throwsA(
          isA<ValidationException>().having(
            (e) => e.message,
            'message',
            'AI Mock Interview is available only on Premium plans.',
          ),
        ),
      );
    });
  });

  group('MockInterviewRemoteDataSource.confirmCameraLive', () {
    test('completes normally on {"ok": true}', () async {
      final ds = _dataSource(statusCode: 200, body: jsonEncode({'ok': true}));
      await ds.confirmCameraLive();
    });

    test('sends an X-CSRFToken header', () async {
      final adapter = _CapturingHttpClientAdapter(statusCode: 200, body: jsonEncode({'ok': true}));
      final ds = _dataSource(statusCode: 200, body: '', adapter: adapter);
      await ds.confirmCameraLive();
      expect(adapter.lastRequest!.headers.containsKey('X-CSRFToken'), isTrue);
    });

    test('throws when the server does not confirm', () async {
      final adapter = _RoutedHttpClientAdapter({
        ApiEndpoints.resumeCameraVerified: (status: 400, body: jsonEncode({'error': 'No session'})),
      });
      final ds = _dataSource(statusCode: 200, body: '', adapter: adapter);
      await expectLater(ds.confirmCameraLive(), throwsA(isA<UnexpectedResponseException>()));
    });
  });

  group('MockInterviewRemoteDataSource.getNextQuestion', () {
    test('parses an active question', () async {
      final ds = _dataSource(
        statusCode: 200,
        body: jsonEncode({
          'id': 42,
          'text': 'Tell me about a challenging project.',
          'topic': 'Experience',
          'difficulty': 'Easy',
          'progress': '2/20',
          'status': 'active',
          'is_coding': false,
          'question_type': 'theory',
          'time_limit': 30,
          'time_remaining': 25,
        }),
      );
      final outcome = await ds.getNextQuestion(advance: true);
      final ready = outcome as NextQuestionReady;
      expect(ready.question.id, 42);
      expect(ready.question.topic, 'Experience');
      expect(ready.question.currentNumber, 2);
      expect(ready.question.totalCount, 20);
      expect(ready.question.timeRemainingSeconds, 25);
    });

    test('parses a completed interview', () async {
      final ds = _dataSource(statusCode: 200, body: jsonEncode({'status': 'completed'}));
      final outcome = await ds.getNextQuestion(advance: true);
      expect(outcome, isA<InterviewCompleted>());
    });

    test('throws CameraRequiredException on the camera_required 403 shape', () async {
      final ds = _dataSource(
        statusCode: 403,
        body: jsonEncode({'error': 'camera_required', 'message': 'Camera access is required to attend the interview.'}),
      );
      await expectLater(
        ds.getNextQuestion(advance: false),
        throwsA(isA<CameraRequiredException>().having((e) => e.message, 'message', contains('Camera access'))),
      );
    });

    test('throws MalpracticeTerminatedException on the malpractice_terminated 403 shape', () async {
      final ds = _dataSource(
        statusCode: 403,
        body: jsonEncode({
          'error': 'malpractice_terminated',
          'message': 'This interview was ended due to repeated malpractice violations.',
        }),
      );
      await expectLater(ds.getNextQuestion(advance: false), throwsA(isA<MalpracticeTerminatedException>()));
    });

    test('maps an unrecognized non-200 status to a generic AppException', () async {
      final ds = _dataSource(statusCode: 500, body: '');
      await expectLater(ds.getNextQuestion(advance: false), throwsA(isA<ServerException>()));
    });
  });

  group('MockInterviewRemoteDataSource.submitAnswer', () {
    test('parses score/feedback/timed_out', () async {
      final ds = _dataSource(
        statusCode: 200,
        body: jsonEncode({'score': 4, 'feedback': 'Solid answer.', 'timed_out': false}),
      );
      final result = await ds.submitAnswer(questionId: 42, answerText: 'My answer');
      expect(result.score, 4);
      expect(result.feedback, 'Solid answer.');
      expect(result.timedOut, isFalse);
    });

    test('sends question_id and answer_text as multipart form fields', () async {
      final adapter = _CapturingHttpClientAdapter(
        statusCode: 200,
        body: jsonEncode({'score': 0, 'feedback': '', 'timed_out': false}),
      );
      final ds = _dataSource(statusCode: 200, body: '', adapter: adapter);
      await ds.submitAnswer(questionId: 7, answerText: 'hello world');

      final sent = adapter.lastRequest!.data as FormData;
      final fields = {for (final entry in sent.fields) entry.key: entry.value};
      expect(fields['question_id'], '7');
      expect(fields['answer_text'], 'hello world');
    });

    test('throws MalpracticeTerminatedException on the malpractice_terminated 403 shape', () async {
      final adapter = _RoutedHttpClientAdapter({
        ApiEndpoints.resumeSubmitAnswer: (
          status: 403,
          body: jsonEncode({'error': 'malpractice_terminated', 'message': 'Terminated.'}),
        ),
      });
      final ds = _dataSource(statusCode: 200, body: '', adapter: adapter);
      await expectLater(
        ds.submitAnswer(questionId: 1, answerText: 'x'),
        throwsA(isA<MalpracticeTerminatedException>()),
      );
    });
  });

  group('MockInterviewRemoteDataSource.getViolationState', () {
    test('parses count/status/thresholds', () async {
      final ds = _dataSource(
        statusCode: 200,
        body: jsonEncode({'count': 2, 'status': 'flagged', 'flag_threshold': 3, 'terminate_threshold': 5}),
      );
      final state = await ds.getViolationState();
      expect(state.count, 2);
      expect(state.status, MalpracticeStatus.flagged);
      expect(state.flagThreshold, 3);
      expect(state.terminateThreshold, 5);
    });
  });

  group('MockInterviewRemoteDataSource.recordViolation', () {
    test('parses a warn action', () async {
      final ds = _dataSource(
        statusCode: 200,
        body: jsonEncode({'count': 1, 'status': 'clean', 'action': 'warn', 'type_occurrence_number': 1}),
      );
      final result = await ds.recordViolation(type: ViolationType.tabSwitch);
      expect(result.count, 1);
      expect(result.action, ViolationAction.warn);
      expect(result.typeOccurrenceNumber, 1);
    });

    test('parses the already-terminated shape, which omits type_occurrence_number', () async {
      final ds = _dataSource(
        statusCode: 200,
        body: jsonEncode({'count': 5, 'status': 'terminated', 'action': 'terminated'}),
      );
      final result = await ds.recordViolation(type: ViolationType.windowBlur);
      expect(result.action, ViolationAction.terminated);
      expect(result.typeOccurrenceNumber, isNull);
    });

    test('sends the exact API violation-type string', () async {
      final adapter = _CapturingHttpClientAdapter(
        statusCode: 200,
        body: jsonEncode({'count': 1, 'status': 'clean', 'action': 'warn'}),
      );
      final ds = _dataSource(statusCode: 200, body: '', adapter: adapter);
      await ds.recordViolation(type: ViolationType.tabSwitch);
      final sent = adapter.lastRequest!.data as FormData;
      final fields = {for (final entry in sent.fields) entry.key: entry.value};
      expect(fields['type'], 'TAB_SWITCH');
    });
  });

  group('MockInterviewRemoteDataSource.uploadInterviewVideo', () {
    test('returns true when stored', () async {
      final file = File('${Directory.systemTemp.path}/mock_interview_video_test.mp4');
      await file.writeAsBytes([0, 1, 2, 3]);
      final ds = _dataSource(statusCode: 200, body: jsonEncode({'ok': true, 'stored': true}));
      final stored = await ds.uploadInterviewVideo(file.path);
      expect(stored, isTrue);
    });

    test('returns false when the session did not pass', () async {
      final file = File('${Directory.systemTemp.path}/mock_interview_video_test2.mp4');
      await file.writeAsBytes([0, 1, 2, 3]);
      final ds = _dataSource(statusCode: 200, body: jsonEncode({'ok': true, 'stored': false}));
      final stored = await ds.uploadInterviewVideo(file.path);
      expect(stored, isFalse);
    });
  });

  group('MockInterviewRemoteDataSource.getAnalytics', () {
    test('parses the summary numbers and the embedded per-question JSON', () async {
      final ds = _dataSource(statusCode: 200, body: _analyticsHtml, headers: _htmlHeaders);
      final analytics = await ds.getAnalytics();

      expect(analytics.totalScore, 72);
      expect(analytics.isPassed, isTrue);
      expect(analytics.answeredCount, 4);
      expect(analytics.totalQuestions, 5);
      expect(analytics.yearsExperience, 2.5);
      expect(analytics.avgScore, 3.6);
      expect(analytics.questionResults, hasLength(1));
      expect(analytics.questionResults.single.topic, 'Python');
      expect(analytics.questionResults.single.score, 4);

      // REGRESSION (Phase 8): `suitable_jobs` — same `_get_matched_jobs`
      // source and per-job fields as the dashboard's recommended jobs,
      // reusing the same `RecommendedJob` entity.
      expect(analytics.suitableJobs, hasLength(1));
      expect(analytics.suitableJobs.single.title, 'Backend Developer');
      expect(analytics.suitableJobs.single.companyName, 'Globex Inc');
      expect(analytics.suitableJobs.single.skills, ['Python', 'Django']);
      expect(analytics.suitableJobs.single.location, 'Bengaluru');
      expect(analytics.suitableJobs.single.jobType, 'Full-time');
      expect(analytics.suitableJobs.single.experienceLevel, '1-2 years');
      expect(analytics.suitableJobs.single.salaryDisplay, '₹6L - ₹9L');
      // `job.pk` — scraped from the card's own "View & Apply" link
      // (`resume_analytics.html:406`), the same stable id
      // `employer_portal:job_detail`/`PublicJobDetailScreen` already uses.
      expect(analytics.suitableJobs.single.id, 77);
    });

    test('throws NotFoundException when no completed session exists', () async {
      final ds = _dataSource(statusCode: 200, body: '<html><body>No analysis available.</body></html>', headers: _htmlHeaders);
      await expectLater(ds.getAnalytics(), throwsA(isA<NotFoundException>()));
    });

    group('REGRESSION (Phase 8) — suitable_jobs', () {
      test('a response missing the suitable_jobs card entirely (web\'s own {% if %} being false) parses as empty, not an error', () async {
        final withoutJobsSection = _analyticsHtml.replaceAll(
          RegExp(r'<div class="card border-0 rounded-4 shadow-sm p-4 mb-4 bg-white">[\s\S]*?</div>\s*</div>\s*</div>'),
          '',
        );
        final ds = _dataSource(statusCode: 200, body: withoutJobsSection, headers: _htmlHeaders);
        final analytics = await ds.getAnalytics();

        expect(analytics.suitableJobs, isEmpty);
        // Confirms the strip above didn't accidentally eat the still-expected
        // summary/question-breakdown sections too.
        expect(analytics.totalScore, 72);
        expect(analytics.questionResults, hasLength(1));
      });

      test('a job card whose link markup has drifted still parses every other real field, with a null id rather than a crash or a fabricated one', () async {
        final withoutJobLink = _analyticsHtml.replaceAll(RegExp(r'<a href="/employer/jobs/77/"[\s\S]*?</a>'), '');
        final ds = _dataSource(statusCode: 200, body: withoutJobLink, headers: _htmlHeaders);
        final analytics = await ds.getAnalytics();

        expect(analytics.suitableJobs, hasLength(1));
        expect(analytics.suitableJobs.single.title, 'Backend Developer');
        expect(analytics.suitableJobs.single.id, isNull);
      });

      test('multiple suitable jobs all parse, in document order', () async {
        // Appended after the first card rather than re-nested inside
        // `row g-3`'s own closing tag: the parser splits on the `job-card`
        // marker and never relies on true DOM nesting, so document order is
        // the only thing this test needs to control.
        const secondCard = '''
<div class="job-card border rounded-3 p-3 h-100">
  <h6 class="fw-bold mb-0 text-truncate" title="QA Engineer">QA Engineer</h6>
  <small class="text-muted">Initech</small>
  <span class="badge bg-light text-dark border">Selenium</span>
  <span class="text-muted"><i class="fas fa-map-marker-alt me-1"></i>Pune</span>
  <span class="badge bg-primary bg-opacity-10 text-primary">Full-time</span>
  <span class="text-muted"><i class="fas fa-briefcase me-1"></i>0-1 years</span>
  <small class="fw-bold text-success"><i class="fas fa-rupee-sign me-1"></i>₹4L - ₹5L</small>
  <a href="/employer/jobs/88/" class="btn btn-primary btn-sm w-100 rounded-3 fw-bold" target="_blank">View &amp; Apply</a>
</div>
''';
        final twoJobs = _analyticsHtml.replaceFirst('</body></html>', '$secondCard</body></html>');
        final ds = _dataSource(statusCode: 200, body: twoJobs, headers: _htmlHeaders);
        final analytics = await ds.getAnalytics();

        expect(analytics.suitableJobs, hasLength(2));
        expect(analytics.suitableJobs[0].title, 'Backend Developer');
        expect(analytics.suitableJobs[1].title, 'QA Engineer');
        expect(analytics.suitableJobs[1].id, 88);
      });

      test('malformed/unrecognized job-card markup produces no fabricated job', () async {
        final malformed = _analyticsHtml.replaceAll(
          '<h6 class="fw-bold mb-0 text-truncate" title="Backend Developer">Backend Developer</h6>',
          '<h6 class="some-other-class">Backend Developer</h6>',
        );
        final ds = _dataSource(statusCode: 200, body: malformed, headers: _htmlHeaders);
        final analytics = await ds.getAnalytics();

        expect(analytics.suitableJobs, isEmpty);
      });
    });
  });
}
