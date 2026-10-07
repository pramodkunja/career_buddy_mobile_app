import 'dart:convert';

import 'package:dio/dio.dart';

import '../../../../core/errors/exceptions.dart';
import '../../../../core/network/api_client.dart';
import '../../../../core/network/api_endpoints.dart';
import '../../domain/entities/profile_data.dart';

/// `users/views.py:profile_view` (`ApiEndpoints.profile`) — a single URL
/// serving BOTH the read-only Overview tab and the Edit form in one GET
/// response (no JSON API, no separate URL per tab). [getProfile] scrapes
/// the Overview tab's `info-item-label`/`info-item-value` pairs (a
/// uniform, repeated markup pattern — see `_infoItemPattern` — that every
/// field in `templates/users/profile.html` follows, including the
/// conditional ones: a field the server chose not to render for this user
/// simply doesn't appear in the parsed map, no special-casing needed).
/// [updateProfile] POSTs the same URL; same 302-success/200-failure
/// convention as login/registration. [getProfile] also scrapes 3 fields
/// that have no Edit-tab UI at all (`english_level`, `bio`,
/// `additional_educations_json` — see `ProfileEditData`'s doc comments) so
/// [updateProfile] can always post them back unchanged: `english_level` is
/// `required=True` server-side with no value this app ever sends, so every
/// save would otherwise fail validation; `bio`/`additional_educations_json`
/// have no "absent means unchanged" handling server-side, so omitting them
/// would otherwise silently wipe them on every successful save.
class ProfileRemoteDataSource {
  ProfileRemoteDataSource(this._apiClient);

  final ApiClient _apiClient;

  static final _infoItemPattern = RegExp(
    r'info-item-label">([^<]*)</span>\s*<span class="info-item-value">\s*([\s\S]*?)\s*</span>',
  );
  static final _statValuePattern = RegExp(r'profile-stat-value[^"]*">\s*(\d+)\s*<');
  static final _fullNamePattern = RegExp(
    r'<h4[^>]*>\s*([\s\S]*?)\s*</h4>',
  );
  static final _usernamePattern = RegExp(r'text-slate-400 text-sm mb-2">\s*@([^<]*)<');
  static final _recentResultPattern = RegExp(
    r'text-truncate me-2">\s*([\s\S]*?)\s*</span>\s*<span class="text-amber-400 fw-semibold">\s*(\d+)\s*/\s*(\d+)\s*<',
  );
  static final _htmlTagPattern = RegExp(r'<[^>]*>');
  static final _fieldErrorPattern = RegExp(r'invalid-feedback d-block">([^<]+)<');

  // ── `english_level`/`bio`/`additional_educations_json` round-trip-only
  // scraping (never shown in any Flutter UI — see `ProfileEditData`'s doc
  // comment on why these 3 must still be sent back verbatim on every save).
  //
  // `users/forms.py:814`'s `forms.Select` (`templates/users/profile.html:638`
  // `{{ form.english_level }}`) renders one `<option value="...">` per
  // `LEVEL_CHOICES` (`users/models.py:83-88`), with a bare `selected`
  // attribute (no `="selected"`, see Django's own
  // `django/forms/templates/django/forms/widgets/attrs.html`) on whichever
  // option matches the current value.
  static final _englishLevelSelectPattern = RegExp(
    r'<select[^>]*\bname="english_level"[^>]*>([\s\S]*?)</select>',
  );
  static final _selectedOptionValuePattern = RegExp(
    r'<option\s+value="([^"]*)"[^>]*\bselected\b[^>]*>',
  );

  // `users/forms.py:815`'s `forms.Textarea` (`templates/users/profile.html:700`
  // `{{ form.bio }}`) renders the current value as HTML-escaped text content.
  // Django's own `textarea.html` widget template emits a literal `\n`
  // immediately after the opening tag (the standard HTML
  // leading-newline-in-textarea convention), which we skip without touching
  // the value itself.
  static final _bioTextareaPattern = RegExp(
    r'<textarea[^>]*\bname="bio"[^>]*>\n?([\s\S]*?)</textarea>',
  );

  // `templates/users/profile.html:1092`'s
  // `const rawData = "{{ user.profile.additional_educations_json|escapejs }}";`
  // — a JS-string-literal-escaped JSON array. `(?:[^"\\]|\\.)*` matches a
  // full JS string body (handles any escaped quote/backslash) rather than
  // assuming there's never one, even though Django's `escapejs` happens to
  // never emit a bare `"` or `\` (see `django.utils.html._js_escapes`).
  static final _additionalEducationsRawDataPattern = RegExp(
    r'const rawData = "((?:[^"\\]|\\.)*)";',
  );

  String _stripHtml(String value) => value.replaceAll(_htmlTagPattern, '').trim();

  /// `has_experience`/`has_abroad_experience` are real `<select>` fields on
  /// the live page (`<option value="True">Yes</option>` /
  /// `<option value="False">No</option>`, confirmed directly against
  /// production) — a Django `TypedChoiceField` matching the Python
  /// convention `str(True)`/`str(False)`. Dart's own `bool.toString()`
  /// produces lowercase `"true"`/`"false"`, which doesn't match either
  /// `<option>`'s value, so Django's `ChoiceField` rejects the whole save
  /// with "Select a valid choice" — confirmed live: this was the actual
  /// cause of "Could not update your profile" for any account that had
  /// ever answered either question (not just accounts missing a mobile
  /// number, which is a separate, genuine data issue on some accounts).
  static String _djangoBool(bool value) => value ? 'True' : 'False';

  static String _unescapeHtmlEntities(String value) => value
      .replaceAll('&amp;', '&')
      .replaceAll('&lt;', '<')
      .replaceAll('&gt;', '>')
      .replaceAll('&quot;', '"')
      // Python's `html.escape` (which Django's `escape()`/autoescape use)
      // emits the hex form `&#x27;` for an apostrophe, not the decimal
      // `&#39;` — handle both for robustness.
      .replaceAll('&#x27;', "'")
      .replaceAll('&#39;', "'");

  String _extractEnglishLevel(String html) {
    final block = _englishLevelSelectPattern.firstMatch(html)?.group(1);
    if (block == null) return 'intermediate';
    return _selectedOptionValuePattern.firstMatch(block)?.group(1) ?? 'intermediate';
  }

  String _extractBio(String html) {
    final raw = _bioTextareaPattern.firstMatch(html)?.group(1) ?? '';
    return _unescapeHtmlEntities(raw);
  }

  /// Recovers the exact original JSON array text Django's `escapejs` filter
  /// encoded: wrapping the captured JS-string body in `"..."` turns it back
  /// into a valid JSON string literal (escapejs's `\uXXXX`/`\\`/`\"`
  /// conventions are a subset of JSON's own string-escaping grammar), so
  /// running it through `jsonDecode` recovers the original text — including
  /// any quote or non-ASCII character it contained — without us
  /// re-implementing JS/unicode unescaping by hand.
  String _extractAdditionalEducationsJson(String html) {
    final captured = _additionalEducationsRawDataPattern.firstMatch(html)?.group(1);
    if (captured == null) return '[]';
    try {
      final decoded = jsonDecode('"$captured"');
      return decoded is String ? decoded : '[]';
    } on FormatException {
      return '[]';
    }
  }

  Future<ProfileOverview> getProfile() async {
    try {
      final response = await _apiClient.dio.get<String>(
        ApiEndpoints.profile,
        options: Options(responseType: ResponseType.plain, validateStatus: (_) => true),
      );
      if (response.statusCode != 200) throw ServerException(response.statusCode);
      final html = response.data ?? '';

      final fields = <String, String>{};
      for (final m in _infoItemPattern.allMatches(html)) {
        final label = m.group(1)!.trim();
        final value = _stripHtml(m.group(2)!);
        // First occurrence wins — the dynamic `additional_educations_json`
        // loop can repeat "Additional Qualification" etc. beyond the first
        // (documented, disclosed scope limit — see `StudentRegistrationData`'s
        // doc comment for the same decision on the registration side); the
        // fixed-field set (`education_level_2` et al.) always renders first.
        fields.putIfAbsent(label, () => value);
      }

      final stats = _statValuePattern.allMatches(html).map((m) => int.tryParse(m.group(1)!) ?? 0).toList();

      final recentResults = [
        for (final m in _recentResultPattern.allMatches(html))
          ProfileRecentResult(
            title: _stripHtml(m.group(1)!),
            score: int.tryParse(m.group(2)!) ?? 0,
            maxScore: int.tryParse(m.group(3)!) ?? 0,
          ),
      ];

      final fullNameMatch = _fullNamePattern.firstMatch(html)?.group(1);
      return ProfileOverview(
        fullName: fullNameMatch == null ? '' : _stripHtml(fullNameMatch),
        username: _usernamePattern.firstMatch(html)?.group(1)?.trim() ?? '',
        email: fields['Email Address'] ?? '',
        activitiesStarted: stats.isNotEmpty ? stats[0] : 0,
        completedSubs: stats.length > 1 ? stats[1] : 0,
        totalScore: stats.length > 2 ? stats[2] : 0,
        recentResults: recentResults,
        fields: fields,
        englishLevel: _extractEnglishLevel(html),
        bio: _extractBio(html),
        additionalEducationsJson: _extractAdditionalEducationsJson(html),
      );
    } on DioException catch (e) {
      throw e.error is AppException ? e.error as AppException : const UnexpectedResponseException();
    }
  }

  /// `users/views.py:profile_view`'s POST branch — same URL as
  /// [getProfile], `multipart/form-data` (resume replace), 302-success/
  /// 200-failure convention as [login]/[register].
  Future<void> updateProfile(ProfileEditData data) async {
    try {
      final csrfToken = await _apiClient.readCookie('csrftoken');

      final formData = FormData.fromMap({
        'first_name': data.firstName,
        'last_name': data.lastName,
        'email': data.email,
        'gender': data.gender,
        'mobile': data.mobile,
        'alternate_mobile': data.alternateMobile,
        'blood_group': data.bloodGroup,
        'languages_known': data.languagesKnown,
        'aadhar_number': data.aadharNumber,
        'pan_number': data.panNumber,
        'passport_number': data.passportNumber,
        'education_level': data.educationLevel,
        if (data.passedOutYear != null) 'passed_out_year': data.passedOutYear.toString(),
        'iti_diploma_specialization': data.itiDiplomaSpecialization,
        'higher_education_degree': data.higherEducationDegree,
        'education_level_2': data.educationLevel2,
        if (data.passedOutYear2 != null) 'passed_out_year_2': data.passedOutYear2.toString(),
        'iti_diploma_specialization_2': data.itiDiplomaSpecialization2,
        'higher_education_degree_2': data.higherEducationDegree2,
        if (data.hasExperience != null) 'has_experience': _djangoBool(data.hasExperience!),
        if (data.experienceYears != null) 'experience_years': data.experienceYears.toString(),
        'company_name': data.companyName,
        'contact_person_role': data.contactPersonRole,
        'contact_person_mobile': data.contactPersonMobile,
        'contact_person_email': data.contactPersonEmail,
        'industry': data.industry,
        'skills': data.skills,
        if (data.currentCtc != null) 'current_ctc': data.currentCtc.toString(),
        if (data.expectedCtc != null) 'expected_ctc': data.expectedCtc.toString(),
        'certification': data.certification,
        'current_location': data.currentLocation,
        'preferred_location': data.preferredLocation,
        if (data.hasAbroadExperience != null) 'has_abroad_experience': _djangoBool(data.hasAbroadExperience!),
        if (data.abroadYears != null) 'abroad_years': data.abroadYears.toString(),
        'abroad_country': data.abroadCountry,
        'abroad_industry': data.abroadIndustry,
        'abroad_skills': data.abroadSkills,
        // Not editable from any Flutter UI — sent unconditionally, verbatim
        // from whatever `getProfile()` last scraped, purely so this save
        // doesn't fail `form.is_valid()` (`english_level`) or silently wipe
        // existing data (`bio`, `additional_educations_json`) — see
        // `ProfileEditData`'s doc comments on these 3 fields.
        'english_level': data.englishLevel,
        'bio': data.bio,
        'additional_educations_json': data.additionalEducationsJson,
        'csrfmiddlewaretoken': csrfToken ?? '',
        if (data.resumeFilePath != null)
          'resume': await MultipartFile.fromFile(data.resumeFilePath!, filename: data.resumeFileName),
      });

      final response = await _apiClient.dio.post(
        ApiEndpoints.profile,
        data: formData,
        options: Options(
          followRedirects: false,
          validateStatus: (_) => true,
          responseType: ResponseType.plain,
          headers: {'X-CSRFToken': csrfToken ?? ''},
        ),
      );

      if (response.statusCode == 302) return;
      if (response.statusCode == 200) {
        final String body = response.data ?? '';
        final message = _fieldErrorPattern.firstMatch(body)?.group(1)?.trim() ??
            'Could not update your profile — please check your details and try again.';
        throw ValidationException({'form': [message]}, message);
      }
      throw ServerException(response.statusCode);
    } on DioException catch (e) {
      throw e.error is AppException ? e.error as AppException : const UnexpectedResponseException();
    }
  }
}
