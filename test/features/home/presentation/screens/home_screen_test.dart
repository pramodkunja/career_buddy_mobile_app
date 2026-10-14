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
  Future<Result<AuthUser>> login({required String usernameOrEmail, required String password}) async {
    throw UnimplementedError();
  }

  @override
  Future<Result<void>> logout() async => const Success(null);

  @override
  Future<Result<String>> sendOtp(String email) async => throw UnimplementedError();

  @override
  Future<Result<String>> verifyOtp({required String email, required String code}) async =>
      throw UnimplementedError();

  @override
  Future<Result<AuthUser>> register(StudentRegistrationData data) async => throw UnimplementedError();
}

GoRouter _router() => GoRouter(
  initialLocation: RoutePaths.home,
  routes: [
    GoRoute(path: RoutePaths.home, builder: (context, state) => const HomeScreen()),
    GoRoute(path: RoutePaths.login, builder: (context, state) => const Scaffold(body: Text('Login Screen'))),
    GoRoute(path: RoutePaths.register, builder: (context, state) => const ComingSoonScreen(title: 'Create Account', message: 'x')),
    GoRoute(path: RoutePaths.employerLogin, builder: (context, state) => const ComingSoonScreen(title: 'Employer Portal', message: 'x')),
    GoRoute(path: RoutePaths.employerRegister, builder: (context, state) => const ComingSoonScreen(title: 'Employer Registration', message: 'x')),
    GoRoute(path: RoutePaths.employerDashboard, builder: (context, state) => const Scaffold(body: Text('Employer Dashboard Screen'))),
    GoRoute(path: RoutePaths.employerSearchCandidates, builder: (context, state) => const ComingSoonScreen(title: 'Candidate Search', message: 'x')),
    GoRoute(path: RoutePaths.dashboard, builder: (context, state) => const Scaffold(body: Text('Dashboard Screen'))),
    GoRoute(path: RoutePaths.activities, builder: (context, state) => const Scaffold(body: Text('Activities Screen'))),
    GoRoute(path: RoutePaths.resumeBuilder, builder: (context, state) => const ComingSoonScreen(title: 'Resume Parsing', message: 'x')),
  ],
);

Future<void> _pump(WidgetTester tester, {AuthUser? user, Size size = const Size(400, 2400)}) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);

  await tester.pumpWidget(
    ProviderScope(
      overrides: [authRepositoryProvider.overrideWithValue(_FakeAuthRepository(restoredUser: user))],
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
    testWidgets('renders the Job Seeker / Employer portal cards with their web copy', (tester) async {
      await _pump(tester);

      expect(find.text('for job seekers'), findsOneWidget);
      expect(find.text('for clients'), findsOneWidget);
      expect(find.textContaining('Learn English, build resumes'), findsOneWidget);
      expect(find.textContaining('Post jobs, search verified candidates'), findsOneWidget);
      expect(find.text('Register Free'), findsOneWidget);
      expect(find.text('Register Company'), findsOneWidget);
    });

    group('REGRESSION (Phase 21) — unified hero', () {
      testWidgets('renders the unified hero headline and all 3 CTA labels above the portal cards', (tester) async {
        await _pump(tester);

        expect(find.text('Build skills. Craft capability. Claim your career.'), findsOneWidget);
        expect(find.text('Get Started'), findsOneWidget);
        expect(find.text('Find Jobs'), findsOneWidget);
        expect(find.text('Create Resume'), findsOneWidget);
        // The hero is new, additive content — the existing portal cards
        // below it must still be present, not replaced.
        expect(find.text('for job seekers'), findsOneWidget);
      });

      testWidgets('tapping Get Started navigates to the registration placeholder, same as Register Free', (
        tester,
      ) async {
        await _pump(tester);

        await tester.tap(find.text('Get Started'));
        await _pumpAfterTap(tester);

        expect(find.text('Create Account'), findsOneWidget);
      });

      testWidgets(
        'tapping Find Jobs pushes the dashboard route — in the real app, the auth guard (tested separately in '
        'route_guards_test.dart) redirects an anonymous visitor from there to /login, matching '
        "the real `dashboard()` view's own @login_required",
        (tester) async {
          await _pump(tester);

          await tester.tap(find.text('Find Jobs'));
          await _pumpAfterTap(tester);

          expect(find.text('Dashboard Screen'), findsOneWidget);
        },
      );

      testWidgets(
        'tapping Create Resume pushes the resume-builder route — same auth-guard redirect note as Find Jobs applies',
        (tester) async {
          await _pump(tester);

          await tester.tap(find.text('Create Resume'));
          await _pumpAfterTap(tester);

          expect(find.text('Resume Parsing'), findsOneWidget);
        },
      );
    });

    testWidgets('shows the default (non-personalized) chatbot greeting', (tester) async {
      await _pump(tester);

      // BuddyChatbotOverlay now computes its greeting internally,
      // matching the real web's own guest-state prompt
      // (`riya_bot/views.py:_speakable_user_name`) rather than a
      // per-screen hardcoded string.
      expect(find.text('Hello there! Job seeker or employer?'), findsOneWidget);
    });

    testWidgets('tapping the job-seeker Login button navigates to /login', (tester) async {
      await _pump(tester);

      await tester.tap(find.text('Login').first);
      await _pumpAfterTap(tester);

      expect(find.text('Login Screen'), findsOneWidget);
    });

    testWidgets('tapping Register Free navigates to the registration placeholder', (tester) async {
      await _pump(tester);

      await tester.tap(find.text('Register Free'));
      await _pumpAfterTap(tester);

      expect(find.text('Create Account'), findsOneWidget);
    });

    testWidgets('tapping Register Company navigates to Employer Registration', (tester) async {
      await _pump(tester);

      await tester.tap(find.text('Register Company'));
      await _pumpAfterTap(tester);

      expect(find.text('Employer Registration'), findsOneWidget);
    });
  });

  group('HomeScreen (authenticated)', () {
    const user = AuthUser(username: 'jane');

    testWidgets(
      'REGRESSION (Phase 21): renders the same unified hero as a guest sees, not the old hero-image-cards/button-row',
      (tester) async {
        await _pump(tester, user: user);

        expect(find.text('Build skills. Craft capability. Claim your career.'), findsOneWidget);
        expect(find.text('Get Started'), findsOneWidget);
        expect(find.text('Find Jobs'), findsOneWidget);
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
      'REGRESSION (Phase 21): tapping Get Started goes to the dashboard, never back into registration for an '
      'already-authenticated user',
      (tester) async {
        await _pump(tester, user: user);

        await tester.tap(find.text('Get Started'));
        await _pumpAfterTap(tester);

        expect(find.text('Dashboard Screen'), findsOneWidget);
        expect(find.text('Create Account'), findsNothing);
      },
    );

    testWidgets('REGRESSION (Phase 21): tapping Find Jobs navigates to /dashboard (same destination as before)', (
      tester,
    ) async {
      await _pump(tester, user: user);

      await tester.tap(find.text('Find Jobs'));
      await _pumpAfterTap(tester);

      expect(find.text('Dashboard Screen'), findsOneWidget);
    });

    testWidgets('tapping Create Resume navigates to the resume-builder placeholder (same destination/label as before, '
        'renamed from "Parse Your Resume")', (tester) async {
      await _pump(tester, user: user);

      await tester.tap(find.text('Create Resume'));
      await _pumpAfterTap(tester);

      expect(find.text('Resume Parsing'), findsOneWidget);
    });
  });

  group('HomeScreen (authenticated employer)', () {
    const employer = AuthUser(username: 'acmehr', isEmployer: true);

    testWidgets('still renders the "Learn Business English" card (a real web quirk, not fixed) '
        'but the hiring-pipeline card and employer CTAs instead of the job-seeker ones', (tester) async {
      await _pump(tester, user: employer);

      expect(find.text('Learn Business English'), findsOneWidget);
      expect(find.text('Manage Your Hiring Pipeline'), findsOneWidget);
      expect(find.text('Apply for Your Dream Job'), findsNothing);
      expect(find.text('Employer Dashboard'), findsOneWidget);
      expect(find.text('Find Candidates'), findsOneWidget);
      expect(find.text('Parse Your Resume'), findsNothing);
      expect(find.text('My Dashboard'), findsNothing);
    });

    testWidgets('tapping Employer Dashboard navigates to it', (tester) async {
      await _pump(tester, user: employer);

      await tester.tap(find.text('Employer Dashboard'));
      await _pumpAfterTap(tester);

      expect(find.text('Employer Dashboard Screen'), findsOneWidget);
    });

    testWidgets('tapping Find Candidates navigates to the candidate-search placeholder', (tester) async {
      await _pump(tester, user: employer);

      await tester.tap(find.text('Find Candidates'));
      await _pumpAfterTap(tester);

      expect(find.text('Candidate Search'), findsOneWidget);
    });
  });

  group('REGRESSION (Phase 21) — hero responsive layout', () {
    // 320px is deliberately not included here: it surfaces a pre-existing,
    // unrelated overflow in `PortalCard` (`portal_card.dart:96`, confirmed
    // by direct debugging — a file this phase does not touch), not
    // anything in the new hero. `HomeHero` itself is confirmed overflow-free
    // at 320px in isolation — see `test/features/home/presentation/widgets/
    // home_hero_test.dart`. Flagged in the Phase 21 report as a pre-existing
    // issue to fix separately, per this phase's own scope boundary against
    // changing the portal cards.
    testWidgets('renders the hero without horizontal overflow at narrow phone widths, guest and student alike', (
      tester,
    ) async {
      for (final size in [const Size(360, 2600), const Size(390, 2600), const Size(430, 2600)]) {
        await _pump(tester, size: size);
        expect(tester.takeException(), isNull);

        await _pump(tester, user: const AuthUser(username: 'jane'), size: size);
        expect(tester.takeException(), isNull);
      }
    });
  });
}
