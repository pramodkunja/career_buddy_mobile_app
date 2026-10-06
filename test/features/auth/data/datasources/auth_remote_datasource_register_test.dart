import 'dart:io';

import 'package:career_buddy_lms/core/errors/exceptions.dart';
import 'package:career_buddy_lms/core/network/api_client.dart';
import 'package:career_buddy_lms/features/auth/data/datasources/auth_remote_datasource.dart';
import 'package:career_buddy_lms/features/auth/domain/entities/student_registration_data.dart';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../../support/fake_http_client_adapter.dart';

/// Phase 1 (web-to-Flutter conversion) — student registration
/// (`users/views.py:register_view`) has no JSON API; these tests exercise
/// the same 302-success/200-failure contract already proven for login and
/// employer registration.
void main() {
  group('sendOtp / verifyOtp', () {
    test('sendOtp returns the server message on a real success response', () async {
      final dio = Dio(BaseOptions(baseUrl: 'https://example.test'))
        ..httpClientAdapter = FakeHttpClientAdapter(
          statusCode: 200,
          body: '{"ok": true, "message": "Code sent."}',
          headers: {'content-type': ['application/json']},
        );
      final datasource = AuthRemoteDataSource(ApiClient.forTesting(dio));

      expect(await datasource.sendOtp('user@example.com'), 'Code sent.');
    });

    test('sendOtp throws RateLimitException on a 429', () async {
      final dio = Dio(BaseOptions(baseUrl: 'https://example.test'))
        ..httpClientAdapter = GetPrimesCsrfAdapter(postStatusCode: 429, postBody: '{"error": "Too many attempts."}');
      final datasource = AuthRemoteDataSource(ApiClient.forTesting(dio));

      await expectLater(datasource.sendOtp('user@example.com'), throwsA(isA<RateLimitException>()));
    });

    test('verifyOtp throws ValidationException on an incorrect code', () async {
      final dio = Dio(BaseOptions(baseUrl: 'https://example.test'))
        ..httpClientAdapter = FakeHttpClientAdapter(
          statusCode: 200,
          body: '{"ok": false, "error": "Incorrect code."}',
          headers: {'content-type': ['application/json']},
        );
      final datasource = AuthRemoteDataSource(ApiClient.forTesting(dio));

      await expectLater(
        datasource.verifyOtp(email: 'user@example.com', code: '000000'),
        throwsA(isA<ValidationException>()),
      );
    });
  });

  group('register', () {
    late File tempResume;

    setUp(() async {
      tempResume = File('${Directory.systemTemp.path}/test_resume.pdf');
      await tempResume.writeAsBytes([0x25, 0x50, 0x44, 0x46]); // "%PDF"
    });

    tearDown(() async {
      if (await tempResume.exists()) await tempResume.delete();
    });

    StudentRegistrationData buildData() => StudentRegistrationData(
      firstName: 'Test',
      lastName: 'User',
      email: 'test@example.com',
      username: 'testuser',
      password: 'Aa1!aaaa',
      passwordConfirm: 'Aa1!aaaa',
      aadharNumber: '123456789012',
      resumeFilePath: tempResume.path,
      resumeFileName: 'test_resume.pdf',
    );

    test('returns the username on a real 302 (redirect-on-success)', () async {
      final dio = Dio(BaseOptions(baseUrl: 'https://example.test'))
        ..httpClientAdapter = GetPrimesCsrfAdapter(postStatusCode: 302);
      final datasource = AuthRemoteDataSource(ApiClient.forTesting(dio));

      expect(await datasource.register(buildData()), 'testuser');
    });

    test('throws ValidationException on a 200 (form re-rendered with errors)', () async {
      final dio = Dio(BaseOptions(baseUrl: 'https://example.test'))
        ..httpClientAdapter = FakeHttpClientAdapter(statusCode: 200, body: '<html></html>');
      final datasource = AuthRemoteDataSource(ApiClient.forTesting(dio));

      await expectLater(datasource.register(buildData()), throwsA(isA<ValidationException>()));
    });
  });
}
