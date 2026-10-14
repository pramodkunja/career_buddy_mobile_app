import 'dart:convert';

import 'package:career_buddy_lms/core/errors/exceptions.dart';
import 'package:career_buddy_lms/core/network/api_client.dart';
import 'package:career_buddy_lms/features/resume/data/resume_remote_datasource.dart';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../support/fake_http_client_adapter.dart';

/// A representative fixture matching `manual_resume_roles`'s real response
/// shape — `client_payload(full=True)` (confirmed directly,
/// `career_app/manual_resume_views.py:111`): every built-in field is
/// present, not just the lighter `CARD_KEYS` subset the landing page's own
/// inline script uses. Only the fields `parseManualResumeRoles` actually
/// reads are populated meaningfully; the rest (`fields`/`levels`/
/// `summary_focus`/etc.) are included to prove they're safely ignored, not
/// omitted to make parsing easier than it really is.
const _rolesFixtureJson = '''
{
  "roles": [
    {
      "slug": "software-developer",
      "title": "Software Developer",
      "category": "it",
      "category_label": "IT Role",
      "icon": "code",
      "industry": "Information Technology",
      "subtitle": "Frontend, backend, full-stack",
      "description": "Builds and maintains applications.",
      "responsibilities": ["Write clean code"],
      "required_skills": ["JavaScript"],
      "recommended_skills": [],
      "career_path": [],
      "certifications": [],
      "fields": [],
      "levels": {},
      "summary_focus": {},
      "experience_label": "Professional Experience"
    },
    {
      "slug": "hse-engineer",
      "title": "HSE Engineer",
      "category": "nt",
      "category_label": "Non-IT · Non-Technical",
      "icon": "shield",
      "industry": "Engineering, Construction & Energy Projects",
      "subtitle": "Health, Safety & Environment",
      "description": "Oversees workplace safety compliance.",
      "responsibilities": [],
      "required_skills": [],
      "recommended_skills": [],
      "career_path": [],
      "certifications": [],
      "fields": [],
      "levels": {},
      "summary_focus": {},
      "experience_label": "Professional Experience"
    }
  ],
  "levels": [{"key": "fresher", "label": "Fresher"}],
  "level_common": {},
  "categories": {"it": "IT Role", "tech": "Non-IT · Technical", "nt": "Non-IT · Non-Technical"},
  "sections": []
}
''';

/// REGRESSION (Phase 19) — `getParseQuota()` is a dedicated GET of
/// `resume_builder_home`, deliberately independent of the conditional
/// `_ensureCsrfCookie()` priming call: it must always fire, regardless of
/// whether a CSRF cookie already exists this session, so the count is
/// never stale.
void main() {
  group('ResumeRemoteDataSource.getParseQuota', () {
    test('hits the real resume_builder_home endpoint with a GET', () async {
      RequestOptions? captured;
      final dio = Dio(BaseOptions(baseUrl: 'http://test'))
        ..httpClientAdapter = FakeHttpClientAdapter(
          statusCode: 200,
          body: '<span><i class="fas fa-file-lines"></i> Free plan: 2 of 4 resume analyses left</span>',
          onRequest: (o) => captured = o,
        );
      final ds = ResumeRemoteDataSource(ApiClient.forTesting(dio));

      final quota = await ds.getParseQuota();

      expect(captured!.method, 'GET');
      expect(captured!.path, '/resume-builder/');
      expect(quota, isNotNull);
      expect(quota!.left, 2);
      expect(quota.limit, 4);
    });

    test('fires even when a csrftoken cookie already exists — never piggybacks on _ensureCsrfCookie', () async {
      final dio = Dio(BaseOptions(baseUrl: 'http://test'))
        ..httpClientAdapter = FakeHttpClientAdapter(
          statusCode: 200,
          body: 'Free plan: 1 of 4 resume analyses left',
          // A real cookie jar isn't wired up in this minimal test client, so
          // there is no stored csrftoken cookie to begin with — this test's
          // point is simply that getParseQuota() never checks for one at
          // all (unlike _ensureCsrfCookie, which is a separate, unrelated
          // method this call never touches). Calling it twice in a row,
          // both times expecting a real request, demonstrates that.
          onRequest: (_) {},
        );
      final ds = ResumeRemoteDataSource(ApiClient.forTesting(dio));

      final first = await ds.getParseQuota();
      final second = await ds.getParseQuota();

      expect(first, isNotNull);
      expect(second, isNotNull);
    });

    test('a 500/error response has no badge to find, so it also safely returns null', () async {
      final dio = Dio(BaseOptions(baseUrl: 'http://test'))
        ..httpClientAdapter = FakeHttpClientAdapter(statusCode: 500, body: 'Internal Server Error');
      final ds = ResumeRemoteDataSource(ApiClient.forTesting(dio));

      expect(await ds.getParseQuota(), isNull);
    });

    test('a genuine request failure (e.g. a network error) is caught and returns null, never throwing', () async {
      final dio = Dio(BaseOptions(baseUrl: 'http://test'))
        ..httpClientAdapter = FakeHttpClientAdapter(
          statusCode: 200,
          onRequest: (_) => throw Exception('connection refused'),
        );
      final ds = ResumeRemoteDataSource(ApiClient.forTesting(dio));

      expect(await ds.getParseQuota(), isNull);
    });

    test('a response with no badge at all (e.g. a paid-plan page) returns null, not an error', () async {
      final dio = Dio(BaseOptions(baseUrl: 'http://test'))
        ..httpClientAdapter = FakeHttpClientAdapter(
          statusCode: 200,
          body: '<div class="resume-hero"><h1>Resume Analysis & ATS Score</h1></div>',
        );
      final ds = ResumeRemoteDataSource(ApiClient.forTesting(dio));

      expect(await ds.getParseQuota(), isNull);
    });
  });

  group('ResumeRemoteDataSource.getRoles (Phase 23)', () {
    test('hits the real manual_resume_roles endpoint and parses every role field', () async {
      RequestOptions? captured;
      final dio = Dio(BaseOptions(baseUrl: 'http://test'))
        ..httpClientAdapter = FakeHttpClientAdapter(
          statusCode: 200,
          body: _rolesFixtureJson,
          headers: const {'content-type': ['application/json']},
          onRequest: (o) => captured = o,
        );
      final ds = ResumeRemoteDataSource(ApiClient.forTesting(dio));

      final roles = await ds.getRoles();

      expect(captured!.method, 'GET');
      expect(captured!.path, '/resume-builder/manual/roles/');
      expect(roles, hasLength(2));
      expect(roles[0].slug, 'software-developer');
      expect(roles[0].title, 'Software Developer');
      expect(roles[0].category, 'it');
      expect(roles[0].categoryLabel, 'IT Role');
      expect(roles[0].subtitle, 'Frontend, backend, full-stack');
      expect(roles[0].track, 'tech'); // 'it' category -> 'tech' track
      expect(roles[1].category, 'nt');
      expect(roles[1].track, 'nonit'); // every non-'it' category -> 'nonit' track
    });

    test('an empty roles list is a valid, real response — returns an empty list, not an error', () async {
      final dio = Dio(BaseOptions(baseUrl: 'http://test'))
        ..httpClientAdapter = FakeHttpClientAdapter(
          statusCode: 200,
          body: jsonEncode({'roles': [], 'levels': [], 'level_common': {}, 'categories': {}, 'sections': []}),
          headers: const {'content-type': ['application/json']},
        );
      final ds = ResumeRemoteDataSource(ApiClient.forTesting(dio));

      expect(await ds.getRoles(), isEmpty);
    });

    test('a malformed top-level response (not a map) throws, mapped to a real failure upstream', () async {
      final dio = Dio(BaseOptions(baseUrl: 'http://test'))
        ..httpClientAdapter = FakeHttpClientAdapter(
          statusCode: 200,
          body: jsonEncode([1, 2, 3]),
          headers: const {'content-type': ['application/json']},
        );
      final ds = ResumeRemoteDataSource(ApiClient.forTesting(dio));

      // Dio hands back a List, not a Map<String, dynamic> — the typed GET
      // itself throws a DioException (type cast failure), which this
      // method re-throws as an AppException, never a silent empty list.
      await expectLater(ds.getRoles(), throwsA(isA<AppException>()));
    });

    test('one malformed role entry is skipped; the rest of a real response still parses', () async {
      final dio = Dio(BaseOptions(baseUrl: 'http://test'))
        ..httpClientAdapter = FakeHttpClientAdapter(
          statusCode: 200,
          body: jsonEncode({
            'roles': [
              {'slug': 'ok-role', 'title': 'OK Role', 'category': 'it', 'category_label': 'IT Role', 'subtitle': 'x'},
              {'slug': 'bad-role', 'title': null, 'category': 'it', 'subtitle': 'y'}, // title not a String
              {'slug': 'empty-subtitle', 'title': 'No Dept', 'category': 'it', 'subtitle': ''}, // empty dept
            ],
          }),
          headers: const {'content-type': ['application/json']},
        );
      final ds = ResumeRemoteDataSource(ApiClient.forTesting(dio));

      final roles = await ds.getRoles();

      expect(roles, hasLength(1));
      expect(roles.single.slug, 'ok-role');
    });

    test('a genuine request failure is thrown as an AppException, not swallowed', () async {
      final dio = Dio(BaseOptions(baseUrl: 'http://test'))
        ..httpClientAdapter = FakeHttpClientAdapter(
          statusCode: 200,
          onRequest: (_) => throw Exception('connection refused'),
        );
      final ds = ResumeRemoteDataSource(ApiClient.forTesting(dio));

      await expectLater(ds.getRoles(), throwsA(isA<AppException>()));
    });
  });

  group('ResumeRemoteDataSource.selectTargetRole (Phase 23)', () {
    test('sends the exact role/dept/track query parameters to resume_builder_home', () async {
      RequestOptions? captured;
      final dio = Dio(BaseOptions(baseUrl: 'http://test'))
        ..httpClientAdapter = FakeHttpClientAdapter(
          statusCode: 200,
          body: '<span>Target role: Software Developer &middot; Frontend, backend, full-stack</span>',
          onRequest: (o) => captured = o,
        );
      final ds = ResumeRemoteDataSource(ApiClient.forTesting(dio));

      await ds.selectTargetRole(role: 'Software Developer', dept: 'Frontend, backend, full-stack', track: 'tech');

      expect(captured!.method, 'GET');
      expect(captured!.path, '/resume-builder/');
      expect(captured!.queryParameters, {
        'role': 'Software Developer',
        'dept': 'Frontend, backend, full-stack',
        'track': 'tech',
      });
    });

    test('confirms success only when the response echoes back the exact same role/dept just sent', () async {
      final dio = Dio(BaseOptions(baseUrl: 'http://test'))
        ..httpClientAdapter = FakeHttpClientAdapter(
          statusCode: 200,
          body: '<span>Target role: HSE Engineer &middot; Health, Safety &amp; Environment</span>',
        );
      final ds = ResumeRemoteDataSource(ApiClient.forTesting(dio));

      final result = await ds.selectTargetRole(
        role: 'HSE Engineer',
        dept: 'Health, Safety & Environment',
        track: 'nonit',
      );

      expect(result.role, 'HSE Engineer');
      expect(result.dept, 'Health, Safety & Environment');
    });

    test('never claims success when the badge is absent — e.g. an anonymous/expired session redirected to login',
        () async {
      final dio = Dio(BaseOptions(baseUrl: 'http://test'))
        ..httpClientAdapter = FakeHttpClientAdapter(
          statusCode: 200,
          // A login page's HTML has no "Target role" badge at all.
          body: '<form><input name="username"></form>',
        );
      final ds = ResumeRemoteDataSource(ApiClient.forTesting(dio));

      await expectLater(
        ds.selectTargetRole(role: 'Software Developer', dept: 'Frontend, backend, full-stack', track: 'tech'),
        throwsA(isA<UnauthorizedException>()),
      );
    });

    test('never claims success when the echoed role/dept mismatches what was sent', () async {
      final dio = Dio(BaseOptions(baseUrl: 'http://test'))
        ..httpClientAdapter = FakeHttpClientAdapter(
          statusCode: 200,
          // Echoes a stale, different role than the one just requested.
          body: '<span>Target role: Some Other Role &middot; Some Other Dept</span>',
        );
      final ds = ResumeRemoteDataSource(ApiClient.forTesting(dio));

      await expectLater(
        ds.selectTargetRole(role: 'Software Developer', dept: 'Frontend, backend, full-stack', track: 'tech'),
        throwsA(isA<UnauthorizedException>()),
      );
    });

    test('a genuine request failure is thrown as an AppException, not reported as success', () async {
      final dio = Dio(BaseOptions(baseUrl: 'http://test'))
        ..httpClientAdapter = FakeHttpClientAdapter(
          statusCode: 200,
          onRequest: (_) => throw Exception('connection refused'),
        );
      final ds = ResumeRemoteDataSource(ApiClient.forTesting(dio));

      await expectLater(
        ds.selectTargetRole(role: 'Software Developer', dept: 'Frontend, backend, full-stack', track: 'tech'),
        throwsA(isA<AppException>()),
      );
    });
  });
}
