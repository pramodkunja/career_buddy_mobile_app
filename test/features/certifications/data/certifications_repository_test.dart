import 'dart:convert';

import 'package:career_buddy_lms/core/errors/failures.dart';
import 'package:career_buddy_lms/core/network/api_client.dart';
import 'package:career_buddy_lms/core/network/api_exceptions_interceptor.dart';
import 'package:career_buddy_lms/core/utils/result.dart';
import 'package:career_buddy_lms/features/certifications/data/datasources/certifications_remote_datasource.dart';
import 'package:career_buddy_lms/features/certifications/data/repositories/certifications_repository_impl.dart';
import 'package:career_buddy_lms/features/certifications/domain/entities/certification_state.dart';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../support/fake_http_client_adapter.dart';

const _jsonHeaders = {
  'content-type': ['application/json'],
};

const _validStatusBody = {
  'categories': <Map<String, dynamic>>[],
  'total_count': 0,
  'attempted_count': 0,
  'earned_count': 0,
};

const _generateSuccessBody = {
  'subject': {
    'subject': 'python',
    'label': 'Python',
    'category': 'tech',
    'state': 'certified',
    'pass_threshold': 70,
    'result': {'score': 18, 'total': 20, 'completed': true},
    'certificate': {
      'certificate_name': 'Jane Doe',
      'score': 18,
      'total': 20,
      'certificate_number': 'CB-PYTHON-0001',
      'generated_at': '2026-09-20T10:15:00Z',
      'download_url': '/skill-up/assessment/python/certificate/download/',
      'edit_url': '/skill-up/assessment/python/certificate/edit/',
    },
    'prefill_name': 'Jane Doe',
    'name_url': '/skill-up/assessment/python/certificate/name/',
  },
};

CertificationsRepositoryImpl _repoReturning({
  required int statusCode,
  required String body,
  Map<String, List<String>>? headers,
}) {
  final dio = Dio(BaseOptions(baseUrl: 'http://test'))
    ..httpClientAdapter = FakeHttpClientAdapter(statusCode: statusCode, body: body, headers: headers)
    ..interceptors.add(ApiExceptionsInterceptor());
  return CertificationsRepositoryImpl(CertificationsRemoteDataSource(ApiClient.forTesting(dio)));
}

void main() {
  group('CertificationsRepositoryImpl.getStatus', () {
    test('returns Success with the parsed status on a valid 200 response', () async {
      final repo = _repoReturning(statusCode: 200, body: jsonEncode(_validStatusBody), headers: _jsonHeaders);

      final result = await repo.getStatus();

      expect(result, isA<Success>());
      expect((result as Success).value.totalCount, 0);
    });

    test('returns Failed with a NotFoundFailure when the endpoint 404s', () async {
      final repo = _repoReturning(statusCode: 404, body: '');

      final result = await repo.getStatus();

      expect(result, isA<Failed>());
      expect((result as Failed).failure, isA<NotFoundFailure>());
    });

    test('returns Failed with UnexpectedFailure when the body is not valid JSON (e.g. a login redirect page)', () async {
      final repo = _repoReturning(statusCode: 200, body: '<html>login</html>');

      final result = await repo.getStatus();

      expect(result, isA<Failed>());
      expect((result as Failed).failure, isA<UnexpectedFailure>());
    });
  });

  group('CertificationsRepositoryImpl.generateCertificate', () {
    test('returns Success with the freshly updated subject on a valid response', () async {
      final repo = _repoReturning(statusCode: 200, body: jsonEncode(_generateSuccessBody), headers: _jsonHeaders);

      final result = await repo.generateCertificate(subject: 'python', name: 'Jane Doe');

      expect(result, isA<Success>());
      final subject = (result as Success).value;
      expect(subject.subject, 'python');
      expect(subject.state, CertificationState.certified);
      expect(subject.certificate?.certificateNumber, 'CB-PYTHON-0001');
    });

    test('returns Failed with a ForbiddenFailure when the subject is not eligible (403)', () async {
      final repo = _repoReturning(
        statusCode: 403,
        body: jsonEncode({'error': 'A Mock Test score of 70% or higher is required.'}),
        headers: _jsonHeaders,
      );

      final result = await repo.generateCertificate(subject: 'python', name: 'Jane Doe');

      expect(result, isA<Failed>());
      expect((result as Failed).failure, isA<ForbiddenFailure>());
    });
  });

  group('CertificationsRepositoryImpl.regenerateCertificate', () {
    test('returns Success with the updated subject on a valid response', () async {
      final repo = _repoReturning(statusCode: 200, body: jsonEncode(_generateSuccessBody), headers: _jsonHeaders);

      final result = await repo.regenerateCertificate(subject: 'python', name: 'Jane D.');

      expect(result, isA<Success>());
    });
  });

  group('CertificationsRepositoryImpl.downloadCertificateBytes', () {
    test('returns Success with the raw PDF bytes on a valid response', () async {
      final repo = _repoReturning(statusCode: 200, body: 'fake-pdf-bytes');

      final result = await repo.downloadCertificateBytes('python');

      expect(result, isA<Success>());
      expect(utf8.decode((result as Success).value), 'fake-pdf-bytes');
    });

    test('returns Failed with a NotFoundFailure when no certificate exists yet (404)', () async {
      final repo = _repoReturning(statusCode: 404, body: '');

      final result = await repo.downloadCertificateBytes('python');

      expect(result, isA<Failed>());
      expect((result as Failed).failure, isA<NotFoundFailure>());
    });
  });
}
