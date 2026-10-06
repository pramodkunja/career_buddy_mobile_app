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

  Future<void> submit(JobPostingSubmission data) async {
    try {
      await _apiClient.dio.get(ApiEndpoints.employerJobCreate);
      final csrfToken = await _apiClient.readCookie('csrftoken');

      final response = await _apiClient.dio.post<String>(
        ApiEndpoints.employerJobCreate,
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
}
