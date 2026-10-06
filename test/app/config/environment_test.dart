import 'dart:io' show Platform;

import 'package:career_buddy_lms/app/config/environment.dart';
import 'package:flutter_test/flutter_test.dart';

/// Batch 11/12 — release-readiness smoke tests for environment/backend-host
/// resolution. `Environment.current` is fixed by a compile-time
/// `--dart-define=ENV=...` for the whole test binary, so a single run can
/// only exercise whichever one value was passed to `flutter test`. This
/// file is deliberately run three separate ways (see
/// `docs/BATCH_12_PRODUCTION_RELEASE.md` for the exact commands and their
/// captured output) to prove all three real branches:
///   flutter test test/app/config/environment_test.dart                        (ENV unset → dev)
///   flutter test test/app/config/environment_test.dart --dart-define=ENV=staging
///   flutter test test/app/config/environment_test.dart --dart-define=ENV=production
///
/// Batch 12 update: `Environment.production` is now a positively-verified
/// real host (see `environment.dart`'s own doc comment) — the production
/// branch's test below was updated to assert the real verified URL,
/// replacing the old "throws, unconfigured" expectation, which is no
/// longer true and would be actively wrong to keep asserting.
void main() {
  const envName = String.fromEnvironment('ENV', defaultValue: 'dev');

  test('the current build\'s ENV resolves to the Environment this run expects', () {
    switch (envName) {
      case 'staging':
        expect(EnvironmentConfig.current, Environment.staging);
      case 'production':
        expect(EnvironmentConfig.current, Environment.production);
      default:
        expect(EnvironmentConfig.current, Environment.dev);
    }
  });

  switch (envName) {
    case 'staging':
      test('Environment.staging has no confirmed host yet — baseUrl throws a clear, actionable error, never a fabricated URL', () {
        expect(
          () => EnvironmentConfig.baseUrl,
          throwsA(
            isA<UnsupportedError>().having(
              (e) => e.message,
              'message',
              allOf(contains('Staging backend URL not configured'), isNot(contains('localhost')), isNot(contains('10.0.2.2'))),
            ),
          ),
        );
      });

    case 'production':
      test('Environment.production resolves to the real, positively-verified live backend (Batch 12) over HTTPS', () {
        final url = EnvironmentConfig.baseUrl;
        expect(url, 'https://careerbuddy4u.com');
        final uri = Uri.parse(url);
        expect(uri.scheme, 'https'); // never a downgraded/insecure production host
        expect(uri.host, isNot(anyOf('localhost', '127.0.0.1', '10.0.2.2'))); // never a leftover dev address
      });

    default:
      test('Environment.dev resolves to the real local dev-server convention for this platform, never a bare crash', () {
        final url = EnvironmentConfig.baseUrl;
        final expectedHost = Platform.isAndroid ? '10.0.2.2' : '127.0.0.1';
        expect(url, 'http://$expectedHost:8000');
      });

      test('dev never accidentally resolves to a non-loopback/emulator-alias address', () {
        final uri = Uri.parse(EnvironmentConfig.baseUrl);
        expect(uri.scheme, 'http'); // the real local Django dev server has no TLS cert
        expect(['10.0.2.2', '127.0.0.1'], contains(uri.host));
      });
  }

  group('release-mode guard (the ENV=production flag being forgotten on a real release build)', () {
    test('release=false never throws regardless of which ENV this test run was built with', () {
      expect(() => EnvironmentConfig.resolve(releaseMode: false), returnsNormally);
    });

    switch (envName) {
      case 'staging':
      case 'production':
        test('release=true does not throw once ENV is explicitly staging/production', () {
          expect(() => EnvironmentConfig.resolve(releaseMode: true), returnsNormally);
        });

      default:
        test('release=true throws a clear, actionable error when ENV defaulted to dev — the exact bug this guard exists to catch', () {
          expect(
            () => EnvironmentConfig.resolve(releaseMode: true),
            throwsA(
              isA<StateError>().having(
                (e) => e.message,
                'message',
                allOf(contains('ENV=production'), contains('10.0.2.2')),
              ),
            ),
          );
        });
    }
  });
}
