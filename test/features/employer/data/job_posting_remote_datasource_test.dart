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
}
