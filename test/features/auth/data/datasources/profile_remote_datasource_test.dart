import 'package:career_buddy_lms/core/errors/exceptions.dart';
import 'package:career_buddy_lms/core/network/api_client.dart';
import 'package:career_buddy_lms/features/auth/data/datasources/profile_remote_datasource.dart';
import 'package:career_buddy_lms/features/auth/domain/entities/profile_data.dart';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../../support/fake_http_client_adapter.dart';

/// Phase 1 (web-to-Flutter conversion) — `templates/users/profile.html`'s
/// Overview tab has no JSON API; this fixture reproduces its real,
/// consistently-repeated `info-item-label`/`info-item-value` markup (and
/// the sidebar's `profile-stat-value`/recent-results markup) so
/// [ProfileRemoteDataSource.getProfile]'s regex-based scraper can be
/// verified against something shaped like the real page, not a guess.
const _fixtureHtml = '''
<h4 class="mt-3 mb-1 text-white font-semibold">Venkat Sai</h4>
<p class="text-slate-400 text-sm mb-2">@nvenkatsai</p>
<div class="profile-stat"><div class="profile-stat-value text-indigo-400">5</div></div>
<div class="profile-stat"><div class="profile-stat-value text-emerald-400">3</div></div>
<div class="profile-stat"><div class="profile-stat-value text-amber-400">120</div></div>
<div id="recent-exercise-results">
  <div class="d-flex"><span class="text-truncate me-2">Elevator Pitch</span><span class="text-amber-400 fw-semibold">8/10</span></div>
  <div class="d-flex"><span class="text-truncate me-2">Negotiation Quiz</span><span class="text-amber-400 fw-semibold">6/10</span></div>
</div>
<span class="info-item-label">Email Address</span>
<span class="info-item-value">nvenkatsai@example.com</span>
<span class="info-item-label">Username</span>
<span class="info-item-value">nvenkatsai</span>
<span class="info-item-label">Mobile Number</span>
<span class="info-item-value">+919876543210</span>
<span class="info-item-label">Alternate Mobile</span>
<span class="info-item-value">Not Provided</span>
<span class="info-item-label">Gender</span>
<span class="info-item-value">Male</span>
<span class="info-item-label">Aadhar Number</span>
<span class="info-item-value">XXXX XXXX 1234</span>
<span class="info-item-label">Highest Qualification</span>
<span class="info-item-value">Under-Graduate / Degree</span>
<span class="info-item-label">Year of Passing</span>
<span class="info-item-value">2020</span>
<span class="info-item-label">Experience Status</span>
<span class="info-item-value">Fresher</span>
<span class="info-item-label">Current CTC</span>
<span class="info-item-value">0.0 LPA</span>
''';

/// Adds the Edit tab's `english_level`/`bio`/`additional_educations_json`
/// markup to [_fixtureHtml] — modeled on Django's real widget rendering
/// (`forms.Select`/`forms.Textarea`, `users/forms.py:814-815`) and the
/// `const rawData = "...";` JS-escapejs literal
/// (`templates/users/profile.html:1092`) — so the round-trip-only scraping
/// these 3 fields need can be verified against something shaped like the
/// real page, not a guess.
const _fixtureHtmlWithEditForm =
    '$_fixtureHtml'
    '<select name="english_level" class="form-select" id="id_english_level">'
    '<option value="beginner">Pre-Intermediate</option>'
    '<option value="intermediate" selected>Intermediate</option>'
    '<option value="upper_intermediate">Upper-Intermediate</option>'
    '<option value="advanced">Advanced</option>'
    '</select>'
    '<textarea name="bio" cols="40" rows="3" class="form-control" id="id_bio">\nLoves &amp; enjoys teaching.</textarea>'
    // Django's `escapejs` encodes every `"` as `"` (not `\"`) — this
    // literally embeds that same 6-character escape sequence (one
    // backslash + `u0022`), not a Dart-interpreted unicode character, to
    // model the real server output byte-for-byte.
    'const rawData = "[{\\u0022degree\\u0022: \\u0022B.Tech\\u0022, \\u0022year\\u0022: \\u00222019\\u0022}]";';

/// `contact_person_role`/`contact_person_mobile`/`contact_person_email` have
/// no Overview `info-item` at all (confirmed directly against production —
/// see `ProfileRemoteDataSource`'s doc comment), so they're only present in
/// the Edit tab's own `<input>` markup — modeled here on the exact live
/// markup for a POPULATED value (role/email: plain `value="..."` attribute;
/// mobile: the same hidden-input-with-`value`-attribute pattern already
/// confirmed for `mobile`/`alternate_mobile`).
const _fixtureHtmlWithContactPerson =
    '$_fixtureHtmlWithEditForm'
    '<input type="text" name="contact_person_role" class="form-control" '
    'value="HR Manager" placeholder="Contact Role (e.g. HR Manager, Team Lead)" '
    'maxlength="100" id="id_contact_person_role">'
    '<input type="hidden" name="contact_person_mobile" value="+919876500000" id="id_contact_person_mobile">'
    '<input type="email" name="contact_person_email" class="form-control" '
    'value="hr@example.com" placeholder="Contact Email ID" maxlength="320" id="id_contact_person_email">';

void main() {
  group('getProfile', () {
    test('parses header, stats, recent results, and info-item fields', () async {
      final dio = Dio(BaseOptions(baseUrl: 'https://example.test'))
        ..httpClientAdapter = FakeHttpClientAdapter(statusCode: 200, body: _fixtureHtml);
      final datasource = ProfileRemoteDataSource(ApiClient.forTesting(dio));

      final profile = await datasource.getProfile();

      expect(profile.fullName, 'Venkat Sai');
      expect(profile.username, 'nvenkatsai');
      expect(profile.email, 'nvenkatsai@example.com');
      expect(profile.activitiesStarted, 5);
      expect(profile.completedSubs, 3);
      expect(profile.totalScore, 120);
      expect(profile.recentResults, hasLength(2));
      expect(profile.recentResults.first.title, 'Elevator Pitch');
      expect(profile.recentResults.first.score, 8);
      expect(profile.recentResults.first.maxScore, 10);
      expect(profile.field(ProfileFieldLabels.mobile), '+919876543210');
      expect(profile.field(ProfileFieldLabels.alternateMobile), 'Not Provided');
      expect(profile.field(ProfileFieldLabels.gender), 'Male');
      expect(profile.field(ProfileFieldLabels.aadhar), 'XXXX XXXX 1234');
      expect(profile.field(ProfileFieldLabels.educationLevel), 'Under-Graduate / Degree');
      expect(profile.field(ProfileFieldLabels.experienceStatus), 'Fresher');
    });

    test('extracts englishLevel/bio/additionalEducationsJson from the Edit tab markup', () async {
      final dio = Dio(BaseOptions(baseUrl: 'https://example.test'))
        ..httpClientAdapter = FakeHttpClientAdapter(statusCode: 200, body: _fixtureHtmlWithEditForm);
      final datasource = ProfileRemoteDataSource(ApiClient.forTesting(dio));

      final profile = await datasource.getProfile();

      expect(profile.englishLevel, 'intermediate');
      expect(profile.bio, 'Loves & enjoys teaching.');
      // Recovered from the escapejs-encoded `rawData` literal, including a
      // `"`-escaped quote — proving the JSON-decode round-trip handles
      // escaped characters, not just a plain unescaped string.
      expect(profile.additionalEducationsJson, '[{"degree": "B.Tech", "year": "2019"}]');
    });

    test('defaults englishLevel/bio/additionalEducationsJson safely when the Edit tab markup is absent', () async {
      final dio = Dio(BaseOptions(baseUrl: 'https://example.test'))
        ..httpClientAdapter = FakeHttpClientAdapter(statusCode: 200, body: _fixtureHtml);
      final datasource = ProfileRemoteDataSource(ApiClient.forTesting(dio));

      final profile = await datasource.getProfile();

      expect(profile.englishLevel, 'intermediate');
      expect(profile.bio, '');
      expect(profile.additionalEducationsJson, '[]');
    });

    test('extracts contactPersonRole/Mobile/Email from the Edit tab markup when populated', () async {
      final dio = Dio(BaseOptions(baseUrl: 'https://example.test'))
        ..httpClientAdapter = FakeHttpClientAdapter(statusCode: 200, body: _fixtureHtmlWithContactPerson);
      final datasource = ProfileRemoteDataSource(ApiClient.forTesting(dio));

      final profile = await datasource.getProfile();

      expect(profile.contactPersonRole, 'HR Manager');
      expect(profile.contactPersonMobile, '+919876500000');
      expect(profile.contactPersonEmail, 'hr@example.com');
    });

    test('defaults contactPersonRole/Mobile/Email to empty when unset (no "value" attribute, matching production for an account with no stored data)', () async {
      final dio = Dio(BaseOptions(baseUrl: 'https://example.test'))
        ..httpClientAdapter = FakeHttpClientAdapter(statusCode: 200, body: _fixtureHtmlWithEditForm);
      final datasource = ProfileRemoteDataSource(ApiClient.forTesting(dio));

      final profile = await datasource.getProfile();

      expect(profile.contactPersonRole, '');
      expect(profile.contactPersonMobile, '');
      expect(profile.contactPersonEmail, '');
    });

    test('throws ServerException on a non-200 response', () async {
      final dio = Dio(BaseOptions(baseUrl: 'https://example.test'))
        ..httpClientAdapter = FakeHttpClientAdapter(statusCode: 500, body: '');
      final datasource = ProfileRemoteDataSource(ApiClient.forTesting(dio));

      await expectLater(datasource.getProfile(), throwsA(isA<ServerException>()));
    });
  });

  group('updateProfile', () {
    const data = ProfileEditData(
      firstName: 'Venkat',
      lastName: 'Sai',
      email: 'nvenkatsai@example.com',
      englishLevel: 'intermediate',
      bio: '',
      additionalEducationsJson: '[]',
    );

    test('completes without throwing on a real 302 (redirect-on-success)', () async {
      final dio = Dio(BaseOptions(baseUrl: 'https://example.test'))
        ..httpClientAdapter = FakeHttpClientAdapter(statusCode: 302, body: '');
      final datasource = ProfileRemoteDataSource(ApiClient.forTesting(dio));

      await expectLater(datasource.updateProfile(data), completes);
    });

    test('always posts englishLevel/bio/additionalEducationsJson verbatim, even though no UI edits them', () async {
      RequestOptions? captured;
      final dio = Dio(BaseOptions(baseUrl: 'https://example.test'))
        ..httpClientAdapter = FakeHttpClientAdapter(statusCode: 302, body: '', onRequest: (o) => captured = o);
      final datasource = ProfileRemoteDataSource(ApiClient.forTesting(dio));
      const edited = ProfileEditData(
        firstName: 'Changed', // the user only touched this field...
        lastName: 'Sai',
        email: 'nvenkatsai@example.com',
        englishLevel: 'advanced', // ...but these 3 must still round-trip through unchanged.
        bio: 'A real bio with a " quote.',
        additionalEducationsJson: '[{"degree": "MBA"}]',
      );

      await datasource.updateProfile(edited);

      final sentFields = (captured!.data as FormData).fields;
      String fieldValue(String name) => sentFields.firstWhere((e) => e.key == name).value;
      expect(fieldValue('english_level'), 'advanced');
      expect(fieldValue('bio'), 'A real bio with a " quote.');
      expect(fieldValue('additional_educations_json'), '[{"degree": "MBA"}]');
    });

    test('sends contact_person_role/mobile/email under their exact Django field names, preserved unchanged when only an unrelated field is edited', () async {
      // Regression guard for the Contact Person data-loss bug: before this
      // fix, `_EditTabState._submit()` never populated these 3 fields from
      // the loaded profile, so every save sent `ProfileEditData`'s `''`
      // defaults — silently wiping any existing Contact Person data
      // server-side (`ProfileUpdateForm.save()` has no "blank = keep
      // existing" fallback for these 3 fields, unlike Aadhar/PAN/Passport).
      RequestOptions? captured;
      final dio = Dio(BaseOptions(baseUrl: 'https://example.test'))
        ..httpClientAdapter = FakeHttpClientAdapter(statusCode: 302, body: '', onRequest: (o) => captured = o);
      final datasource = ProfileRemoteDataSource(ApiClient.forTesting(dio));
      const edited = ProfileEditData(
        firstName: 'Changed', // the user only touched this field...
        lastName: 'Sai',
        email: 'nvenkatsai@example.com',
        englishLevel: 'intermediate',
        bio: '',
        additionalEducationsJson: '[]',
        // ...but these 3 must still round-trip through unchanged, exactly
        // as `getProfile()` last scraped them.
        contactPersonRole: 'HR Manager',
        contactPersonMobile: '+919876500000',
        contactPersonEmail: 'hr@example.com',
      );

      await datasource.updateProfile(edited);

      final sentFields = (captured!.data as FormData).fields;
      String fieldValue(String name) => sentFields.firstWhere((e) => e.key == name).value;
      expect(fieldValue('contact_person_role'), 'HR Manager');
      expect(fieldValue('contact_person_mobile'), '+919876500000');
      expect(fieldValue('contact_person_email'), 'hr@example.com');
    });

    test('sends has_experience/has_abroad_experience as "True"/"False" (Django\'s own convention), not Dart\'s lowercase bool.toString()', () async {
      // Confirmed live against production: `has_experience`/
      // `has_abroad_experience` are real `<select>` fields whose only valid
      // `<option>` values are `"True"`/`"False"` (capitalized) — Dart's
      // `true.toString()`/`false.toString()` produce lowercase `"true"`/
      // `"false"`, which match neither option and make the whole save fail
      // with "Select a valid choice" for ANY account that had ever answered
      // either question (not just accounts missing a mobile number).
      RequestOptions? captured;
      final dio = Dio(BaseOptions(baseUrl: 'https://example.test'))
        ..httpClientAdapter = FakeHttpClientAdapter(statusCode: 302, body: '', onRequest: (o) => captured = o);
      final datasource = ProfileRemoteDataSource(ApiClient.forTesting(dio));
      const edited = ProfileEditData(
        firstName: 'Venkat',
        lastName: 'Sai',
        email: 'nvenkatsai@example.com',
        englishLevel: 'intermediate',
        bio: '',
        additionalEducationsJson: '[]',
        hasExperience: true,
        hasAbroadExperience: false,
      );

      await datasource.updateProfile(edited);

      final sentFields = (captured!.data as FormData).fields;
      String fieldValue(String name) => sentFields.firstWhere((e) => e.key == name).value;
      expect(fieldValue('has_experience'), 'True');
      expect(fieldValue('has_abroad_experience'), 'False');
    });

    test('throws ValidationException with the scraped field error on a 200', () async {
      final dio = Dio(BaseOptions(baseUrl: 'https://example.test'))
        ..httpClientAdapter = FakeHttpClientAdapter(
          statusCode: 200,
          body: '<div class="invalid-feedback d-block">This field is required.</div>',
        );
      final datasource = ProfileRemoteDataSource(ApiClient.forTesting(dio));

      await expectLater(
        datasource.updateProfile(data),
        throwsA(isA<ValidationException>().having((e) => e.message, 'message', 'This field is required.')),
      );
    });
  });
}
