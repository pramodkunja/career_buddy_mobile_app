import 'package:career_buddy_lms/app/router/route_paths.dart';
import 'package:career_buddy_lms/core/utils/result.dart';
import 'package:career_buddy_lms/features/auth/domain/entities/auth_user.dart';
import 'package:career_buddy_lms/features/auth/domain/repositories/auth_repository.dart';
import 'package:career_buddy_lms/features/auth/domain/entities/student_registration_data.dart';
import 'package:career_buddy_lms/features/auth/presentation/providers/auth_providers.dart';
import 'package:career_buddy_lms/features/home/presentation/screens/home_screen.dart';
import 'package:career_buddy_lms/shared/widgets/coming_soon_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

class _FakeAuthRepository implements AuthRepository {
  _FakeAuthRepository({this.restoredUser});

  final AuthUser? restoredUser;

  @override
  Future<AuthUser?> restoreSession() async => restoredUser;

  @override
  Future<Result<AuthUser>> login({
    required String usernameOrEmail,
    required String password,
  }) async {
    throw UnimplementedError();
  }

  @override
  Future<Result<void>> logout() async => const Success(null);

  @override
  Future<Result<String>> sendOtp(String email) async =>
      throw UnimplementedError();

  @override
  Future<Result<String>> verifyOtp({
    required String email,
    required String code,
  }) async => throw UnimplementedError();

  @override
  Future<Result<AuthUser>> register(StudentRegistrationData data) async =>
      throw UnimplementedError();
}

GoRouter _router() => GoRouter(
  initialLocation: RoutePaths.home,
  routes: [
    GoRoute(
      path: RoutePaths.home,
      builder: (context, state) => const HomeScreen(),
    ),
    GoRoute(
      path: RoutePaths.login,
      builder: (context, state) => const Scaffold(body: Text('Login Screen')),
    ),
    GoRoute(
      path: RoutePaths.register,
      builder: (context, state) =>
          const ComingSoonScreen(title: 'Create Account', message: 'x'),
    ),
    GoRoute(
      path: RoutePaths.employerLogin,
      builder: (context, state) =>
          const ComingSoonScreen(title: 'Employer Portal', message: 'x'),
    ),
    GoRoute(
      path: RoutePaths.employerRegister,
      builder: (context, state) =>
          const ComingSoonScreen(title: 'Employer Registration', message: 'x'),
    ),
    GoRoute(
      path: RoutePaths.employerDashboard,
      builder: (context, state) =>
          const Scaffold(body: Text('Employer Dashboard Screen')),
    ),
    GoRoute(
      path: RoutePaths.employerSearchCandidates,
      builder: (context, state) =>
          const ComingSoonScreen(title: 'Candidate Search', message: 'x'),
    ),
    GoRoute(
      path: RoutePaths.dashboard,
      builder: (context, state) =>
          const Scaffold(body: Text('Dashboard Screen')),
    ),
    GoRoute(
      path: RoutePaths.activities,
      builder: (context, state) =>
          const Scaffold(body: Text('Activities Screen')),
    ),
    GoRoute(
      path: RoutePaths.resumeBuilder,
      builder: (context, state) =>
          const ComingSoonScreen(title: 'Resume Parsing', message: 'x'),
    ),
    GoRoute(
      path: RoutePaths.skillUp,
      builder: (context, state) =>
          const Scaffold(body: Text('Skill Up Screen')),
    ),
    GoRoute(
      path: RoutePaths.sitemap,
      builder: (context, state) => const Scaffold(body: Text('Sitemap Screen')),
    ),
    GoRoute(
      path: RoutePaths.grammar,
      builder: (context, state) => const Scaffold(body: Text('Grammar Screen')),
    ),
    GoRoute(
      path: RoutePaths.pro,
      builder: (context, state) => const Scaffold(body: Text('Pro Screen')),
    ),
    GoRoute(
      path: RoutePaths.manualResumeBuilder,
      builder: (context, state) =>
          const Scaffold(body: Text('Manual Resume Builder Screen')),
    ),
    GoRoute(
      path: RoutePaths.createResumeBuilder,
      builder: (context, state) =>
          const Scaffold(body: Text('Create Resume Builder Screen')),
    ),
  ],
);

Future<void> _pump(
  WidgetTester tester, {
  AuthUser? user,
  Size size = const Size(400, 2900),
}) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);

  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        authRepositoryProvider.overrideWithValue(
          _FakeAuthRepository(restoredUser: user),
        ),
      ],
      child: MaterialApp.router(routerConfig: _router()),
    ),
  );
  await tester.pump();
}

/// [BuddyChatbotOverlay]'s float animation repeats forever
/// (`AnimationController.repeat(reverse: true)`), so `pumpAndSettle()`
/// would hang whenever it's still mounted (every `HomeScreen` route, and
/// any `context.push`-based destination stacked on top of it, since a
/// pushed page doesn't dispose the page beneath it). A bounded pump
/// covers the default ~300ms page-transition instead.
Future<void> _pumpAfterTap(WidgetTester tester) async {
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 400));
}

void main() {
  group('HomeScreen (guest)', () {
    testWidgets(
      'REGRESSION (Phase 37): renders the job seeker / employer story sections with their real web copy',
      (tester) async {
        await _pump(tester);

        expect(find.text('Built for your career journey'), findsOneWidget);
        expect(
          find.text('Build your hiring pipeline with CareerBuddy'),
          findsOneWidget,
        );
        expect(
          find.text('AI-powered Resume & Interview Preparation'),
          findsOneWidget,
        );
        expect(
          find.text('Post and manage job openings in minutes'),
          findsOneWidget,
        );
        expect(find.text('Explore Job Seeker Portal'), findsOneWidget);
        expect(find.text('Explore Employer Portal'), findsOneWidget);
      },
    );

    group('REGRESSION (Phase 21/37) — unified hero', () {
      testWidgets(
        'renders the unified hero headline and all 3 CTA labels above the story sections',
        (tester) async {
          await _pump(tester);

          expect(
            find.text('Build skills. Craft capability. Claim your career.'),
            findsOneWidget,
          );
          expect(find.text('Get Started Free'), findsOneWidget);
          expect(find.text('Find Jobs').first, findsWidgets);
          expect(find.text('Create Resume'), findsOneWidget);
          // The hero is above the story sections, not instead of them.
          expect(find.text('Built for your career journey'), findsOneWidget);
        },
      );

      testWidgets(
        'tapping Get Started Free navigates to the registration placeholder',
        (tester) async {
          await _pump(tester);

          await tester.tap(find.text('Get Started Free'));
          await _pumpAfterTap(tester);

          expect(find.widgetWithText(AppBar, 'Create Account'), findsOneWidget);
        },
      );

      testWidgets(
        "tapping the hero's Find Jobs pushes the dashboard route — in the real app, the auth guard (tested "
        'separately in route_guards_test.dart) redirects an anonymous visitor from there to /login, matching '
        "the real `dashboard()` view's own @login_required",
        (tester) async {
          await _pump(tester);

          // Both the hero button and the footer's "Find Jobs" link now share
          // this exact label — the hero's own button is first in tree order.
          await tester.tap(find.text('Find Jobs').first);
          await _pumpAfterTap(tester);

          expect(find.text('Dashboard Screen'), findsOneWidget);
        },
      );

      testWidgets(
        'REGRESSION (Phase 39): tapping Create Resume pushes the real free-form builder directly — matching '
        "the real web's own hero button destination exactly, no intermediate choice sheet",
        (tester) async {
          await _pump(tester);

          await tester.tap(find.text('Create Resume'));
          await _pumpAfterTap(tester);

          expect(find.text('Create Resume Builder Screen'), findsOneWidget);
        },
      );
    });

    testWidgets('shows the default (non-personalized) chatbot greeting', (
      tester,
    ) async {
      await _pump(tester);

      // BuddyChatbotOverlay now computes its greeting internally,
      // matching the real web's own guest-state prompt
      // (`riya_bot/views.py:_speakable_user_name`) rather than a
      // per-screen hardcoded string.
      expect(find.text('Hello there! Job seeker or employer?'), findsOneWidget);
    });

    testWidgets(
      'tapping the job-seeker story section\'s Login link navigates to /login',
      (tester) async {
        await _pump(tester);

        await tester.tap(find.text('Login').first);
        await _pumpAfterTap(tester);

        expect(find.text('Login Screen'), findsOneWidget);
      },
    );

    testWidgets(
      'tapping Explore Job Seeker Portal navigates to the registration placeholder (same destination '
      'as the old "Register Free" button, renamed to match the real web)',
      (tester) async {
        await _pump(tester);

        await tester.tap(find.text('Explore Job Seeker Portal'));
        await _pumpAfterTap(tester);

        expect(find.widgetWithText(AppBar, 'Create Account'), findsOneWidget);
      },
    );

    testWidgets(
      'tapping Explore Employer Portal navigates to Employer Registration (same destination as the '
      'old "Register Company" button, renamed to match the real web)',
      (tester) async {
        await _pump(tester);

        await tester.tap(find.text('Explore Employer Portal'));
        await _pumpAfterTap(tester);

        expect(find.text('Employer Registration'), findsOneWidget);
      },
    );

    group('REGRESSION (Phase 37) — the landing-specific footer', () {
      testWidgets('renders instead of the shared AppFooter for a guest', (
        tester,
      ) async {
        await _pump(tester);

        // The shared AppFooter's own stats row never appears on this page;
        // the richer footer's own unique brand tagline/platform column does.
        expect(find.text('Sub-Activities'), findsNothing);
        expect(find.text('Platform'), findsOneWidget);
        expect(find.text('Job Seekers'), findsOneWidget);
        expect(find.text('Employers'), findsOneWidget);
        expect(find.text('Company'), findsOneWidget);
      });

      testWidgets('tapping Skill Up in the footer navigates there', (
        tester,
      ) async {
        await _pump(tester);

        await tester.dragUntilVisible(
          find.text('Skill Up'),
          find.byType(SingleChildScrollView),
          const Offset(0, -300),
        );
        await tester.tap(find.text('Skill Up'));
        await _pumpAfterTap(tester);

        expect(find.text('Skill Up Screen'), findsOneWidget);
      });

      testWidgets('tapping CareerBuddy Pro in the footer navigates there', (
        tester,
      ) async {
        await _pump(tester);

        await tester.dragUntilVisible(
          find.text('CareerBuddy Pro'),
          find.byType(SingleChildScrollView),
          const Offset(0, -300),
        );
        await tester.tap(find.text('CareerBuddy Pro'));
        await _pumpAfterTap(tester);

        expect(find.text('Pro Screen'), findsOneWidget);
      });
    });
  });

  group('HomeScreen (authenticated)', () {
    const user = AuthUser(username: 'jane');

    testWidgets(
      'REGRESSION (Phase 21): renders the same unified hero as a guest sees, not the old hero-image-cards/button-row',
      (tester) async {
        await _pump(tester, user: user);

        expect(
          find.text('Build skills. Craft capability. Claim your career.'),
          findsOneWidget,
        );
        expect(find.text('Get Started Free'), findsOneWidget);
        expect(find.text('Find Jobs').first, findsWidgets);
        expect(find.text('Create Resume'), findsOneWidget);
        // The old content this hero replaced for a logged-in student:
        expect(find.text('Learn Business English'), findsNothing);
        expect(find.text('Apply for Your Dream Job'), findsNothing);
        expect(find.text('Parse Your Resume'), findsNothing);
        expect(find.text('My Dashboard'), findsNothing);
        expect(find.text('Browse Activities'), findsNothing);
      },
    );

    testWidgets('shows a personalized chatbot greeting', (tester) async {
      await _pump(tester, user: user);

      // Capitalized, matching `riya_bot/views.py:_speakable_user_name`'s
      // own `.capitalize()` — not a literal echo of the raw username.
      expect(find.text('Hello Jane!'), findsOneWidget);
    });

    testWidgets(
      'REGRESSION (Phase 21): tapping Get Started Free goes to the dashboard, never back into registration for an '
      'already-authenticated user',
      (tester) async {
        await _pump(tester, user: user);

        await tester.tap(find.text('Get Started Free'));
        await _pumpAfterTap(tester);

        expect(find.text('Dashboard Screen'), findsOneWidget);
        expect(find.widgetWithText(AppBar, 'Create Account'), findsNothing);
      },
    );

    testWidgets(
      "REGRESSION (Phase 21): tapping the hero's Find Jobs navigates to /dashboard (same destination as before)",
      (tester) async {
        await _pump(tester, user: user);

        await tester.tap(find.text('Find Jobs').first);
        await _pumpAfterTap(tester);

        expect(find.text('Dashboard Screen'), findsOneWidget);
      },
    );

    testWidgets(
      'REGRESSION (Phase 39): tapping Create Resume pushes the real free-form builder directly, same as the '
      'guest branch',
      (tester) async {
        await _pump(tester, user: user);

        await tester.tap(find.text('Create Resume'));
        await _pumpAfterTap(tester);

        expect(find.text('Create Resume Builder Screen'), findsOneWidget);
      },
    );

    testWidgets(
      'REGRESSION (Phase 37): still shows the landing-specific footer, not the shared AppFooter, for '
      'an authenticated non-employer student',
      (tester) async {
        await _pump(tester, user: user);

        expect(find.text('Platform'), findsOneWidget);
        expect(find.text('Sub-Activities'), findsNothing);
      },
    );
  });

  group('HomeScreen (authenticated employer)', () {
    const employer = AuthUser(username: 'acmehr', isEmployer: true);

    testWidgets(
      'still renders the "Learn Business English" card (a real web quirk, not fixed) '
      'but the hiring-pipeline card and employer CTAs instead of the job-seeker ones',
      (tester) async {
        await _pump(tester, user: employer);

        expect(find.text('Learn Business English'), findsOneWidget);
        expect(find.text('Manage Your Hiring Pipeline'), findsOneWidget);
        expect(find.text('Apply for Your Dream Job'), findsNothing);
        expect(find.text('Employer Dashboard'), findsOneWidget);
        expect(find.text('Find Candidates'), findsOneWidget);
        expect(find.text('Parse Your Resume'), findsNothing);
        expect(find.text('My Dashboard'), findsNothing);
      },
    );

    testWidgets('tapping Employer Dashboard navigates to it', (tester) async {
      await _pump(tester, user: employer);

      await tester.tap(find.text('Employer Dashboard'));
      await _pumpAfterTap(tester);

      expect(find.text('Employer Dashboard Screen'), findsOneWidget);
    });

    testWidgets(
      'tapping Find Candidates navigates to the candidate-search placeholder',
      (tester) async {
        await _pump(tester, user: employer);

        await tester.tap(find.text('Find Candidates'));
        await _pumpAfterTap(tester);

        expect(find.text('Candidate Search'), findsOneWidget);
      },
    );

    testWidgets(
      'REGRESSION (Phase 37): renders the shared AppFooter, not the landing-specific one — an '
      'authenticated employer never reaches landing.html on the real site (home() redirects to job_home first)',
      (tester) async {
        await _pump(tester, user: employer);

        expect(find.text('Sub-Activities'), findsOneWidget);
        expect(find.text('Platform'), findsNothing);
      },
    );
  });

  group('REGRESSION (Phase 21/37) — hero and page responsive layout', () {
    testWidgets(
      'renders the whole page without horizontal overflow at narrow phone widths, guest and student alike',
      (tester) async {
        for (final size in [
          const Size(320, 3200),
          const Size(360, 3200),
          const Size(390, 3200),
          const Size(430, 3200),
        ]) {
          await _pump(tester, size: size);
          expect(tester.takeException(), isNull);

          await _pump(
            tester,
            user: const AuthUser(username: 'jane'),
            size: size,
          );
          expect(tester.takeException(), isNull);
        }
      },
    );
  });
}
