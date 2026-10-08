import 'package:dio/dio.dart';

import '../../../core/errors/exceptions.dart';
import '../../../core/network/api_client.dart';
import '../../../core/network/api_endpoints.dart';
import '../domain/entities/job_posting_submission.dart';

/// Talks to `ApiEndpoints.employerJobCreate` — see that constant's doc
/// comment for the full, live-production-verified field contract.
///
/// **Validation is deliberately NOT reimplemented client-side beyond basic
/// required-field prompts in the UI.** The live view's actual server-side
/// validation logic is not visible in the committed Django repository (the
/// repo's own `JobPostingForm` is a different, much smaller form — see
/// `ApiEndpoints.employerJobCreate`'s doc comment) and reverse-engineering
/// it by trial POSTs risks guessing a rule wrong. Every submission is sent
/// to the real endpoint; the server's own per-field `err_<field>` messages
/// (confirmed live, e.g. `id="err_salary_min"` -> `"Minimum Salary is
/// required."`) are parsed back verbatim and surfaced per-field, so the
/// app is never out of sync with whatever the production form actually
/// requires, including rules this task's own source/JS reading might have
/// missed.
class JobPostingRemoteDataSource {
  JobPostingRemoteDataSource(this._apiClient);

  final ApiClient _apiClient;

  /// Matches the live page's own error markup exactly:
  /// `<div class="text-danger small mt-1" id="err_<field>">message</div>`
  /// — confirmed directly against a real (deliberately incomplete, so
  /// nothing was created) production POST during this task. Distinct from
  /// `EmployerProfileRemoteDataSource`'s `errorlist`-based parser — this
  /// page does not use Django's default form error rendering.
  static final _fieldErrorPattern = RegExp(
    r'<div class="text-danger small mt-1" id="err_([a-z_]+)">\s*([^<]*?)\s*</div>',
  );

  Future<void> submit(JobPostingSubmission data) => _postJob(ApiEndpoints.employerJobCreate, data);

  /// `jobs_app.views.job_edit` — same 46-field contract as [submit], just
  /// POSTed to the edit URL instead (the live edit page's own `<form>` has
  /// no `action=`, i.e. it posts back to itself — confirmed live, job 68).
  /// See `ApiEndpoints.employerJobEdit`'s doc comment.
  Future<void> submitEdit(int jobId, JobPostingSubmission data) => _postJob(ApiEndpoints.employerJobEdit(jobId), data);

  Future<void> _postJob(String url, JobPostingSubmission data) async {
    try {
      await _apiClient.dio.get(url);
      final csrfToken = await _apiClient.readCookie('csrftoken');

      final response = await _apiClient.dio.post<String>(
        url,
        data: {
          'csrfmiddlewaretoken': csrfToken ?? '',
          'job_category': data.jobCategory,
          'job_classification': data.jobClassification,
          'department': data.department,
          'department_function': data.departmentFunction,
          'designation': data.designation,
          'industry_sector': data.industrySector,
          'title': data.title,
          'job_type': data.jobType,
          'contract_duration_months': data.contractDurationMonths,
          'employment_type': data.employmentType,
          'experience': data.experiencePreset,
          'experience_years': data.experienceYears,
          'experience_plus': data.experiencePlus ? 'True' : 'False',
          'experience_years_max': data.experienceYearsMax,
          'location': data.location,
          'education': data.educationPreset,
          'education_other': data.educationOther,
          'functional_skills': data.functionalSkills,
          'industry_experience': data.industryExperience,
          'working_hours': data.workingHours,
          'salary_format': data.salaryFormat,
          'salary_min': data.salaryMin,
          'salary_max': data.salaryMax,
          'openings': data.openings.toString(),
          'perks': data.perks,
          'description': data.description,
          'requirements': data.requirements,
          'responsibilities': data.responsibilities,
          'certifications': data.certifications,
          'software_skills': data.softwareSkills,
          'language_requirements': data.languageRequirements,
          'keywords': data.keywords,
          'application_contact': data.applicationContact,
          'skills': data.skills,
          // The real hidden `#id_mandatory_skills` input is a single
          // comma-joined string (`syncMandatorySkills`, `job_form.html`),
          // not a repeated field like `skills`/`perks`.
          'mandatory_skills': data.mandatorySkills.join(','),
          'deadline': data.deadline,
          'status': data.status,
          'work_environment': data.workEnvironment,
          'interview_mode': data.interviewMode,
          'interview_mode_other': data.interviewModeOther,
          'work_mode': data.workMode,
          'joining_requirement': data.joiningRequirement,
          'notice_period': data.noticePeriod,
          'notice_period_other': data.noticePeriodOther,
          'gender_preference': data.genderPreference,
          'age_limit': data.ageLimit,
        },
        options: Options(
          contentType: Headers.formUrlEncodedContentType,
          followRedirects: false,
          validateStatus: (_) => true,
          responseType: ResponseType.plain,
          headers: {'X-CSRFToken': csrfToken ?? ''},
        ),
      );

      if (response.statusCode == 302) return;
      if (response.statusCode == 200) {
        final body = response.data ?? '';
        final fieldErrors = <String, List<String>>{};
        for (final match in _fieldErrorPattern.allMatches(body)) {
          final field = match.group(1)!;
          final message = match.group(2)!.trim();
          if (message.isNotEmpty) fieldErrors[field] = [message];
        }
        if (fieldErrors.isEmpty) {
          // A 200 with no recognizable per-field error at all is still not
          // a success (no redirect happened) — surface a generic message
          // rather than silently treating it as if the job was posted.
          throw const ValidationException(
            {},
            'Could not post this job — please check your details and try again.',
          );
        }
        throw ValidationException(fieldErrors, 'Please check the highlighted fields.');
      }
      throw ServerException(response.statusCode);
    } on DioException catch (e) {
      throw e.error is AppException ? e.error as AppException : const UnexpectedResponseException();
    }
  }

  /// `jobs_app.views.job_edit`'s GET branch — scrapes the existing job's
  /// current values out of the rendered edit form (there is no JSON API),
  /// into the exact same [JobPostingSubmission] shape [submitEdit] sends
  /// back, so the Edit screen can reuse Post New Job's form/state wholesale
  /// just by seeding its controllers from this.
  ///
  /// **The `job_category` quirk** (confirmed live, job 68): unlike every
  /// other field, the top-level `job_category`/`job_classification`/
  /// `department`/`employment_type`/`education`/`joining_requirement`
  /// `<select>`s are rendered WITHOUT their stored value marked `selected`
  /// — only the blank placeholder option is. Every other field (every text
  /// input, `job_type`, `experience`, `salary_format`, `status`, every
  /// checkbox/radio) IS correctly echoed. Since `job_classification`/
  /// `department`/`employment_type`/`joining_requirement` are genuinely
  /// Non-IT-only fields (legitimately blank for an IT job, not a bug) and
  /// `education` is a plain optional field (plausibly just never set for
  /// that job), the one field this app cannot take at face value is
  /// `job_category` itself — required on every job, yet shown blank. This
  /// reconstructs it from evidence the response DOES contain: the
  /// `work_environment`/`interview_mode` radio groups only ever render
  /// (and only ever get a `checked` option) for an IT job, so a `checked`
  /// value in either means `'it'`; failing that, a selected
  /// `job_classification`/`employment_type`/`department` value (Non-IT-only
  /// fields) means `'non_it'`. This is read evidence already present in the
  /// same response, not an invented rule — if neither signal is present
  /// (e.g. a job whose IT/Non-IT-only fields are all genuinely blank),
  /// [JobPostingSubmission.jobCategory] comes back empty, same as
  /// [submit]'s own create-mode default, and the Edit screen's existing
  /// "Select a job category" required-field check applies unchanged.
  Future<JobPostingSubmission> getJobForEdit(int jobId) async {
    try {
      final response = await _apiClient.dio.get<String>(
        ApiEndpoints.employerJobEdit(jobId),
        options: Options(responseType: ResponseType.plain, validateStatus: (_) => true),
      );
      if (response.statusCode != 200) throw ServerException(response.statusCode);
      return _parseJobForm(response.data ?? '');
    } on DioException catch (e) {
      throw e.error is AppException ? e.error as AppException : const UnexpectedResponseException();
    }
  }

  static String _textValue(String html, String name) {
    final tag = RegExp('<input[^>]*\\bname="$name"[^>]*>').firstMatch(html)?.group(0);
    if (tag == null) return '';
    return RegExp(r'\bvalue="([^"]*)"').firstMatch(tag)?.group(1) ?? '';
  }

  static String _textareaValue(String html, String name) {
    final match = RegExp('<textarea[^>]*\\bname="$name"[^>]*>\\n?([\\s\\S]*?)</textarea>').firstMatch(html);
    return match?.group(1) ?? '';
  }

  static String _selectValue(String html, String name) {
    final block = RegExp('<select[^>]*\\bname="$name"[^>]*>([\\s\\S]*?)</select>').firstMatch(html)?.group(1);
    if (block == null) return '';
    final selected = RegExp(r'<option\s+value="([^"]*)"[^>]*\bselected\b').firstMatch(block);
    return selected?.group(1) ?? '';
  }

  static String _checkedRadioValue(String html, String name) {
    final match = RegExp('<input type="radio" name="$name" value="([^"]*)"[^>]*\\bchecked\\b').firstMatch(html);
    return match?.group(1) ?? '';
  }

  static List<String> _checkedCheckboxValues(String html, String name) {
    return [
      for (final m in RegExp('<input type="checkbox" name="$name" value="([^"]*)"[^>]*\\bchecked\\b').allMatches(html))
        m.group(1)!,
    ];
  }

  JobPostingSubmission _parseJobForm(String html) {
    final jobClassification = _selectValue(html, 'job_classification');
    final department = _selectValue(html, 'department');
    final employmentType = _selectValue(html, 'employment_type');

    var jobCategory = _selectValue(html, 'job_category');
    if (jobCategory.isEmpty) {
      final isItSignal =
          _checkedRadioValue(html, 'work_environment').isNotEmpty || _checkedRadioValue(html, 'interview_mode').isNotEmpty;
      final isNonItSignal = jobClassification.isNotEmpty || department.isNotEmpty || employmentType.isNotEmpty;
      if (isItSignal) {
        jobCategory = 'it';
      } else if (isNonItSignal) {
        jobCategory = 'non_it';
      }
    }

    final experiencePreset = _selectValue(html, 'experience');
    final educationPreset = _selectValue(html, 'education');

    return JobPostingSubmission(
      jobCategory: jobCategory,
      jobClassification: jobClassification,
      department: department,
      departmentFunction: _textValue(html, 'department_function'),
      designation: _selectValue(html, 'designation'),
      industrySector: _textValue(html, 'industry_sector'),
      title: _textValue(html, 'title'),
      jobType: _selectValue(html, 'job_type'),
      contractDurationMonths: _textValue(html, 'contract_duration_months'),
      employmentType: employmentType,
      experiencePreset: experiencePreset,
      experienceYears: _textValue(html, 'experience_years'),
      experiencePlus: _textValue(html, 'experience_plus') == 'True',
      experienceYearsMax: _textValue(html, 'experience_years_max'),
      location: _textValue(html, 'location'),
      educationPreset: educationPreset,
      educationOther: _textValue(html, 'education_other'),
      functionalSkills: _textValue(html, 'functional_skills'),
      industryExperience: _textValue(html, 'industry_experience'),
      workingHours: _textValue(html, 'working_hours'),
      salaryFormat: _selectValue(html, 'salary_format'),
      salaryMin: _textValue(html, 'salary_min'),
      salaryMax: _textValue(html, 'salary_max'),
      openings: int.tryParse(_textValue(html, 'openings')) ?? 1,
      perks: _checkedCheckboxValues(html, 'perks'),
      description: _textareaValue(html, 'description'),
      requirements: _textareaValue(html, 'requirements'),
      responsibilities: _textareaValue(html, 'responsibilities'),
      certifications: _textValue(html, 'certifications'),
      softwareSkills: _textValue(html, 'software_skills'),
      languageRequirements: _textValue(html, 'language_requirements'),
      keywords: _textValue(html, 'keywords'),
      applicationContact: _textValue(html, 'application_contact'),
      skills: _checkedCheckboxValues(html, 'skills'),
      // The hidden `#id_mandatory_skills` input is one comma-joined string
      // on the wire (see [_postJob]) — split it back out, dropping any
      // empty segment (an unset job renders this input with no value at
      // all, i.e. `''`, which must become `[]`, not `['']`).
      mandatorySkills: _textValue(html, 'mandatory_skills').split(',').where((s) => s.isNotEmpty).toList(),
      deadline: _textValue(html, 'deadline'),
      status: _selectValue(html, 'status'),
      workEnvironment: _checkedRadioValue(html, 'work_environment'),
      interviewMode: _checkedRadioValue(html, 'interview_mode'),
      interviewModeOther: _textValue(html, 'interview_mode_other'),
      workMode: _selectValue(html, 'work_mode'),
      joiningRequirement: _selectValue(html, 'joining_requirement'),
      noticePeriod: _checkedRadioValue(html, 'notice_period'),
      noticePeriodOther: _textValue(html, 'notice_period_other'),
      genderPreference: _checkedRadioValue(html, 'gender_preference'),
      ageLimit: _textValue(html, 'age_limit'),
    );
  }
}
