import 'package:career_buddy_lms/core/network/api_client.dart';
import 'package:career_buddy_lms/features/jam/data/jam_remote_datasource.dart';
import 'package:career_buddy_lms/features/jam/domain/entities/jam_history_profile.dart';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../support/fake_http_client_adapter.dart';

const _historyHtml = '''
<div id="content-regular">
<div class="group flex items-center justify-between p-5 rounded-2xl border border-slate-50">
<a href="/jam/session/5/"></a>
<h4 class="font-serif font-bold text-slate-900 group-hover:text-coral transition-all">Topic</h4>
<span class="badge-jam badge-jam-easy">easy</span>
<span class="text-xs text-slate-400 font-serif">Sep 1 2026 10:00 AM</span>
<div class="text-sm font-bold font-serif text-slate-900">30s</div>
</div>
</div>
<div id="content-assessments"></div>
''';

const _sessionDetailHtml = '''
<div id="resultCard">
<h1>Topic</h1>
</div>
''';

const _profileHtml = '''
<h3 class="font-serif text-xl font-bold text-slate-900">Alex</h3>
<input type="text" name="first_name" value="Alex">
<input type="text" name="last_name" value="Kumar">
<input type="email" name="email" value="alex@example.com">
<textarea name="bio" rows="4"></textarea>
''';

const _profileUpdate = JamProfileUpdate(firstName: 'Alex', lastName: 'Kumar', email: 'alex@example.com', bio: 'Hi');

void main() {
  group('getHistoryPage', () {
    test('parses a real 200 response', () async {
      final dio = Dio(BaseOptions(baseUrl: 'https://example.test'))
        ..httpClientAdapter = FakeHttpClientAdapter(statusCode: 200, body: _historyHtml);
      final datasource = JamRemoteDataSource(ApiClient.forTesting(dio));

      final page = await datasource.getHistoryPage();

      expect(page.sessions.single.sessionId, 5);
    });
  });

  group('getProfile', () {
    test('parses a real 200 response', () async {
      final dio = Dio(BaseOptions(baseUrl: 'https://example.test'))
        ..httpClientAdapter = FakeHttpClientAdapter(statusCode: 200, body: _profileHtml);
      final datasource = JamRemoteDataSource(ApiClient.forTesting(dio));

      final profile = await datasource.getProfile();

      expect(profile.fullName, 'Alex');
    });
  });

  group('updateProfile', () {
    test('completes without throwing on a real 302 (redirect-on-success)', () async {
      final dio = Dio(BaseOptions(baseUrl: 'https://example.test'))
        ..httpClientAdapter = FakeHttpClientAdapter(statusCode: 302, body: '');
      final datasource = JamRemoteDataSource(ApiClient.forTesting(dio));

      await expectLater(datasource.updateProfile(_profileUpdate), completes);
    });

    test('throws on a 200 (the real web shows no error UI, but this is still a failed save)', () async {
      final dio = Dio(BaseOptions(baseUrl: 'https://example.test'))
        ..httpClientAdapter = FakeHttpClientAdapter(statusCode: 200, body: _profileHtml);
      final datasource = JamRemoteDataSource(ApiClient.forTesting(dio));

      await expectLater(datasource.updateProfile(_profileUpdate), throwsException);
    });
  });

  group('deleteSession', () {
    test('completes without throwing on a real 302', () async {
      final dio = Dio(BaseOptions(baseUrl: 'https://example.test'))
        ..httpClientAdapter = FakeHttpClientAdapter(statusCode: 302, body: '');
      final datasource = JamRemoteDataSource(ApiClient.forTesting(dio));

      await expectLater(datasource.deleteSession(5), completes);
    });
  });

  group('deleteAssessment', () {
    test('completes without throwing on a real 302', () async {
      final dio = Dio(BaseOptions(baseUrl: 'https://example.test'))
        ..httpClientAdapter = FakeHttpClientAdapter(statusCode: 302, body: '');
      final datasource = JamRemoteDataSource(ApiClient.forTesting(dio));

      await expectLater(datasource.deleteAssessment(7), completes);
    });
  });

  group('resetProgress', () {
    test('completes without throwing on a real 302', () async {
      final dio = Dio(BaseOptions(baseUrl: 'https://example.test'))
        ..httpClientAdapter = FakeHttpClientAdapter(statusCode: 302, body: '');
      final datasource = JamRemoteDataSource(ApiClient.forTesting(dio));

      await expectLater(datasource.resetProgress(), completes);
    });
  });

  group('getSessionDetail', () {
    test('parses a real 200 response (pure read, not complete_session)', () async {
      final dio = Dio(BaseOptions(baseUrl: 'https://example.test'))
        ..httpClientAdapter = FakeHttpClientAdapter(statusCode: 200, body: _sessionDetailHtml);
      final datasource = JamRemoteDataSource(ApiClient.forTesting(dio));

      final result = await datasource.getSessionDetail(5);

      expect(result.sessionId, 5);
    });
  });
}
