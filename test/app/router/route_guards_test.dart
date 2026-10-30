import 'package:career_buddy_lms/app/router/route_guards.dart';
import 'package:career_buddy_lms/app/router/route_paths.dart';
import 'package:career_buddy_lms/features/auth/domain/entities/auth_user.dart';
import 'package:career_buddy_lms/features/auth/presentation/controllers/auth_controller.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('computeRedirect', () {
    test('AuthUnknown sends any non-splash location to splash', () {
      expect(
        computeRedirect(
          authState: const AuthUnknown(),
          matchedLocation: RoutePaths.dashboard,
        ),
        RoutePaths.splash,
      );
      expect(
        computeRedirect(
          authState: const AuthUnknown(),
          matchedLocation: RoutePaths.splash,
        ),
        isNull,
      );
    });

    // Phase 3 — Subscription. `RoutePaths.pro` is deliberately not in
    // `publicRoutes`/`universalRoutes`/`employerProtectedRoutes` — matches
    // the real backend's `@login_required` on `pro_page`/
    // `create_razorpay_order`/`verify_razorpay_payment` (confirmed in
    // `docs/PHASE_3_SUBSCRIPTION_DISCOVERY.md` §1). Explicit test (not just
    // relying on the generic "any non-public location" case below) since
    // this route newly carries real payment functionality.
    test(
      'an unauthenticated hit on the Subscription screen bounces to the student login',
      () {
        expect(
          computeRedirect(
            authState: const AuthUnauthenticated(),
            matchedLocation: RoutePaths.pro,
          ),
          RoutePaths.login,
        );
      },
    );

    test(
      'an authenticated user (either role) reaches the Subscription screen without any redirect',
      () {
        const student = AuthAuthenticated(AuthUser(username: 'jane'));
        const employer = AuthAuthenticated(
          AuthUser(username: 'acme', isEmployer: true),
        );
        expect(
          computeRedirect(authState: student, matchedLocation: RoutePaths.pro),
          isNull,
        );
        expect(
          computeRedirect(authState: employer, matchedLocation: RoutePaths.pro),
          isNull,
        );
      },
    );

    test('AuthUnauthenticated sends any non-public location to login', () {
      expect(
        computeRedirect(
          authState: const AuthUnauthenticated(),
          matchedLocation: RoutePaths.dashboard,
        ),
        RoutePaths.login,
      );
      expect(
        computeRedirect(
          authState: const AuthUnauthenticated(),
          matchedLocation: RoutePaths.login,
        ),
        isNull,
      );
    });

    // Phase 2 — Home entry routing. Matches the real web's own `/`
    // (`activities/views.py:76 home()`), which serves the same combined
    // Employer/Job Seeker landing page to every logged-out visitor instead
    // of bouncing them straight to a login form. Before this fix, splash
    // fell through to the generic "any non-public location" branch above
    // and redirected to [RoutePaths.login] like any other unlisted route.
    test('AuthUnauthenticated at splash is redirected to Home, not login', () {
      expect(
        computeRedirect(
          authState: const AuthUnauthenticated(),
          matchedLocation: RoutePaths.splash,
        ),
        RoutePaths.home,
      );
    });

    test(
      'AuthUnauthenticated redirected from splash to Home does not then bounce back off Home',
      () {
        // The router re-runs `computeRedirect` for the new location after a
        // redirect; confirms no redirect loop between splash and Home for an
        // unauthenticated session (Home is a universal route — see the
        // existing 'Home (a universal route) is reachable while
        // unauthenticated' test below for the direct version of this check).
        final redirected = computeRedirect(
          authState: const AuthUnauthenticated(),
          matchedLocation: RoutePaths.splash,
        );
        expect(
          computeRedirect(
            authState: const AuthUnauthenticated(),
            matchedLocation: redirected!,
          ),
          isNull,
        );
      },
    );

    test(
      'AuthUnauthenticated can reach the login screen\'s linked pre-login destinations '
      '(register / password reset / employer login) without being bounced to login',
      () {
        for (final route in [
          RoutePaths.register,
          RoutePaths.passwordReset,
          RoutePaths.employerLogin,
        ]) {
          expect(
            computeRedirect(
              authState: const AuthUnauthenticated(),
              matchedLocation: route,
            ),
            isNull,
            reason: '$route should be reachable while unauthenticated',
          );
        }
      },
    );

    test(
      'AuthAuthenticated is pushed off splash/login/pre-login destinations onto the dashboard',
      () {
        const authenticated = AuthAuthenticated(AuthUser(username: 'jane'));
        expect(
          computeRedirect(
            authState: authenticated,
            matchedLocation: RoutePaths.login,
          ),
          RoutePaths.dashboard,
        );
        expect(
          computeRedirect(
            authState: authenticated,
            matchedLocation: RoutePaths.splash,
          ),
          RoutePaths.dashboard,
        );
        expect(
          computeRedirect(
            authState: authenticated,
            matchedLocation: RoutePaths.register,
          ),
          RoutePaths.dashboard,
        );
        expect(
          computeRedirect(
            authState: authenticated,
            matchedLocation: RoutePaths.dashboard,
          ),
          isNull,
        );
      },
    );

    test(
      'AuthRefreshing never redirects, so the current screen stays put mid-request',
      () {
        expect(
          computeRedirect(
            authState: const AuthRefreshing(),
            matchedLocation: RoutePaths.login,
          ),
          isNull,
        );
      },
    );

    test(
      'an unauthenticated user can reach the Direct Demo Entry route without being bounced to login',
      () {
        expect(
          computeRedirect(
            authState: const AuthUnauthenticated(),
            matchedLocation: RoutePaths.demoEntry,
          ),
          isNull,
        );
      },
    );

    test(
      'demoBypass:true skips every auth redirect, even while fully unauthenticated',
      () {
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
      },
    );

    test(
      'demoBypass defaults to false, so ordinary callers are unaffected',
      () {
        expect(
          computeRedirect(
            authState: const AuthUnauthenticated(),
            matchedLocation: RoutePaths.activities,
          ),
          RoutePaths.login,
        );
      },
    );

    test(
      'Home (a universal route) is reachable while unauthenticated, without being bounced to login',
      () {
        expect(
          computeRedirect(
            authState: const AuthUnauthenticated(),
            matchedLocation: RoutePaths.home,
          ),
          isNull,
        );
      },
    );

    test(
      'Home (a universal route) is reachable while authenticated too, without being bounced to the dashboard',
      () {
        const authenticated = AuthAuthenticated(AuthUser(username: 'jane'));
        expect(
          computeRedirect(
            authState: authenticated,
            matchedLocation: RoutePaths.home,
          ),
          isNull,
        );
      },
    );

    test('Employer Home is reachable by both auth states, same as Home', () {
      expect(
        computeRedirect(
          authState: const AuthUnauthenticated(),
          matchedLocation: RoutePaths.employerHome,
        ),
        isNull,
      );
      const employer = AuthAuthenticated(
        AuthUser(username: 'acme', isEmployer: true),
      );
      expect(
        computeRedirect(
          authState: employer,
          matchedLocation: RoutePaths.employerHome,
        ),
        isNull,
      );
    });

    test(
      'an unauthenticated hit on an employer-protected route bounces to the employer login, not the student one',
      () {
        expect(
          computeRedirect(
            authState: const AuthUnauthenticated(),
            matchedLocation: RoutePaths.employerDashboard,
          ),
          RoutePaths.employerLogin,
        );
      },
    );

    test(
      'an authenticated employer landing on a pre-login/-splash route goes to the employer dashboard',
      () {
        const employer = AuthAuthenticated(
          AuthUser(username: 'acme', isEmployer: true),
        );
        expect(
          computeRedirect(
            authState: employer,
            matchedLocation: RoutePaths.employerLogin,
          ),
          RoutePaths.employerDashboard,
        );
        expect(
          computeRedirect(
            authState: employer,
            matchedLocation: RoutePaths.splash,
          ),
          RoutePaths.employerDashboard,
        );
      },
    );

    test(
      'an authenticated non-employer still goes to the student dashboard, not the employer one',
      () {
        const student = AuthAuthenticated(AuthUser(username: 'jane'));
        expect(
          computeRedirect(
            authState: student,
            matchedLocation: RoutePaths.login,
          ),
          RoutePaths.dashboard,
        );
      },
    );

    // Batch 10 — cross-role access, confirmed as a real gap against the real
    // backend: `employer_dashboard()` (`jobs_app/views.py`) force-logs-out a
    // non-employer session, and `dashboard()` (`activities/views.py`)
    // redirects an employer session away — neither direction was previously
    // guarded once already authenticated (only the *unauthenticated* bounce
    // to the correct login screen was).
    test(
      'an authenticated non-employer navigating to any employer-only route is bounced to their own dashboard',
      () {
        const student = AuthAuthenticated(AuthUser(username: 'jane'));
        for (final route in RoutePaths.employerProtectedRoutes) {
          expect(
            computeRedirect(authState: student, matchedLocation: route),
            RoutePaths.dashboard,
            reason: 'a student must never reach $route',
          );
        }
      },
    );

    test(
      'an authenticated employer navigating to the student dashboard is bounced to their own dashboard',
      () {
        const employer = AuthAuthenticated(
          AuthUser(username: 'acme', isEmployer: true),
        );
        expect(
          computeRedirect(
            authState: employer,
            matchedLocation: RoutePaths.dashboard,
          ),
          RoutePaths.employerDashboard,
        );
      },
    );

    test(
      'an authenticated employer can still reach employer-protected routes without a redirect loop',
      () {
        const employer = AuthAuthenticated(
          AuthUser(username: 'acme', isEmployer: true),
        );
        for (final route in RoutePaths.employerProtectedRoutes) {
          expect(
            computeRedirect(authState: employer, matchedLocation: route),
            isNull,
          );
        }
      },
    );

    test(
      'an authenticated non-employer can still reach their own dashboard without a redirect loop',
      () {
        const student = AuthAuthenticated(AuthUser(username: 'jane'));
        expect(
          computeRedirect(
            authState: student,
            matchedLocation: RoutePaths.dashboard,
          ),
          isNull,
        );
      },
    );

    test(
      'Resume Parsing/History are protected like every other career_app view '
      '(@login_required, no login_url override) — an unauthenticated hit bounces to the student login',
      () {
        for (final route in [
          RoutePaths.resumeBuilder,
          RoutePaths.resumeHistory,
        ]) {
          expect(
            computeRedirect(
              authState: const AuthUnauthenticated(),
              matchedLocation: route,
            ),
            RoutePaths.login,
            reason:
                '$route should redirect to student login while unauthenticated',
          );
        }
      },
    );

    test(
      'an authenticated user reaches Resume Parsing/History without any redirect',
      () {
        const student = AuthAuthenticated(AuthUser(username: 'jane'));
        for (final route in [
          RoutePaths.resumeBuilder,
          RoutePaths.resumeHistory,
        ]) {
          expect(
            computeRedirect(authState: student, matchedLocation: route),
            isNull,
          );
        }
      },
    );

    // Phase 1 Critical Fixes — Job Seeker Job Openings navigation. Unlike
    // every other `RoutePaths.employerJobOpenings`-shaped route, the real
    // backend view behind it is plain `@login_required` with no
    // employer-portal-session check (confirmed live) — so, unlike the rest
    // of `employerProtectedRoutes`, it must NOT bounce a non-employer
    // session away, and an unauthenticated hit must land on the student
    // login (matching `@login_required`'s default), not the employer one.
    test(
      'employerJobOpenings is reachable by an authenticated non-employer session, unlike every other employer-protected route',
      () {
        const student = AuthAuthenticated(AuthUser(username: 'jane'));
        expect(
          computeRedirect(
            authState: student,
            matchedLocation: RoutePaths.employerJobOpenings,
          ),
          isNull,
        );
      },
    );

    test(
      'employerJobOpenings is reachable by an authenticated employer session too',
      () {
        const employer = AuthAuthenticated(
          AuthUser(username: 'acme', isEmployer: true),
        );
        expect(
          computeRedirect(
            authState: employer,
            matchedLocation: RoutePaths.employerJobOpenings,
          ),
          isNull,
        );
      },
    );

    test(
      'an unauthenticated hit on employerJobOpenings bounces to the student login, not the employer one',
      () {
        expect(
          computeRedirect(
            authState: const AuthUnauthenticated(),
            matchedLocation: RoutePaths.employerJobOpenings,
          ),
          RoutePaths.login,
        );
      },
    );

    test('employerJobOpenings is not a member of employerProtectedRoutes', () {
      expect(
        RoutePaths.employerProtectedRoutes.contains(
          RoutePaths.employerJobOpenings,
        ),
        isFalse,
      );
    });

    // Phase 30 — the Phase 29 audit found that, while `computeRedirect`'s
    // "any non-public/non-universal route redirects an unauthenticated
    // session to login" rule is already covered generically (using
    // `RoutePaths.dashboard` as the example above), no test named the three
    // Manual Resume Builder routes specifically. The real backend endpoints
    // these screens call (`manual_resume_preview`/`manual_resume_pages`/
    // `manual_resume_pdf`) require no login at all (Phase 24 audit) — this
    // app's own, deliberate decision to gate them behind authentication
    // anyway (Phase 25/27/28) is exactly the kind of app-only restriction
    // that deserves its own named regression test, not just incidental
    // coverage from an unrelated route's example.
    group('Manual Resume Builder routes', () {
      const manualResumeRoutes = [
        RoutePaths.manualResumeBuilder,
        RoutePaths.manualResumePreview,
        RoutePaths.manualResumePagePreview,
      ];

      test('none of them are public or universal routes', () {
        for (final route in manualResumeRoutes) {
          expect(
            RoutePaths.publicRoutes.contains(route),
            isFalse,
            reason: '$route must not be public',
          );
          expect(
            RoutePaths.universalRoutes.contains(route),
            isFalse,
            reason: '$route must not be universal',
          );
        }
      });

      test(
        'an unauthenticated hit on any of them bounces to the student login',
        () {
          for (final route in manualResumeRoutes) {
            expect(
              computeRedirect(
                authState: const AuthUnauthenticated(),
                matchedLocation: route,
              ),
              RoutePaths.login,
              reason:
                  '$route should redirect an unauthenticated session to login',
            );
          }
        },
      );

      test(
        'an authenticated session reaches all of them without any redirect',
        () {
          const authenticated = AuthAuthenticated(AuthUser(username: 'jane'));
          for (final route in manualResumeRoutes) {
            expect(
              computeRedirect(authState: authenticated, matchedLocation: route),
              isNull,
              reason:
                  '$route should be reachable while authenticated, with no redirect',
            );
          }
        },
      );

      test(
        'an authenticated employer session reaches all of them too, same as a student session',
        () {
          const employer = AuthAuthenticated(
            AuthUser(username: 'acme', isEmployer: true),
          );
          for (final route in manualResumeRoutes) {
            expect(
              computeRedirect(authState: employer, matchedLocation: route),
              isNull,
              reason:
                  '$route should be reachable by an authenticated employer session too',
            );
          }
        },
      );

      test(
        'an AuthUnknown (session not yet determined) hit on any of them bounces to splash, not login',
        () {
          for (final route in manualResumeRoutes) {
            expect(
              computeRedirect(
                authState: const AuthUnknown(),
                matchedLocation: route,
              ),
              RoutePaths.splash,
              reason:
                  '$route should wait for splash to resolve the session, matching every other protected route',
            );
          }
        },
      );
    });

    // Phase 39 — the opposite posture from the Manual Resume Builder group
    // above: `create_resume_views.preview_api`/`pdf_download`/`pages_api`
    // genuinely have **no** login requirement on the real backend
    // (confirmed directly — only the drafts endpoints do), and the real
    // web's own entry point is reachable by every visitor, so this app
    // deliberately does *not* add a stricter gate than the real site has.
    group('Create Resume routes', () {
      const universalCreateResumeRoutes = [
        RoutePaths.createResumeBuilder,
        RoutePaths.createResumePreview,
      ];

      test(
        'the builder and preview are universal routes, reachable by both auth states',
        () {
          for (final route in universalCreateResumeRoutes) {
            expect(
              RoutePaths.universalRoutes.contains(route),
              isTrue,
              reason: '$route must be universal',
            );
            expect(
              computeRedirect(
                authState: const AuthUnauthenticated(),
                matchedLocation: route,
              ),
              isNull,
              reason:
                  '$route should be reachable while unauthenticated, with no redirect',
            );
            const authenticated = AuthAuthenticated(AuthUser(username: 'jane'));
            expect(
              computeRedirect(authState: authenticated, matchedLocation: route),
              isNull,
              reason:
                  '$route should be reachable while authenticated too, with no redirect',
            );
          }
        },
      );

      test(
        'My Resumes (drafts) is not public or universal — the real drafts_list/draft_save/draft_delete '
        'endpoints are @login_required, confirmed directly',
        () {
          expect(
            RoutePaths.publicRoutes.contains(RoutePaths.createResumeDrafts),
            isFalse,
          );
          expect(
            RoutePaths.universalRoutes.contains(RoutePaths.createResumeDrafts),
            isFalse,
          );
          expect(
            computeRedirect(
              authState: const AuthUnauthenticated(),
              matchedLocation: RoutePaths.createResumeDrafts,
            ),
            RoutePaths.login,
          );
          const authenticated = AuthAuthenticated(AuthUser(username: 'jane'));
          expect(
            computeRedirect(
              authState: authenticated,
              matchedLocation: RoutePaths.createResumeDrafts,
            ),
            isNull,
          );
        },
      );
    });

    group('Phase 43 — Career browsing routes', () {
      const universalCareerRoutes = [
        RoutePaths.careerDepartments,
        RoutePaths.careerRoles,
      ];

      test(
        'departments and roles browsing are universal routes, reachable by both auth states — '
        'matching the real career_path() view, confirmed directly to have no @login_required',
        () {
          for (final route in universalCareerRoutes) {
            expect(
              RoutePaths.universalRoutes.contains(route),
              isTrue,
              reason: '$route must be universal',
            );
            expect(
              computeRedirect(
                authState: const AuthUnauthenticated(),
                matchedLocation: route,
              ),
              isNull,
              reason:
                  '$route should be reachable while unauthenticated, with no redirect',
            );
            const authenticated = AuthAuthenticated(AuthUser(username: 'jane'));
            expect(
              computeRedirect(authState: authenticated, matchedLocation: route),
              isNull,
              reason:
                  '$route should be reachable while authenticated too, with no redirect',
            );
          }
        },
      );

      test(
        'the role-action sheet\'s own destinations (Resume Parsing -> resumeBuilder, '
        'Build Resume -> manualResumeBuilder) remain protected, unchanged by this phase',
        () {
          for (final route in [
            RoutePaths.resumeBuilder,
            RoutePaths.manualResumeBuilder,
          ]) {
            expect(RoutePaths.publicRoutes.contains(route), isFalse);
            expect(RoutePaths.universalRoutes.contains(route), isFalse);
            expect(
              computeRedirect(
                authState: const AuthUnauthenticated(),
                matchedLocation: route,
              ),
              RoutePaths.login,
              reason:
                  '$route must still redirect an anonymous visitor to login',
            );
          }
        },
      );
    });

    // Phase 77 — explicit coverage for Phase 76's 2 new Tech Center routes,
    // confirmed not in `publicRoutes`/`universalRoutes`/
    // `employerProtectedRoutes` so each inherits the same default-protected
    // behavior as every other Skill Up destination (`skillUpNonIt`/
    // `skillUpNonItRoles` included) — matching the real site's own
    // `SkillUpAccessMiddleware`/login-required gating for this content.
    group('Phase 77 — Tech Center routes', () {
      test(
        'neither techCenterDepartments nor techCenterRoles is in any special route list',
        () {
          for (final route in [
            RoutePaths.techCenterDepartments,
            RoutePaths.techCenterRoles,
          ]) {
            expect(RoutePaths.publicRoutes.contains(route), isFalse);
            expect(RoutePaths.universalRoutes.contains(route), isFalse);
            expect(RoutePaths.employerProtectedRoutes.contains(route), isFalse);
          }
        },
      );

      test(
        'an unauthenticated hit on either Tech Center route bounces to the student login',
        () {
          for (final route in [
            RoutePaths.techCenterDepartments,
            RoutePaths.techCenterRoles,
          ]) {
            expect(
              computeRedirect(
                authState: const AuthUnauthenticated(),
                matchedLocation: route,
              ),
              RoutePaths.login,
              reason: '$route must redirect an anonymous visitor to login',
            );
          }
        },
      );

      test(
        'an authenticated candidate reaches both Tech Center routes without any redirect',
        () {
          const candidate = AuthAuthenticated(AuthUser(username: 'jane'));
          for (final route in [
            RoutePaths.techCenterDepartments,
            RoutePaths.techCenterRoles,
          ]) {
            expect(
              computeRedirect(authState: candidate, matchedLocation: route),
              isNull,
              reason:
                  '$route should be reachable while authenticated, with no redirect',
            );
          }
        },
      );
    });

    // Phase 78 — closes the coverage gap Phase 77 itself flagged: the 6
    // older Skill Up routes had no dedicated route-guard test at all before
    // this phase (only the 2 newest, `techCenterDepartments`/
    // `techCenterRoles`, did). All 8 share one real, confirmed policy —
    // `riya_bot.skillup_views.skillup_hub` (`royalStaffing_CB01`) is plain
    // `@login_required` with no `login_url=` override and no
    // employer-specific branch anywhere in its body (read in full this
    // phase): every one of these 8 Flutter routes is reached only by
    // navigating within or from that one real page, so every one of them
    // gets the same default-protected treatment here — bounced to the
    // student login when signed out, reachable by *either* role once
    // authenticated. A single well-structured, loop-based group covers all
    // 8 without 6 near-duplicate copies of the group above; it also
    // re-confirms the 2 Tech Center routes against a dimension Phase 77
    // never tested (employer access).
    group(
      'Phase 78 — the 6 older Skill Up routes (and a re-check of the 2 Tech Center ones)',
      () {
        const allSkillUpRoutes = [
          RoutePaths.skillUp,
          RoutePaths.skillUpSections,
          RoutePaths.skillUpCertifications,
          RoutePaths.skillUpLesson,
          RoutePaths.skillUpNonIt,
          RoutePaths.skillUpNonItRoles,
          RoutePaths.techCenterDepartments,
          RoutePaths.techCenterRoles,
        ];

        test('none of the 8 Skill Up routes is in any special route list', () {
          for (final route in allSkillUpRoutes) {
            expect(
              RoutePaths.publicRoutes.contains(route),
              isFalse,
              reason: '$route should not be public',
            );
            expect(
              RoutePaths.universalRoutes.contains(route),
              isFalse,
              reason: '$route should not be universal',
            );
            expect(
              RoutePaths.employerProtectedRoutes.contains(route),
              isFalse,
              reason:
                  '$route should not be employer-only — the real skillup_hub view has no employer branch',
            );
          }
        });

        test(
          'an unauthenticated hit on any of the 8 routes bounces to the student login, not the employer one',
          () {
            for (final route in allSkillUpRoutes) {
              expect(
                computeRedirect(
                  authState: const AuthUnauthenticated(),
                  matchedLocation: route,
                ),
                RoutePaths.login,
                reason:
                    '$route must redirect an anonymous visitor to the student login '
                    '(matches LOGIN_URL — no custom login_url= on the real view)',
              );
            }
          },
        );

        test(
          'an authenticated candidate reaches all 8 routes without any redirect',
          () {
            const candidate = AuthAuthenticated(AuthUser(username: 'jane'));
            for (final route in allSkillUpRoutes) {
              expect(
                computeRedirect(authState: candidate, matchedLocation: route),
                isNull,
                reason:
                    '$route should be reachable by a candidate, with no redirect',
              );
            }
          },
        );

        test(
          'an authenticated employer also reaches all 8 routes without any redirect — the real skillup_hub '
          'view has no employer-specific block (confirmed directly in source: plain @login_required, no '
          'portal/role branch anywhere in the view body), so an employer session must not be bounced away '
          'from candidate learning content it is actually allowed to see on the real site',
          () {
            const employer = AuthAuthenticated(
              AuthUser(username: 'acme', isEmployer: true),
            );
            for (final route in allSkillUpRoutes) {
              expect(
                computeRedirect(authState: employer, matchedLocation: route),
                isNull,
                reason:
                    '$route should be reachable by an employer session too, with no redirect',
              );
            }
          },
        );
      },
    );
  });
}
