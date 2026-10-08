import 'dart:io';

import 'package:career_buddy_lms/core/errors/exceptions.dart';
import 'package:career_buddy_lms/core/network/api_client.dart';
import 'package:career_buddy_lms/features/employer/data/job_posting_remote_datasource.dart';
import 'package:career_buddy_lms/features/employer/domain/entities/job_posting_submission.dart';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../support/fake_http_client_adapter.dart';

const _submission = JobPostingSubmission(
  jobCategory: 'it',
  jobClassification: '',
  department: '',
  departmentFunction: '',
  designation: '',
  industrySector: '',
  title: 'Senior Flutter Developer',
  jobType: 'full_time',
  contractDurationMonths: '',
  employmentType: '',
  experiencePreset: '3-5',
  experienceYears: '',
  experiencePlus: false,
  experienceYearsMax: '',
  location: 'Hyderabad',
  educationPreset: '',
  educationOther: '',
  functionalSkills: '',
  industryExperience: '',
  workingHours: '',
  salaryFormat: 'monthly',
  salaryMin: '30000',
  salaryMax: '50000',
  openings: 2,
  perks: ['laptop', 'health_insurance'],
  description: 'Build and ship mobile features.',
  requirements: '',
  responsibilities: '',
  certifications: '',
  softwareSkills: '',
  languageRequirements: '',
  keywords: '',
  applicationContact: '',
  skills: ['Communication', 'Problem Solving', 'Leadership'],
  mandatorySkills: ['Communication', 'Problem Solving', 'Leadership'],
  deadline: '',
  status: 'active',
  workEnvironment: 'wfo',
  interviewMode: 'virtual',
  interviewModeOther: '',
  workMode: '',
  joiningRequirement: '',
  noticePeriod: 'immediate',
  noticePeriodOther: '',
  genderPreference: 'both',
  ageLimit: '',
);

void main() {
  group('JobPostingRemoteDataSource.submit', () {
    test('completes without throwing on a real 302 (redirect-on-success)', () async {
      final dio = Dio(BaseOptions(baseUrl: 'https://example.test'))
        ..httpClientAdapter = GetPrimesCsrfAdapter(postStatusCode: 302);
      final datasource = JobPostingRemoteDataSource(ApiClient.forTesting(dio));

      await expectLater(datasource.submit(_submission), completes);
    });

    test('throws ValidationException with every per-field error parsed from a 200 (form re-rendered with errors)', () async {
      const body = '''
        <div class="text-danger small mt-1" id="err_job_category">Select a job category.</div>
        <div class="text-danger small mt-1" id="err_title"></div>
        <div class="text-danger small mt-1" id="err_salary_min">Minimum Salary is required.</div>
      ''';
      final dio = Dio(BaseOptions(baseUrl: 'https://example.test'))
        ..httpClientAdapter = GetPrimesCsrfAdapter(postStatusCode: 200, postBody: body);
      final datasource = JobPostingRemoteDataSource(ApiClient.forTesting(dio));

      await expectLater(
        datasource.submit(_submission),
        throwsA(
          isA<ValidationException>()
              .having((e) => e.fieldErrors['job_category'], 'job_category error', ['Select a job category.'])
              .having((e) => e.fieldErrors['salary_min'], 'salary_min error', ['Minimum Salary is required.'])
              .having((e) => e.fieldErrors.containsKey('title'), 'empty err_title div is not a reported error', isFalse),
        ),
      );
    });

    test('throws a generic ValidationException when the 200 response has no recognizable field error at all', () async {
      final dio = Dio(BaseOptions(baseUrl: 'https://example.test'))
        ..httpClientAdapter = GetPrimesCsrfAdapter(postStatusCode: 200, postBody: '<html>something unexpected</html>');
      final datasource = JobPostingRemoteDataSource(ApiClient.forTesting(dio));

      await expectLater(
        datasource.submit(_submission),
        throwsA(isA<ValidationException>().having((e) => e.fieldErrors, 'fieldErrors', isEmpty)),
      );
    });

    test('throws ServerException on an unexpected status code', () async {
      final dio = Dio(BaseOptions(baseUrl: 'https://example.test'))
        ..httpClientAdapter = GetPrimesCsrfAdapter(postStatusCode: 500);
      final datasource = JobPostingRemoteDataSource(ApiClient.forTesting(dio));

      await expectLater(datasource.submit(_submission), throwsA(isA<ServerException>()));
    });
  });

  group('JobPostingRemoteDataSource.submitEdit', () {
    test('posts to the edit URL (not the create one) and completes on a real 302', () async {
      RequestOptions? captured;
      final dio = Dio(BaseOptions(baseUrl: 'https://example.test'))
        ..httpClientAdapter = GetPrimesCsrfAdapter(postStatusCode: 302, onPostRequest: (o) => captured = o);
      final datasource = JobPostingRemoteDataSource(ApiClient.forTesting(dio));

      await expectLater(datasource.submitEdit(68, _submission), completes);
      expect(captured!.path, contains('/employer/employer/jobs/68/edit/'));
    });

    test('throws ValidationException with per-field errors parsed from a 200, same as submit', () async {
      const body = '<div class="text-danger small mt-1" id="err_title">This field is required.</div>';
      final dio = Dio(BaseOptions(baseUrl: 'https://example.test'))
        ..httpClientAdapter = GetPrimesCsrfAdapter(postStatusCode: 200, postBody: body);
      final datasource = JobPostingRemoteDataSource(ApiClient.forTesting(dio));

      await expectLater(
        datasource.submitEdit(68, _submission),
        throwsA(isA<ValidationException>().having((e) => e.fieldErrors['title'], 'title error', ['This field is required.'])),
      );
    });
  });

  group('JobPostingRemoteDataSource.getJobForEdit', () {
    late String fixtureHtml;

    setUpAll(() {
      fixtureHtml = File('test/fixtures/job_edit_form_job68.html').readAsStringSync();
    });

    test('parses an existing job\'s current values from its real Edit page (job 68, confirmed live)', () async {
      final dio = Dio(BaseOptions(baseUrl: 'https://example.test'))
        ..httpClientAdapter = FakeHttpClientAdapter(statusCode: 200, body: fixtureHtml);
      final datasource = JobPostingRemoteDataSource(ApiClient.forTesting(dio));

      final job = await datasource.getJobForEdit(68);

      expect(job.title, 'senior python developer');
      expect(job.jobType, 'full_time');
      expect(job.experiencePreset, '5-8');
      expect(job.salaryFormat, 'monthly');
      expect(job.salaryMin, '4.00');
      expect(job.openings, 10);
      expect(job.skills, containsAll(['python', 'django', 'html', 'css', 'javascript.']));
      expect(job.perks, isEmpty);
      // The hidden `#id_mandatory_skills` input has no `value` at all for
      // this job — must become `[]`, not `['']`.
      expect(job.mandatorySkills, isEmpty);
      expect(job.status, 'active');
      expect(job.workEnvironment, 'wfo');
      expect(job.interviewMode, 'virtual');
      expect(job.deadline, '2026-08-25');
      // The `job_category` quirk: the real page's own `<select
      // name="job_category">` is NOT rendered with `it` marked `selected`
      // (confirmed live) — this must still come back `'it'`, inferred from
      // the checked `work_environment`/`interview_mode` radios, not left
      // blank just because the `<select>` itself says so.
      expect(job.jobCategory, 'it');
      // Non-IT-only fields are legitimately blank for this IT job — not a
      // bug, nothing to infer here.
      expect(job.jobClassification, '');
      expect(job.department, '');
      expect(job.employmentType, '');
    });

    test('throws ServerException on a non-200 response (e.g. a job not owned by this employer)', () async {
      final dio = Dio(BaseOptions(baseUrl: 'https://example.test'))
        ..httpClientAdapter = FakeHttpClientAdapter(statusCode: 404, body: '');
      final datasource = JobPostingRemoteDataSource(ApiClient.forTesting(dio));

      await expectLater(datasource.getJobForEdit(999999), throwsA(isA<ServerException>()));
    });

    test('jobCategory comes back empty when neither IT nor Non-IT signal is present, same as submit\'s own create-mode default', () async {
      const html = '''
        <input type="text" name="title" value="untitled" id="id_title">
        <select name="job_category" id="id_job_category"><option value="" selected>Select a category</option></select>
      ''';
      final dio = Dio(BaseOptions(baseUrl: 'https://example.test'))
        ..httpClientAdapter = FakeHttpClientAdapter(statusCode: 200, body: html);
      final datasource = JobPostingRemoteDataSource(ApiClient.forTesting(dio));

      final job = await datasource.getJobForEdit(1);

      expect(job.jobCategory, '');
    });
  });
}
