import 'package:career_buddy_lms/app/router/route_guards.dart';
import 'package:career_buddy_lms/app/router/route_paths.dart';
import 'package:career_buddy_lms/features/auth/domain/entities/auth_user.dart';
import 'package:career_buddy_lms/features/auth/presentation/controllers/auth_controller.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('computeRedirect', () {
    test('AuthUnknown sends any non-splash location to splash', () {
      expect(
        computeRedirect(authState: const AuthUnknown(), matchedLocation: RoutePaths.dashboard),
        RoutePaths.splash,
      );
      expect(
        computeRedirect(authState: const AuthUnknown(), matchedLocation: RoutePaths.splash),
        isNull,
      );
    });

    test('AuthUnauthenticated sends any non-public location to login', () {
      expect(
        computeRedirect(authState: const AuthUnauthenticated(), matchedLocation: RoutePaths.dashboard),
        RoutePaths.login,
      );
      expect(
        computeRedirect(authState: const AuthUnauthenticated(), matchedLocation: RoutePaths.login),
        isNull,
      );
    });

    test(
      'AuthUnauthenticated can reach the login screen\'s linked pre-login destinations '
      '(register / password reset / employer login) without being bounced to login',
      () {
        for (final route in [RoutePaths.register, RoutePaths.passwordReset, RoutePaths.employerLogin]) {
          expect(
            computeRedirect(authState: const AuthUnauthenticated(), matchedLocation: route),
            isNull,
            reason: '$route should be reachable while unauthenticated',
          );
        }
      },
    );

    test('AuthAuthenticated is pushed off splash/login/pre-login destinations onto the dashboard', () {
      const authenticated = AuthAuthenticated(AuthUser(username: 'jane'));
      expect(
        computeRedirect(authState: authenticated, matchedLocation: RoutePaths.login),
        RoutePaths.dashboard,
      );
      expect(
        computeRedirect(authState: authenticated, matchedLocation: RoutePaths.splash),
        RoutePaths.dashboard,
      );
      expect(
        computeRedirect(authState: authenticated, matchedLocation: RoutePaths.register),
        RoutePaths.dashboard,
      );
      expect(
        computeRedirect(authState: authenticated, matchedLocation: RoutePaths.dashboard),
        isNull,
      );
    });

    test('AuthRefreshing never redirects, so the current screen stays put mid-request', () {
      expect(
        computeRedirect(authState: const AuthRefreshing(), matchedLocation: RoutePaths.login),
        isNull,
      );
    });

    test('an unauthenticated user can reach the Direct Demo Entry route without being bounced to login', () {
      expect(
        computeRedirect(authState: const AuthUnauthenticated(), matchedLocation: RoutePaths.demoEntry),
        isNull,
      );
    });

    test('demoBypass:true skips every auth redirect, even while fully unauthenticated', () {
      expect(
        computeRedirect(
          authState: const AuthUnauthenticated(),
          matchedLocation: RoutePaths.activities,
          demoBypass: true,
        ),
        isNull,
      );
      expect(
        computeRedirect(
          authState: const AuthUnknown(),
          matchedLocation: RoutePaths.dashboard,
          demoBypass: true,
        ),
        isNull,
      );
    });

    test('demoBypass defaults to false, so ordinary callers are unaffected', () {
      expect(
        computeRedirect(authState: const AuthUnauthenticated(), matchedLocation: RoutePaths.activities),
        RoutePaths.login,
      );
    });

    test('Home (a universal route) is reachable while unauthenticated, without being bounced to login', () {
      expect(computeRedirect(authState: const AuthUnauthenticated(), matchedLocation: RoutePaths.home), isNull);
    });

    test('Home (a universal route) is reachable while authenticated too, without being bounced to the dashboard', () {
      const authenticated = AuthAuthenticated(AuthUser(username: 'jane'));
      expect(computeRedirect(authState: authenticated, matchedLocation: RoutePaths.home), isNull);
    });

    test('Employer Home is reachable by both auth states, same as Home', () {
      expect(
        computeRedirect(authState: const AuthUnauthenticated(), matchedLocation: RoutePaths.employerHome),
        isNull,
      );
      const employer = AuthAuthenticated(AuthUser(username: 'acme', isEmployer: true));
      expect(computeRedirect(authState: employer, matchedLocation: RoutePaths.employerHome), isNull);
    });

    test('an unauthenticated hit on an employer-protected route bounces to the employer login, not the student one', () {
      expect(
        computeRedirect(authState: const AuthUnauthenticated(), matchedLocation: RoutePaths.employerDashboard),
        RoutePaths.employerLogin,
      );
    });

    test('an authenticated employer landing on a pre-login/-splash route goes to the employer dashboard', () {
      const employer = AuthAuthenticated(AuthUser(username: 'acme', isEmployer: true));
      expect(computeRedirect(authState: employer, matchedLocation: RoutePaths.employerLogin), RoutePaths.employerDashboard);
      expect(computeRedirect(authState: employer, matchedLocation: RoutePaths.splash), RoutePaths.employerDashboard);
    });

    test('an authenticated non-employer still goes to the student dashboard, not the employer one', () {
      const student = AuthAuthenticated(AuthUser(username: 'jane'));
      expect(computeRedirect(authState: student, matchedLocation: RoutePaths.login), RoutePaths.dashboard);
    });

    // Batch 10 — cross-role access, confirmed as a real gap against the real
    // backend: `employer_dashboard()` (`jobs_app/views.py`) force-logs-out a
    // non-employer session, and `dashboard()` (`activities/views.py`)
    // redirects an employer session away — neither direction was previously
    // guarded once already authenticated (only the *unauthenticated* bounce
    // to the correct login screen was).
    test('an authenticated non-employer navigating to any employer-only route is bounced to their own dashboard', () {
      const student = AuthAuthenticated(AuthUser(username: 'jane'));
      for (final route in RoutePaths.employerProtectedRoutes) {
        expect(
          computeRedirect(authState: student, matchedLocation: route),
          RoutePaths.dashboard,
          reason: 'a student must never reach $route',
        );
      }
    });

    test('an authenticated employer navigating to the student dashboard is bounced to their own dashboard', () {
      const employer = AuthAuthenticated(AuthUser(username: 'acme', isEmployer: true));
      expect(computeRedirect(authState: employer, matchedLocation: RoutePaths.dashboard), RoutePaths.employerDashboard);
    });

    test('an authenticated employer can still reach employer-protected routes without a redirect loop', () {
      const employer = AuthAuthenticated(AuthUser(username: 'acme', isEmployer: true));
      for (final route in RoutePaths.employerProtectedRoutes) {
        expect(computeRedirect(authState: employer, matchedLocation: route), isNull);
      }
    });

    test('an authenticated non-employer can still reach their own dashboard without a redirect loop', () {
      const student = AuthAuthenticated(AuthUser(username: 'jane'));
      expect(computeRedirect(authState: student, matchedLocation: RoutePaths.dashboard), isNull);
    });

    test(
      'Resume Parsing/History are protected like every other career_app view '
      '(@login_required, no login_url override) — an unauthenticated hit bounces to the student login',
      () {
        for (final route in [RoutePaths.resumeBuilder, RoutePaths.resumeHistory]) {
          expect(
            computeRedirect(authState: const AuthUnauthenticated(), matchedLocation: route),
            RoutePaths.login,
            reason: '$route should redirect to student login while unauthenticated',
          );
        }
      },
    );

    test('an authenticated user reaches Resume Parsing/History without any redirect', () {
      const student = AuthAuthenticated(AuthUser(username: 'jane'));
      for (final route in [RoutePaths.resumeBuilder, RoutePaths.resumeHistory]) {
        expect(computeRedirect(authState: student, matchedLocation: route), isNull);
      }
    });
  });
}
