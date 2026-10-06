import 'package:career_buddy_lms/core/errors/exceptions.dart';
import 'package:career_buddy_lms/core/network/api_client.dart';
import 'package:career_buddy_lms/core/network/api_exceptions_interceptor.dart';
import 'package:career_buddy_lms/features/activities/data/datasources/activities_remote_datasource.dart';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../support/fake_http_client_adapter.dart';

const _htmlHeaders = {
  'content-type': ['text/html'],
};

/// Mirrors `activities_html_parser.dart`'s own title-hash synthetic-id
/// formula exactly, so these tests assert against the same value the
/// production parser actually computes for "Group Discussion" — not a
/// hardcoded magic number that silently drifts if that formula ever
/// changes.
int _syntheticIdFor(String title) => -(title.hashCode.abs() % 1000000 + 1);

/// Trimmed but structurally faithful slices of the real templates — every
/// marker the parser anchors on is present, read directly from
/// `templates/activities/list.html`/`detail.html`/`sub_activity.html`
/// rather than invented.
const _validListHtml = '''
<div class="activities-page">
  <div class="module-grid">
    <a href="/activities/" class="module-card mod-all mod-active"><div class="mod-icon"><i class="fas fa-border-all"></i></div><span class="mod-label">All</span></a>
    <a href="/activities/?category=speaking" class="module-card mod-speaking"><div class="mod-icon"><i class="fas fa-microphone"></i></div><span class="mod-label">Speaking</span></a>
  </div>
  <div class="row g-4">
    <div class="activity-card ">
      <h5 class="activity-title">Business Vocabulary Building Games</h5>
      <p class="activity-objective">Build core business vocabulary.</p>
      <span class="badge-level">Intermediate</span>
      <span class="badge-category" title="Vocabulary &amp; Idioms"><i class="fas fa-puzzle-piece"></i></span>
      <small class="fw-semibold text-primary">40%</small>
      <a href="/activities/12/" class="btn btn-primary w-100">Continue</a>
    </div>
    <div class="activity-card activity-card-locked">
      <h5 class="activity-title">Locked Activity</h5>
      <p class="activity-objective">Not available on the Free Plan.</p>
      <span class="badge-level">Advanced</span>
      <span class="badge-category" title="Writing"><i class="fas fa-pen"></i></span>
      <button type="button" class="btn btn-secondary w-100 js-locked-activity">Locked</button>
    </div>
    <div class="activity-card ">
      <h5 class="activity-title">Group Discussion</h5>
      <p class="activity-objective">Interactive workshop.</p>
      <span class="badge-level">All Levels</span>
      <span class="badge-category" title="Workshop"><i class="fas fa-chalkboard-teacher"></i></span>
      <a href="/gd/" class="btn btn-primary w-100">Start Activity</a>
    </div>
  </div>
</div>
''';

const _validDetailHtml = '''
<div class="activity-detail-page">
  <h1 class="activity-hero-title">Business Vocabulary Building Games</h1>
  <p class="activity-hero-objective">Build core business vocabulary.</p>
  <span><i class="fas fa-signal me-2"></i>Intermediate</span>
  <span><i class="fas fa-clock me-2"></i>30 min</span>
  <div class="hero-progress-ring mt-3"><div class="ring-value">40%</div></div>
  <div class="sub-activity-card ">
    <h5 class="sub-title">Common Business Terms</h5>
    <span class="sub-status-badge status-in_progress">In Progress</span>
    <i class="fas fa-gamepad me-1"></i>3 Exercises
    <p class="sub-description">An overview of common business vocabulary.</p>
    <a href="/activities/12/sub/34/">Continue</a>
  </div>
</div>
''';

const _validSubDetailHtml = '''
<div class="sub-activity-hero bg-indigo">
  <nav><ol class="breadcrumb"><li class="breadcrumb-item"><a href="/activities/12/">Business Vocabulary Building Games</a></li><li class="breadcrumb-item active">Common Business Terms</li></ol></nav>
  <div class="text-white-50 small">Sub-Activity 1 of 5</div>
  <h2 class="text-white mb-0">Common Business Terms</h2>
  <span class="badge bg-warning text-dark px-3 py-2"><i class="fas fa-spinner me-1"></i>In Progress</span>
</div>
<span id="descOverview">An overview of common business vocabulary.</span>
<div class="instructions-text" id="instructionsBox"><p>Read each term before starting.</p></div>
<div class="exercise-card">
  <div class="exercise-type-icon exercise-mcq"></div>
  <div class="exercise-type-label">Multiple Choice</div>
  <h6 class="exercise-title">Vocabulary Quiz</h6>
  <a href="/activities/exercise/501/" class="btn btn-primary btn-sm">Start</a>
</div>
<form method="post" action="/activities/sub/34/complete/"><button type="submit">Mark Complete</button></form>
''';

const _loginRedirectHtml = '''
<html><body><form id="login-form"><input name="username"></form></body></html>
''';

/// Dio header values are read case-insensitively, but a fake response body
/// needs the exact key `ApiClient`'s underlying `HttpHeaders` normalizes to
/// — `location` (lowercase) matches what `response.headers.value('location')`
/// reads back regardless of how the real server capitalizes it.
Map<String, List<String>> _redirectTo(String location) => {
  'location': [location],
};

ApiClient _clientReturning({required int statusCode, required String body, Map<String, List<String>>? headers}) {
  final dio = Dio(BaseOptions(baseUrl: 'http://test'))
    ..httpClientAdapter = FakeHttpClientAdapter(statusCode: statusCode, body: body, headers: headers)
    ..interceptors.add(ApiExceptionsInterceptor());
  return ApiClient.forTesting(dio);
}

/// Returns [listBody] for any `GET /activities/` and [detailBody]/[detailStatusCode]
/// for anything else — used for `getActivityDetail`'s redirect-then-list-
/// fallback path, which makes a second real request this session's other
/// fixed-response fake can't represent.
class _PathRoutingAdapter implements HttpClientAdapter {
  _PathRoutingAdapter({required this.listBody, required this.detailStatusCode, this.detailHeaders});

  final String listBody;
  final int detailStatusCode;
  final Map<String, List<String>>? detailHeaders;

  @override
  Future<ResponseBody> fetch(RequestOptions options, Stream<List<int>>? requestStream, Future<void>? cancelFuture) async {
    if (options.path == '/activities/') {
      return ResponseBody.fromString(listBody, 200, headers: _htmlHeaders);
    }
    return ResponseBody.fromString('', detailStatusCode, headers: detailHeaders);
  }

  @override
  void close({bool force = false}) {}
}

void main() {
  group('ActivitiesRemoteDataSource.getActivityList', () {
    test('parses a valid 200 HTML response', () async {
      final client = _clientReturning(statusCode: 200, body: _validListHtml, headers: _htmlHeaders);
      final data = await ActivitiesRemoteDataSource(client).getActivityList();

      expect(data.activities, hasLength(3));
      expect(data.activities[0].id, 12);
      expect(data.activities[0].title, 'Business Vocabulary Building Games');
      expect(data.activities[0].category, 'vocabulary');
      expect(data.activities[0].categoryDisplay, 'Vocabulary & Idioms');
      expect(data.activities[0].completionRate, 40);
      expect(data.activities[0].isLocked, isFalse);

      expect(data.activities[1].title, 'Locked Activity');
      expect(data.activities[1].isLocked, isTrue);

      // No real activity pk in its href (`direct_url` to `/gd/`) — gets a
      // synthetic negative id rather than being dropped, so it still shows
      // up in the browsable list.
      expect(data.activities[2].title, 'Group Discussion');
      expect(data.activities[2].category, 'workshop');
      expect(data.activities[2].id, lessThan(0));

      expect(data.categories, hasLength(1));
      expect(data.categories.single.value, 'speaking');
      expect(data.selectedCategory, '');
    });

    test('a login-redirect page (session expired) throws UnauthorizedException', () async {
      final client = _clientReturning(statusCode: 200, body: _loginRedirectHtml, headers: _htmlHeaders);
      expect(() => ActivitiesRemoteDataSource(client).getActivityList(), throwsA(isA<UnauthorizedException>()));
    });

    test('a non-200 status maps through the existing exception mapper', () async {
      final client = _clientReturning(statusCode: 500, body: '');
      expect(() => ActivitiesRemoteDataSource(client).getActivityList(), throwsA(isA<ServerException>()));
    });

    test(
      'a workshop/module activity\'s synthetic id is the same regardless of its position in the parsed page '
      '(e.g. a category-filtered view vs. the unfiltered "All" list)',
      () async {
        // Confirmed live as a real, reproducible bug: a *position*-based
        // synthetic id (the activity's index in whichever specific page
        // variant was parsed) only matches when `_activityDetailFallback`
        // happens to re-fetch that exact same variant. It re-fetches the
        // plain, unfiltered list — so an id computed while the user was
        // viewing a category-filtered page (where this card could be at a
        // different position) never matched, and the detail screen 404'd
        // ("We couldn't find what you were looking for") for every
        // workshop/module activity reached through a category filter. A
        // title-derived id must be identical no matter where the card
        // appears.
        const reorderedAsFirstCard = '''
<div class="activities-page">
  <div class="row g-4">
    <div class="activity-card ">
      <h5 class="activity-title">Group Discussion</h5>
      <p class="activity-objective">Interactive workshop.</p>
      <span class="badge-level">All Levels</span>
      <span class="badge-category" title="Workshop"><i class="fas fa-chalkboard-teacher"></i></span>
      <a href="/gd/" class="btn btn-primary w-100">Start Activity</a>
    </div>
  </div>
</div>
''';

        final unfiltered = await ActivitiesRemoteDataSource(
          _clientReturning(statusCode: 200, body: _validListHtml, headers: _htmlHeaders),
        ).getActivityList();
        final filtered = await ActivitiesRemoteDataSource(
          _clientReturning(statusCode: 200, body: reorderedAsFirstCard, headers: _htmlHeaders),
        ).getActivityList();

        final idInUnfilteredList = unfiltered.activities.firstWhere((a) => a.title == 'Group Discussion').id;
        final idInFilteredList = filtered.activities.single.id;

        expect(idInFilteredList, idInUnfilteredList);
        expect(idInUnfilteredList, _syntheticIdFor('Group Discussion'));
      },
    );
  });

  group('ActivitiesRemoteDataSource.getActivityDetail', () {
    test('parses a valid 200 HTML response for a normal (non-workshop, non-module) activity', () async {
      final client = _clientReturning(statusCode: 200, body: _validDetailHtml, headers: _htmlHeaders);
      final detail = await ActivitiesRemoteDataSource(client).getActivityDetail(12);

      expect(detail.title, 'Business Vocabulary Building Games');
      expect(detail.level, 'Intermediate');
      expect(detail.duration, '30 min');
      expect(detail.completionRate, 40);
      expect(detail.isWorkshop, isFalse);
      expect(detail.isModule, isFalse);
      expect(detail.subActivities, hasLength(1));
      expect(detail.subActivities.single.id, 34);
      expect(detail.subActivities.single.title, 'Common Business Terms');
      expect(detail.subActivities.single.status.name, 'inProgress');
    });

    test('a redirect to the login page throws UnauthorizedException', () async {
      final client = _clientReturning(statusCode: 302, body: '', headers: _redirectTo('/users/login/?next=/activities/12/'));
      expect(() => ActivitiesRemoteDataSource(client).getActivityDetail(12), throwsA(isA<UnauthorizedException>()));
    });

    test('a redirect to the locked-upgrade page throws ForbiddenException with the real view\'s message', () async {
      final client = _clientReturning(statusCode: 302, body: '', headers: _redirectTo('/activities/?locked=1'));
      await expectLater(
        ActivitiesRemoteDataSource(client).getActivityDetail(12),
        throwsA(isA<ForbiddenException>().having((e) => e.message, 'message', 'This activity requires an upgrade to access.')),
      );
    });

    test(
      'a negative id (a workshop/AI-module activity with no real detail page) falls back to the list page\'s own data',
      () async {
        final client = ApiClient.forTesting(
          Dio(BaseOptions(baseUrl: 'http://test'))
            ..httpClientAdapter = _PathRoutingAdapter(listBody: _validListHtml, detailStatusCode: 404)
            ..interceptors.add(ApiExceptionsInterceptor()),
        );

        final detail = await ActivitiesRemoteDataSource(client).getActivityDetail(_syntheticIdFor('Group Discussion'));

        expect(detail.title, 'Group Discussion');
        expect(detail.isWorkshop, isTrue);
        expect(detail.subActivities, isEmpty);
      },
    );

    test('a positive id that also redirects to something other than login/locked falls back the same way', () async {
      final client = ApiClient.forTesting(
        Dio(BaseOptions(baseUrl: 'http://test'))
          ..httpClientAdapter = _PathRoutingAdapter(
            listBody: _validListHtml,
            detailStatusCode: 302,
            detailHeaders: _redirectTo('/gd/'),
          )
          ..interceptors.add(ApiExceptionsInterceptor()),
      );

      final detail = await ActivitiesRemoteDataSource(client).getActivityDetail(_syntheticIdFor('Group Discussion'));

      expect(detail.title, 'Group Discussion');
    });
  });

  group('ActivitiesRemoteDataSource.getSubActivityDetail', () {
    test('parses a valid 200 HTML response', () async {
      final client = _clientReturning(statusCode: 200, body: _validSubDetailHtml, headers: _htmlHeaders);
      final detail = await ActivitiesRemoteDataSource(client).getSubActivityDetail(12, 34);

      expect(detail.title, 'Common Business Terms');
      expect(detail.activityId, 12);
      expect(detail.activityTitle, 'Business Vocabulary Building Games');
      expect(detail.order, 1);
      expect(detail.status.name, 'inProgress');
      expect(detail.exercises, hasLength(1));
      expect(detail.exercises.single.id, 501);
      expect(detail.exercises.single.exerciseType, 'mcq');
    });

    test('a redirect to the login page throws UnauthorizedException', () async {
      final client = _clientReturning(statusCode: 302, body: '', headers: _redirectTo('/users/login/?next=/activities/12/sub/34/'));
      expect(() => ActivitiesRemoteDataSource(client).getSubActivityDetail(12, 34), throwsA(isA<UnauthorizedException>()));
    });

    test('a redirect to the locked-upgrade page throws ForbiddenException', () async {
      final client = _clientReturning(statusCode: 302, body: '', headers: _redirectTo('/activities/?locked=1'));
      expect(() => ActivitiesRemoteDataSource(client).getSubActivityDetail(12, 34), throwsA(isA<ForbiddenException>()));
    });

    test('a non-200 status maps through the existing exception mapper', () async {
      final client = _clientReturning(statusCode: 500, body: '');
      expect(() => ActivitiesRemoteDataSource(client).getSubActivityDetail(12, 34), throwsA(isA<ServerException>()));
    });
  });

  group('ActivitiesRemoteDataSource.markSubComplete', () {
    test('completes normally on a 302 (the view\'s only real success shape)', () async {
      final client = _clientReturning(statusCode: 302, body: '');
      await expectLater(ActivitiesRemoteDataSource(client).markSubComplete(34), completes);
    });

    test('treats an unexpected 200 as unexpected, not success', () async {
      // mark_sub_complete has no validation-error branch server-side — it
      // always redirects on success — so a 200 here would be a shape the
      // view never actually produces.
      final client = _clientReturning(statusCode: 200, body: '');
      expect(() => ActivitiesRemoteDataSource(client).markSubComplete(34), throwsA(isA<UnexpectedResponseException>()));
    });

    test('maps a 403 through the existing exception mapper (generic mapping, not a case this view actually produces — '
        'mark_sub_complete has no access check of its own, confirmed by reading the view)', () async {
      final client = _clientReturning(statusCode: 403, body: '');
      expect(() => ActivitiesRemoteDataSource(client).markSubComplete(34), throwsA(isA<ForbiddenException>()));
    });

    test('maps a 404 (invalid id) through the existing exception mapper', () async {
      final client = _clientReturning(statusCode: 404, body: '');
      expect(() => ActivitiesRemoteDataSource(client).markSubComplete(999999), throwsA(isA<NotFoundException>()));
    });
  });
}
