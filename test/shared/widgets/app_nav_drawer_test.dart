import 'dart:async';

import 'package:career_buddy_lms/app/router/route_paths.dart';
import 'package:career_buddy_lms/core/errors/failures.dart';
import 'package:career_buddy_lms/core/media/media_url_resolver.dart';
import 'package:career_buddy_lms/core/utils/result.dart';
import 'package:career_buddy_lms/features/auth/domain/entities/auth_user.dart';
import 'package:career_buddy_lms/features/auth/domain/repositories/auth_repository.dart';
import 'package:career_buddy_lms/features/auth/domain/entities/student_registration_data.dart';
import 'package:career_buddy_lms/features/auth/presentation/providers/auth_providers.dart';
import 'package:career_buddy_lms/features/employer/domain/entities/employer_profile_form.dart';
import 'package:career_buddy_lms/features/employer/domain/repositories/employer_profile_repository.dart';
import 'package:career_buddy_lms/features/employer/presentation/providers/employer_profile_providers.dart';
import 'package:career_buddy_lms/features/home/presentation/providers/home_scroll_request_provider.dart';
import 'package:career_buddy_lms/shared/widgets/app_nav_drawer.dart';
import 'package:career_buddy_lms/shared/widgets/coming_soon_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

class _FakeEmployerProfileRepository implements EmployerProfileRepository {
  _FakeEmployerProfileRepository({this.result, this.neverResolves = false});

  /// `null` means "not configured for this test" — behaves exactly like a
  /// real employer who hasn't loaded/saved a profile yet, so the identity
  /// tile's own fallback (generic icon, "Employer Portal") is what a test
  /// that doesn't care about this data will see, never a real network call.
  final Result<EmployerProfileFormData>? result;

  /// Simulates a request that is still in flight — never completes, so the
  /// provider genuinely stays `AsyncLoading` for the lifetime of the test
  /// (a bare unresolved `Future` doesn't itself keep scheduling frames, so
  /// `pumpAndSettle` still returns normally once the drawer's own open
  /// animation finishes).
  final bool neverResolves;

  @override
  Future<Result<EmployerProfileFormData>> getProfileForm({required bool isCreate}) {
    if (neverResolves) return Completer<Result<EmployerProfileFormData>>().future;
    return Future.value(result ?? const Failed(UnexpectedFailure()));
  }

  @override
  Future<Result<void>> updateProfile(EmployerProfileSubmission data, {required bool isCreate}) async {
    throw UnimplementedError();
  }
}

class _FakeAuthRepository implements AuthRepository {
  _FakeAuthRepository({this.restoredUser});

  final AuthUser? restoredUser;
  int logoutCallCount = 0;

  @override
  Future<AuthUser?> restoreSession() async => restoredUser;

  @override
  Future<Result<AuthUser>> login({required String usernameOrEmail, required String password}) async {
    throw UnimplementedError();
  }

  @override
  Future<Result<void>> logout() async {
    logoutCallCount++;
    return const Success(null);
  }

  @override
  Future<Result<String>> sendOtp(String email) async => throw UnimplementedError();

  @override
  Future<Result<String>> verifyOtp({required String email, required String code}) async =>
      throw UnimplementedError();

  @override
  Future<Result<AuthUser>> register(StudentRegistrationData data) async => throw UnimplementedError();
}

/// Stands in for the real `HomeScreen` — just enough to prove (a) this is
/// genuinely the Home route being navigated to, and (b) which
/// [HomeScrollTarget], if any, the drawer asked for, by rendering the
/// provider's own current value as plain text.
class _FakeHomeScreen extends ConsumerWidget {
  const _FakeHomeScreen();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final target = ref.watch(homeScrollRequestProvider);
    return Scaffold(
      body: Text('Home Screen — scrollTarget: ${target?.name ?? 'none'}'),
    );
  }
}

GoRouter _router() => GoRouter(
  initialLocation: '/host',
  routes: [
    GoRoute(
      path: '/host',
      builder: (context, state) => Scaffold(drawer: const AppNavDrawer(), body: Builder(
        builder: (context) => Center(
          child: ElevatedButton(onPressed: () => Scaffold.of(context).openDrawer(), child: const Text('open')),
        ),
      )),
    ),
    GoRoute(path: RoutePaths.login, builder: (context, state) => const Scaffold(body: Text('Login Screen'))),
    GoRoute(path: RoutePaths.createResumeBuilder, builder: (context, state) => const Scaffold(body: Text('Create Resume Builder Screen'))),
    GoRoute(path: RoutePaths.employerLogin, builder: (context, state) => const ComingSoonScreen(title: 'Employer Portal', message: 'x')),
    GoRoute(path: RoutePaths.home, builder: (context, state) => const _FakeHomeScreen()),
    GoRoute(
      path: RoutePaths.activities,
      builder: (context, state) => Scaffold(
        body: Text('Activities Screen — category: ${state.uri.queryParameters['category'] ?? 'none'}'),
      ),
    ),
    GoRoute(path: RoutePaths.dashboard, builder: (context, state) => const Scaffold(body: Text('Dashboard Screen'))),
    GoRoute(path: RoutePaths.skillUp, builder: (context, state) => const Scaffold(body: Text('Skill Up Hub Screen'))),
    GoRoute(
      path: RoutePaths.skillUpSections,
      builder: (context, state) => Scaffold(
        body: Text('Skill Up Sections Screen — section: ${state.uri.queryParameters['section'] ?? 'none'}'),
      ),
    ),
    GoRoute(path: RoutePaths.skillUpCertifications, builder: (context, state) => const Scaffold(body: Text('Skill Up Certifications Screen'))),
    GoRoute(path: RoutePaths.sitemap, builder: (context, state) => const Scaffold(body: Text('Sitemap Screen'))),
    GoRoute(path: RoutePaths.resumeBuilder, builder: (context, state) => const ComingSoonScreen(title: 'Resume Parsing', message: 'x')),
    GoRoute(path: RoutePaths.grammar, builder: (context, state) => const Scaffold(body: Text('Grammar Screen'))),
    GoRoute(path: RoutePaths.pro, builder: (context, state) => const Scaffold(body: Text('Pro Screen'))),
    GoRoute(path: RoutePaths.profile, builder: (context, state) => const ComingSoonScreen(title: 'Profile', message: 'x')),
    GoRoute(path: RoutePaths.employerDashboard, builder: (context, state) => const Scaffold(body: Text('Employer Dashboard Screen'))),
    GoRoute(path: RoutePaths.employerHome, builder: (context, state) => const Scaffold(body: Text('Employer Home Screen'))),
    GoRoute(path: RoutePaths.employerJobCreate, builder: (context, state) => const ComingSoonScreen(title: 'Post New Job', message: 'x')),
    GoRoute(path: RoutePaths.employerAllApplications, builder: (context, state) => const ComingSoonScreen(title: 'All Applications', message: 'x')),
    GoRoute(path: RoutePaths.employerCompanyProfile, builder: (context, state) => const ComingSoonScreen(title: 'Company Profile', message: 'x')),
    GoRoute(path: RoutePaths.employerJobOpenings, builder: (context, state) => const ComingSoonScreen(title: 'Job Openings', message: 'x')),
    GoRoute(path: RoutePaths.employerSearchCandidates, builder: (context, state) => const ComingSoonScreen(title: 'Candidate Search', message: 'x')),
  ],
);

Future<_FakeAuthRepository> _pumpDrawer(
  WidgetTester tester, {
  AuthUser? user,
  Size? surfaceSize,
  Result<EmployerProfileFormData>? employerProfileResult,
  bool employerProfileNeverResolves = false,
}) async {
  if (surfaceSize != null) {
    await tester.binding.setSurfaceSize(surfaceSize);
    addTearDown(() => tester.binding.setSurfaceSize(null));
  }
  final repo = _FakeAuthRepository(restoredUser: user);
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        authRepositoryProvider.overrideWithValue(repo),
        employerProfileRepositoryProvider.overrideWithValue(
          _FakeEmployerProfileRepository(
            result: employerProfileResult,
            neverResolves: employerProfileNeverResolves,
          ),
        ),
      ],
      child: MaterialApp.router(routerConfig: _router()),
    ),
  );
  await tester.pump();
  await tester.tap(find.text('open'));
  await tester.pumpAndSettle();
  return repo;
}

/// Once a submenu (or both) is expanded, an item further down can sit
/// beyond the default test viewport the same way it would need scrolling
/// into view on a real, short phone screen. `ensureVisible` drives the
/// drawer's own `Scrollable` directly (the same mechanism a real
/// `Scrollable.ensureVisible` call uses), which — unlike simulating a
/// finger drag — isn't thrown off by `ExpansionTile`'s own internal
/// expand/collapse animation still settling.
Future<void> _scrollToAndTap(WidgetTester tester, String label) async {
  await tester.ensureVisible(find.text(label));
  await tester.pumpAndSettle();
  await tester.tap(find.text(label));
  await tester.pumpAndSettle();
}

/// The exact Skill Up submenu, in the real site's own order
/// (`site_nav.html:211-220`).
const _skillUpItems = [
  'English Learning',
  'Grammar',
  'Vocabulary & Idioms',
  'Speaking & Presentation',
  'Writing & Correspondence',
  'Negotiation & Meetings',
  'Interactive Roleplay',
  'Aptitude',
  'Tech',
  'Certifications',
];

/// The exact Resources submenu, in the real site's own order
/// (`site_nav.html:227-232`). "Certifications" reappears here by design —
/// both menus deliberately point at the same destination.
const _resourcesItems = [
  'Skill Up Hub',
  'Activities',
  'Certifications',
  'Tutorials: How CareerBuddy Works',
  'Sitemap',
  'CareerBuddy Pro',
];

void main() {
  group('AppNavDrawer — shared guest/authenticated-candidate item list (Phase 71)', () {
    for (final entry in <String, AuthUser?>{
      'guest': null,
      'authenticated candidate': const AuthUser(username: 'janedoe'),
    }.entries) {
      final label = entry.key;
      final user = entry.value;

      testWidgets(
        '[$label] shows every top-level item from the real site\'s own order, collapsed by default',
        (tester) async {
          await _pumpDrawer(tester, user: user);

          expect(find.text('Home'), findsOneWidget);
          expect(find.text('About Us'), findsOneWidget);
          expect(find.text('Skill Up'), findsOneWidget);
          expect(find.text('Resources'), findsOneWidget);
          expect(find.text('Industries'), findsOneWidget);
          expect(find.text('Create Resume'), findsOneWidget);
          expect(find.text('Contact Us'), findsOneWidget);

          // Collapsed by default — the submenu items aren't in the tree
          // yet.
          for (final item in _skillUpItems) {
            expect(find.text(item), findsNothing, reason: '"$item" should be collapsed');
          }
          for (final item in _resourcesItems) {
            expect(find.text(item), findsNothing, reason: '"$item" should be collapsed');
          }
        },
      );

      testWidgets(
        '[$label] expanding Skill Up reveals exactly its 10 real items, in order',
        (tester) async {
          await _pumpDrawer(tester, user: user);

          await tester.tap(find.text('Skill Up'));
          await tester.pumpAndSettle();

          for (final item in _skillUpItems) {
            expect(find.text(item), findsOneWidget, reason: '"$item" should be visible once expanded');
          }
          // Still collapsed — expanding one submenu must not auto-expand
          // the other.
          expect(find.text('Skill Up Hub'), findsNothing);
          expect(find.text('CareerBuddy Pro'), findsNothing);

          // Collapsing it again removes the items from the tree.
          await tester.tap(find.text('Skill Up'));
          await tester.pumpAndSettle();
          for (final item in _skillUpItems) {
            expect(find.text(item), findsNothing, reason: '"$item" should be hidden again after collapsing');
          }
        },
      );

      testWidgets(
        '[$label] expanding Resources reveals exactly its 6 real items, in order',
        (tester) async {
          await _pumpDrawer(tester, user: user);

          await tester.tap(find.text('Resources'));
          await tester.pumpAndSettle();

          for (final item in _resourcesItems) {
            expect(find.text(item), findsOneWidget, reason: '"$item" should be visible once expanded');
          }
          // Skill Up's own items stay hidden.
          expect(find.text('English Learning'), findsNothing);
          expect(find.text('Aptitude'), findsNothing);

          await tester.tap(find.text('Resources'));
          await tester.pumpAndSettle();
          for (final item in _resourcesItems) {
            expect(find.text(item), findsNothing, reason: '"$item" should be hidden again after collapsing');
          }
        },
      );

      testWidgets(
        '[$label] both submenus can be open at once, independently',
        (tester) async {
          await _pumpDrawer(tester, user: user);

          await tester.tap(find.text('Skill Up'));
          await tester.pumpAndSettle();
          await _scrollToAndTap(tester, 'Resources');

          expect(find.text('English Learning'), findsOneWidget);
          expect(find.text('Skill Up Hub'), findsOneWidget);

          // Collapsing one leaves the other expanded.
          await _scrollToAndTap(tester, 'Skill Up');
          expect(find.text('English Learning'), findsNothing);
          expect(find.text('Skill Up Hub'), findsOneWidget);
        },
      );
    }

    testWidgets('guest does not see Dashboard', (tester) async {
      await _pumpDrawer(tester);
      expect(find.text('Dashboard'), findsNothing);
    });

    testWidgets('authenticated candidate does see Dashboard', (tester) async {
      await _pumpDrawer(tester, user: const AuthUser(username: 'janedoe'));
      expect(find.text('Dashboard'), findsOneWidget);
    });

    testWidgets('guest sees the 2 login tiles, never Profile/Logout', (tester) async {
      await _pumpDrawer(tester);

      expect(find.text('Job Seeker Login'), findsOneWidget);
      expect(find.text('Employer Login'), findsOneWidget);
      expect(find.text('Logout'), findsNothing);
      expect(find.text('janedoe'), findsNothing);
    });

    testWidgets('authenticated candidate sees Profile/Logout, never the login tiles', (tester) async {
      await _pumpDrawer(tester, user: const AuthUser(username: 'janedoe'));

      expect(find.text('janedoe'), findsOneWidget);
      expect(find.text('Logout'), findsOneWidget);
      expect(find.text('Job Seeker Login'), findsNothing);
      expect(find.text('Employer Login'), findsNothing);
    });

    testWidgets(
      'Phase 67/70 pre-existing items no longer linked from the real site\'s nav are gone from this drawer too '
      '(Resume Parsing, Job Openings as flat authenticated items)',
      (tester) async {
        await _pumpDrawer(tester, user: const AuthUser(username: 'janedoe'));

        expect(find.text('Resume Parsing'), findsNothing);
        expect(find.text('Job Openings'), findsNothing);
      },
    );

    testWidgets('tapping Job Seeker Login navigates to /login', (tester) async {
      await _pumpDrawer(tester);

      await tester.tap(find.text('Job Seeker Login'));
      await tester.pumpAndSettle();

      expect(find.text('Login Screen'), findsOneWidget);
    });

    testWidgets('tapping Employer Login navigates to the Employer Portal placeholder', (tester) async {
      await _pumpDrawer(tester);

      await tester.tap(find.text('Employer Login'));
      await tester.pumpAndSettle();

      expect(find.text('Employer Portal'), findsOneWidget);
    });

    testWidgets('tapping Create Resume navigates to the guest Create Resume builder', (tester) async {
      await _pumpDrawer(tester);

      await tester.tap(find.text('Create Resume'));
      await tester.pumpAndSettle();

      expect(find.text('Create Resume Builder Screen'), findsOneWidget);
    });

    testWidgets('tapping Dashboard (authenticated) navigates to /dashboard', (tester) async {
      await _pumpDrawer(tester, user: const AuthUser(username: 'janedoe'));

      await tester.tap(find.text('Dashboard'));
      await tester.pumpAndSettle();

      expect(find.text('Dashboard Screen'), findsOneWidget);
    });

    testWidgets('tapping Logout calls the auth repository logout', (tester) async {
      final repo = await _pumpDrawer(tester, user: const AuthUser(username: 'janedoe'));

      await tester.tap(find.text('Logout'));
      await tester.pumpAndSettle();

      expect(repo.logoutCallCount, 1);
    });

    group('Skill Up submenu destinations', () {
      testWidgets(
        'Phase 72 — English Learning and Vocabulary & Idioms both open Skill Up Sections pre-selected to '
        'depth-english — the real site\'s own deliberately-shared destination, confirmed via core/navigation.py',
        (tester) async {
          for (final label in ['English Learning', 'Vocabulary & Idioms']) {
            await _pumpDrawer(tester);
            await tester.tap(find.text('Skill Up'));
            await tester.pumpAndSettle();
            await _scrollToAndTap(tester, label);
            expect(
              find.text('Skill Up Sections Screen — section: depth-english'),
              findsOneWidget,
              reason: '"$label" should open Skill Up Sections pre-selected to depth-english',
            );
          }
        },
      );

      testWidgets('Grammar opens the Grammar screen', (tester) async {
        await _pumpDrawer(tester);
        await tester.tap(find.text('Skill Up'));
        await tester.pumpAndSettle();
        await _scrollToAndTap(tester, 'Grammar');
        expect(find.text('Grammar Screen'), findsOneWidget);
      });

      testWidgets(
        'Phase 72 — Aptitude and Tech each open Skill Up Sections pre-selected to their own distinct section '
        '(depth-aptitude / depth-tech), not the same generic tab',
        (tester) async {
          const expected = {'Aptitude': 'depth-aptitude', 'Tech': 'depth-tech'};
          for (final MapEntry(key: label, value: sectionId) in expected.entries) {
            await _pumpDrawer(tester);
            await tester.tap(find.text('Skill Up'));
            await tester.pumpAndSettle();
            await _scrollToAndTap(tester, label);
            expect(
              find.text('Skill Up Sections Screen — section: $sectionId'),
              findsOneWidget,
              reason: '"$label" should open Skill Up Sections pre-selected to $sectionId',
            );
          }
        },
      );

      testWidgets('Certifications opens the Skill Up Certifications screen', (tester) async {
        await _pumpDrawer(tester);
        await tester.tap(find.text('Skill Up'));
        await tester.pumpAndSettle();
        await _scrollToAndTap(tester, 'Certifications');
        expect(find.text('Skill Up Certifications Screen'), findsOneWidget);
      });

      testWidgets(
        'Speaking/Writing/Negotiation/Interactive Roleplay each open Activities pre-filtered to the real category',
        (tester) async {
          const expected = {
            'Speaking & Presentation': 'speaking',
            'Writing & Correspondence': 'writing',
            'Negotiation & Meetings': 'negotiation',
            'Interactive Roleplay': 'workshop',
          };
          for (final MapEntry(key: label, value: category) in expected.entries) {
            await _pumpDrawer(tester);
            await tester.tap(find.text('Skill Up'));
            await tester.pumpAndSettle();
            await _scrollToAndTap(tester, label);
            expect(
              find.text('Activities Screen — category: $category'),
              findsOneWidget,
              reason: '"$label" should open Activities filtered to "$category"',
            );
          }
        },
      );
    });

    group('Resources submenu destinations', () {
      testWidgets('Skill Up Hub opens the hub with no section filter', (tester) async {
        await _pumpDrawer(tester);
        await tester.tap(find.text('Resources'));
        await tester.pumpAndSettle();
        await _scrollToAndTap(tester, 'Skill Up Hub');
        expect(find.text('Skill Up Hub Screen'), findsOneWidget);
      });

      testWidgets('Activities opens the unfiltered Activities list', (tester) async {
        await _pumpDrawer(tester);
        await tester.tap(find.text('Resources'));
        await tester.pumpAndSettle();
        await _scrollToAndTap(tester, 'Activities');
        expect(find.text('Activities Screen — category: none'), findsOneWidget);
      });

      testWidgets('Certifications (Resources) opens the same screen as Skill Up\'s own Certifications', (tester) async {
        await _pumpDrawer(tester);
        await tester.tap(find.text('Resources'));
        await tester.pumpAndSettle();
        await _scrollToAndTap(tester, 'Certifications');
        expect(find.text('Skill Up Certifications Screen'), findsOneWidget);
      });

      testWidgets('Sitemap opens the Sitemap screen', (tester) async {
        await _pumpDrawer(tester);
        await tester.tap(find.text('Resources'));
        await tester.pumpAndSettle();
        await _scrollToAndTap(tester, 'Sitemap');
        expect(find.text('Sitemap Screen'), findsOneWidget);
      });

      testWidgets('CareerBuddy Pro opens the Pro screen', (tester) async {
        await _pumpDrawer(tester);
        await tester.tap(find.text('Resources'));
        await tester.pumpAndSettle();
        await _scrollToAndTap(tester, 'CareerBuddy Pro');
        expect(find.text('Pro Screen'), findsOneWidget);
      });

      testWidgets('Tutorials: How CareerBuddy Works opens Home and requests the tutorials anchor', (tester) async {
        await _pumpDrawer(tester);
        await tester.tap(find.text('Resources'));
        await tester.pumpAndSettle();
        await _scrollToAndTap(tester, 'Tutorials: How CareerBuddy Works');
        expect(find.text('Home Screen — scrollTarget: tutorials'), findsOneWidget);
      });
    });

    group('Anchor-scroll items (About Us / Industries / Contact Us)', () {
      testWidgets('About Us opens Home and requests the about anchor', (tester) async {
        await _pumpDrawer(tester);
        await tester.tap(find.text('About Us'));
        await tester.pumpAndSettle();
        expect(find.text('Home Screen — scrollTarget: about'), findsOneWidget);
      });

      testWidgets('Industries opens Home and requests the choose-path anchor', (tester) async {
        await _pumpDrawer(tester);
        await tester.tap(find.text('Industries'));
        await tester.pumpAndSettle();
        expect(find.text('Home Screen — scrollTarget: choosePath'), findsOneWidget);
      });

      testWidgets('Contact Us opens Home and requests the contact (footer) anchor', (tester) async {
        await _pumpDrawer(tester);
        await tester.tap(find.text('Contact Us'));
        await tester.pumpAndSettle();
        expect(find.text('Home Screen — scrollTarget: contact'), findsOneWidget);
      });
    });

    testWidgets(
      'a 320px-wide viewport shows every top-level item and both expanded submenus with no layout overflow',
      (tester) async {
        await _pumpDrawer(tester, surfaceSize: const Size(320, 640));

        await tester.tap(find.text('Skill Up'));
        await tester.pumpAndSettle();
        await _scrollToAndTap(tester, 'Resources');

        expect(tester.takeException(), isNull);
        expect(find.text('Interactive Roleplay'), findsOneWidget);
        expect(find.text('CareerBuddy Pro'), findsOneWidget);
      },
    );

    testWidgets('every top-level nav tile exposes its label as a non-empty semantic label', (tester) async {
      await _pumpDrawer(tester);

      for (final label in const [
        'Home',
        'About Us',
        'Skill Up',
        'Resources',
        'Industries',
        'Create Resume',
        'Contact Us',
        'Job Seeker Login',
        'Employer Login',
      ]) {
        final semantics = tester.getSemantics(find.text(label).first);
        expect(
          semantics.label,
          contains(label),
          reason: '"$label" should carry its own text as an accessible label',
        );
      }
    });
  });

  group('AppNavDrawer (authenticated employer) — Phase 73 audit', () {
    const employer = AuthUser(username: 'acmehr', isEmployer: true);

    /// The merged real-site order: `site_nav.html`'s own 3-item employer
    /// branch (`:199-204`, Employer Dashboard/Jobs/Company Profile)
    /// interleaved with `employer_base.html`'s 6-item sidebar (`:214-238`),
    /// deduplicating "Company Profile" (the identical real destination in
    /// both surfaces) to the one entry already here before this phase.
    const employerItems = [
      'Employer Dashboard',
      'Jobs',
      'Post New Job',
      'All Applications',
      'Company Profile',
      'Job Openings',
      'Candidate Search',
    ];

    const sampleLogoProfile = EmployerProfileFormData(
      companyName: 'Acme Talent Solutions',
      companyWebsite: '',
      industry: '',
      companySize: '',
      location: '',
      description: '',
      companyAddress: '',
      companyGst: '',
      maskedPan: '',
      hrContactE164: '',
      hrMail: '',
      companyLogoUrl: '/media/logos/acme.png',
    );

    testWidgets('shows the employer nav items instead of the candidate ones', (tester) async {
      await _pumpDrawer(tester, user: employer);

      for (final label in employerItems) {
        expect(find.text(label), findsOneWidget, reason: '"$label" should be present');
      }
      // Phase 74 — the identity tile shows the real site's own static
      // "Recruiter Account" label and (with no profile configured for this
      // test) its own "Employer Portal" fallback, never the username.
      expect(find.text('Recruiter Account'), findsOneWidget);
      expect(find.text('Employer Portal'), findsOneWidget);
      expect(find.text('acmehr'), findsNothing);
      expect(find.text('Logout'), findsOneWidget);

      // Not the candidate branch's items.
      expect(find.text('Skill Up'), findsNothing);
      expect(find.text('Resources'), findsNothing);
      expect(find.text('About Us'), findsNothing);
    });

    testWidgets(
      'Phase 73 — the employer items appear in the merged real-site order',
      (tester) async {
        await _pumpDrawer(tester, user: employer);

        final positions = [
          for (final label in employerItems) tester.getTopLeft(find.text(label)).dy,
        ];
        for (var i = 1; i < positions.length; i++) {
          expect(
            positions[i],
            greaterThan(positions[i - 1]),
            reason: '"${employerItems[i]}" should come after "${employerItems[i - 1]}"',
          );
        }
      },
    );

    testWidgets('tapping Employer Dashboard navigates to it', (tester) async {
      await _pumpDrawer(tester, user: employer);

      await tester.tap(find.text('Employer Dashboard'));
      await tester.pumpAndSettle();

      expect(find.text('Employer Dashboard Screen'), findsOneWidget);
    });

    testWidgets(
      'Phase 73 — tapping Jobs navigates to the real Employer Home screen (the real site\'s own '
      '"Jobs" destination, previously missing from this drawer)',
      (tester) async {
        await _pumpDrawer(tester, user: employer);

        await tester.tap(find.text('Jobs'));
        await tester.pumpAndSettle();

        expect(find.text('Employer Home Screen'), findsOneWidget);
      },
    );

    testWidgets(
      'Phase 73 — each remaining sidebar item reaches its own verified, already-built destination',
      (tester) async {
        const destinations = {
          'Post New Job': 'Post New Job',
          'All Applications': 'All Applications',
          'Job Openings': 'Job Openings',
          'Candidate Search': 'Candidate Search',
        };
        for (final MapEntry(key: label, value: screenTitle) in destinations.entries) {
          await _pumpDrawer(tester, user: employer);
          await tester.tap(find.text(label));
          await tester.pumpAndSettle();
          expect(
            find.text(screenTitle),
            findsOneWidget,
            reason: '"$label" should open its own real destination, not a different one',
          );
        }
      },
    );

    testWidgets(
      'Phase 73/74 — the identity tile (avatar + company name) also opens Company Profile, matching '
      'the real sidebar\'s own identity block linking nowhere else',
      (tester) async {
        await _pumpDrawer(
          tester,
          user: employer,
          employerProfileResult: const Success(
            EmployerProfileFormData(
              companyName: 'Acme Talent Solutions',
              companyWebsite: '',
              industry: '',
              companySize: '',
              location: '',
              description: '',
              companyAddress: '',
              companyGst: '',
              maskedPan: '',
              hrContactE164: '',
              hrMail: '',
            ),
          ),
        );

        await tester.tap(find.text('Acme Talent Solutions'));
        await tester.pumpAndSettle();

        expect(find.text('Company Profile'), findsOneWidget);
      },
    );

    testWidgets('tapping Company Profile navigates to the one, deduplicated Company Profile screen', (tester) async {
      await _pumpDrawer(tester, user: employer);

      await tester.tap(find.text('Company Profile'));
      await tester.pumpAndSettle();

      expect(find.text('Company Profile'), findsOneWidget);
    });

    group('Phase 74 — employer identity tile', () {
      testWidgets('a company with a saved name and logo shows both, not the username', (tester) async {
        await _pumpDrawer(tester, user: employer, employerProfileResult: const Success(sampleLogoProfile));

        expect(find.text('Acme Talent Solutions'), findsOneWidget);
        expect(find.text('Recruiter Account'), findsOneWidget);
        expect(find.text('acmehr'), findsNothing);
        expect(find.text('Employer Portal'), findsNothing);
        expect(
          find.byWidgetPredicate(
            (widget) =>
                widget is Image &&
                widget.image is NetworkImage &&
                (widget.image as NetworkImage).url == resolveMediaUrl('/media/logos/acme.png'),
          ),
          findsOneWidget,
        );
      });

      testWidgets('a company with a saved name but no logo on file shows the generic icon, not a broken image', (
        tester,
      ) async {
        await _pumpDrawer(
          tester,
          user: employer,
          employerProfileResult: const Success(
            EmployerProfileFormData(
              companyName: 'No Logo Yet Inc',
              companyWebsite: '',
              industry: '',
              companySize: '',
              location: '',
              description: '',
              companyAddress: '',
              companyGst: '',
              maskedPan: '',
              hrContactE164: '',
              hrMail: '',
            ),
          ),
        );

        expect(find.text('No Logo Yet Inc'), findsOneWidget);
        expect(find.byType(Image), findsNothing);
        expect(find.byIcon(Icons.business), findsOneWidget);
      });

      testWidgets('a blank/empty saved company name falls back to "Employer Portal", matching the real site\'s '
          'own |default filter', (tester) async {
        await _pumpDrawer(
          tester,
          user: employer,
          employerProfileResult: const Success(
            EmployerProfileFormData(
              companyName: '   ',
              companyWebsite: '',
              industry: '',
              companySize: '',
              location: '',
              description: '',
              companyAddress: '',
              companyGst: '',
              maskedPan: '',
              hrContactE164: '',
              hrMail: '',
            ),
          ),
        );

        expect(find.text('Employer Portal'), findsOneWidget);
      });

      testWidgets(
        'a failed profile fetch (e.g. no profile saved yet) shows the fallback, never a crash or blank tile',
        (tester) async {
          await _pumpDrawer(
            tester,
            user: employer,
            employerProfileResult: const Failed(UnexpectedFailure()),
          );

          expect(tester.takeException(), isNull);
          expect(find.text('Employer Portal'), findsOneWidget);
          expect(find.byIcon(Icons.business), findsOneWidget);
        },
      );

      testWidgets('while the profile is still loading, the fallback renders — never a blank tile', (tester) async {
        await _pumpDrawer(tester, user: employer, employerProfileNeverResolves: true);

        // The fetch never resolves, so the provider stays `AsyncLoading` for
        // the whole test — this is the drawer's genuine "still loading"
        // state, not a timing guess.
        expect(find.text('Employer Portal'), findsOneWidget);
        expect(find.byIcon(Icons.business), findsOneWidget);
      });

      testWidgets(
        "a logo URL that fails to load falls back to the generic icon via the Image's own errorBuilder",
        (tester) async {
          await _pumpDrawer(tester, user: employer, employerProfileResult: const Success(sampleLogoProfile));

          final image = tester.widget<Image>(find.byType(Image));
          final fallback = image.errorBuilder!(
            tester.element(find.byType(Image)),
            Exception('simulated load failure'),
            null,
          );

          expect(fallback, isA<Icon>());
          expect((fallback as Icon).icon, Icons.business);
        },
      );
    });

    testWidgets(
      'Phase 73 — a candidate session never sees any employer-only item, including the new Jobs entry',
      (tester) async {
        await _pumpDrawer(tester, user: const AuthUser(username: 'jane'));

        for (final label in employerItems) {
          expect(find.text(label), findsNothing, reason: '"$label" must not be shown to a candidate');
        }
        // Phase 74 — a candidate must never see the employer identity
        // tile's own static label either.
        expect(find.text('Recruiter Account'), findsNothing);
      },
    );

    testWidgets(
      'Phase 73 — a guest never sees any employer-only item, including the new Jobs entry',
      (tester) async {
        await _pumpDrawer(tester);

        for (final label in employerItems) {
          expect(find.text(label), findsNothing, reason: '"$label" must not be shown to a guest');
        }
        expect(find.text('Recruiter Account'), findsNothing);
      },
    );

    testWidgets(
      'Phase 73 — a 320px-wide viewport shows every employer item with no layout overflow',
      (tester) async {
        await _pumpDrawer(
          tester,
          user: employer,
          surfaceSize: const Size(320, 640),
          employerProfileResult: const Success(sampleLogoProfile),
        );

        expect(tester.takeException(), isNull);
        for (final label in employerItems) {
          expect(find.text(label), findsOneWidget, reason: '"$label" should still be present at 320px wide');
        }
        // Phase 74 — the identity tile's company name/subtitle must also
        // fit without overflowing at the narrowest supported width.
        expect(find.text('Acme Talent Solutions'), findsOneWidget);
        expect(find.text('Recruiter Account'), findsOneWidget);
      },
    );

    testWidgets('tapping Logout calls the auth repository logout', (tester) async {
      final repo = await _pumpDrawer(tester, user: employer);

      await tester.tap(find.text('Logout'));
      await tester.pumpAndSettle();

      expect(repo.logoutCallCount, 1);
    });
  });
}
