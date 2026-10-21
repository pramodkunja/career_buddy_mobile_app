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
    GoRoute(
      path: RoutePaths.resumeRolePicker,
      builder: (context, state) =>
          const Scaffold(body: Text('Role Picker Screen')),
    ),
    GoRoute(
      path: RoutePaths.careerDepartments,
      builder: (context, state) =>
          Scaffold(body: Text('Career Departments Screen: ${state.extra}')),
    ),
    GoRoute(
      path: RoutePaths.resumeHistory,
      builder: (context, state) =>
          const Scaffold(body: Text('Resume History Screen')),
    ),
    GoRoute(
      path: RoutePaths.skillUpSections,
      builder: (context, state) =>
          const Scaffold(body: Text('Skill Up Sections Screen')),
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
          // Landing-page parity phase: the new resume-maker teaser section
          // also has its own "Create Resume" button — the hero's own is
          // first in tree order, same handling as "Find Jobs" above.
          expect(find.text('Create Resume').first, findsWidgets);
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

          // The hero's own "Create Resume" is first in tree order — see the
          // "all 3 CTA labels" test above for why `.first` is needed now.
          await tester.tap(find.text('Create Resume').first);
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

        // Landing-page parity phase: Platform Overview/Career Journey/Choose
        // Your Path now push this section further down than the test's
        // fixed viewport — scroll it into view first, same as the existing
        // footer tests already do for content below the fold.
        await tester.ensureVisible(find.text('Login').first);
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

        await tester.ensureVisible(find.text('Explore Job Seeker Portal'));
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

        await tester.ensureVisible(find.text('Explore Employer Portal'));
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

        // Landing-page parity phase: the new Skill Up teaser section's own
        // eyebrow pill is also literally "Skill Up" — the footer's link,
        // reproduced last in the page, is `.last` in tree order.
        await tester.dragUntilVisible(
          find.text('Skill Up').last,
          find.byType(SingleChildScrollView),
          const Offset(0, -300),
        );
        await tester.tap(find.text('Skill Up').last);
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

    group('landing-page parity — new sections', () {
      testWidgets(
        'renders every new section header added this phase',
        (tester) async {
          await _pump(tester);

          for (final heading in [
            'Everything you need to move your career forward', // Platform overview
            'Your career journey, step by step', // Career journey
            'Choose Your Path', // Choose your path
            'Seven core skill areas', // Skill Up
            'Turn your resume into a career advantage', // Resume & AI
            'Your career & learning assistant', // Meet Buddy
            'Why job seekers and employers choose CareerBuddy', // About
            'Create your resume', // Resume maker teaser
            'Learn How CareerBuddy Works', // Tutorials
            'What our job seekers say', // Testimonials
            'What our employers say',
          ]) {
            expect(
              find.text(heading),
              findsOneWidget,
              reason: 'missing section heading: $heading',
            );
          }
        },
      );

      testWidgets(
        'tapping IT Job Seeker in Choose Your Path opens IT career browsing '
        '(Phase 43 — previously opened the generic Role Picker)',
        (tester) async {
          await _pump(tester);

          await tester.ensureVisible(find.text('IT Job Seeker'));
          await tester.tap(find.text('IT Job Seeker'));
          await _pumpAfterTap(tester);

          expect(
            find.text('Career Departments Screen: it'),
            findsOneWidget,
          );
        },
      );

      testWidgets(
        'tapping Non-IT Job Seeker in Choose Your Path opens Non-IT career browsing',
        (tester) async {
          await _pump(tester);

          await tester.ensureVisible(find.text('Non-IT Job Seeker'));
          await tester.tap(find.text('Non-IT Job Seeker'));
          await _pumpAfterTap(tester);

          expect(
            find.text('Career Departments Screen: non-it'),
            findsOneWidget,
          );
        },
      );

      testWidgets(
        'tapping a Skill Up row navigates to the matching Activities category',
        (tester) async {
          await _pump(tester);

          await tester.ensureVisible(find.text('Speaking & Presentation'));
          await tester.tap(find.text('Speaking & Presentation'));
          await _pumpAfterTap(tester);

          expect(find.text('Activities Screen'), findsOneWidget);
        },
      );

      testWidgets(
        'tapping Ask Buddy in the Meet Buddy section opens the chat panel',
        (tester) async {
          await _pump(tester);

          // The Meet Buddy section's own button and the footer's "Ask
          // Buddy" link (both open the same panel) share this label — the
          // section's is first in tree order.
          await tester.ensureVisible(find.text('Ask Buddy').first);
          await tester.tap(find.text('Ask Buddy').first);
          await tester.pump();

          // The chat panel's own close button only exists once the panel
          // (not just the launcher/greeting bubble) is open.
          expect(find.byIcon(Icons.close), findsOneWidget);
        },
      );

      testWidgets(
        'tapping a Featured Tutorial opens the video dialog',
        (tester) async {
          await _pump(tester);

          await tester.ensureVisible(find.text('Welcome to CareerBuddy'));
          await tester.tap(find.text('Welcome to CareerBuddy'));
          await tester.pump();

          // Opens the dialog shell immediately (loading spinner) — this
          // test deliberately does not wait for the real network video to
          // load (no network access in a unit test), only that the real
          // tutorial-video action is wired, not a placeholder.
          expect(find.byType(Dialog), findsOneWidget);
          expect(find.byType(CircularProgressIndicator), findsOneWidget);
        },
      );
    });
  });

  group('Phase 49 — path picker popup', () {
    testWidgets('does not appear before 5 seconds have elapsed', (tester) async {
      await _pump(tester);

      await tester.pump(const Duration(seconds: 4));

      expect(find.text('Which path suits you?'), findsNothing);
    });

    testWidgets('appears 5 seconds after load for a guest, with the real popup copy', (tester) async {
      await _pump(tester);

      await tester.pump(const Duration(seconds: 5));
      await tester.pump();

      expect(find.text('Which path suits you?'), findsOneWidget);
      expect(find.text("Pick a track and we'll show you the roles that match."), findsOneWidget);
      expect(find.text('Software, data, AI, cloud, testing and security roles.'), findsOneWidget);
      // The popup's own Non-IT copy ("Technical and Non-Technical
      // opportunities beyond IT.") omits "Explore ", unlike the inline
      // section's wording — both exist on the real page as genuinely
      // different strings, so the popup must not just reuse the inline
      // text.
      expect(find.text('Technical and Non-Technical opportunities beyond IT.'), findsOneWidget);
    });

    testWidgets('never appears for an authenticated (non-employer) user', (tester) async {
      await _pump(tester, user: const AuthUser(username: 'jane'));

      await tester.pump(const Duration(seconds: 5));
      await tester.pump();

      expect(find.text('Which path suits you?'), findsNothing);
    });

    testWidgets('tapping IT Job Seeker in the popup navigates and dismisses it', (tester) async {
      await _pump(tester);
      await tester.pump(const Duration(seconds: 5));
      await tester.pump();

      await tester.tap(find.byKey(const Key('path-picker-it-card')));
      await _pumpAfterTap(tester);

      expect(find.text('Career Departments Screen: it'), findsOneWidget);
      expect(find.text('Which path suits you?'), findsNothing);
    });

    testWidgets('tapping Non-IT Job Seeker advances to step 2 (Technical/Non-Technical), not a direct navigation', (
      tester,
    ) async {
      await _pump(tester);
      await tester.pump(const Duration(seconds: 5));
      await tester.pump();

      await tester.tap(find.byKey(const Key('path-picker-nonit-card')));
      await tester.pump();

      expect(find.text('Technical or Non-Technical?'), findsOneWidget);
      expect(find.text('Choose the kind of Non-IT work you want to explore.'), findsOneWidget);
      expect(find.text('Career Departments Screen: it'), findsNothing);
    });

    testWidgets('step 2 "Back" returns to step 1', (tester) async {
      await _pump(tester);
      await tester.pump(const Duration(seconds: 5));
      await tester.pump();
      await tester.tap(find.byKey(const Key('path-picker-nonit-card')));
      await tester.pump();
      expect(find.text('Technical or Non-Technical?'), findsOneWidget);

      await tester.tap(find.text('Back'));
      await tester.pump();

      expect(find.text('Which path suits you?'), findsOneWidget);
    });

    testWidgets('step 2 "Technical" navigates to the Non-IT career browsing screen and dismisses the popup', (
      tester,
    ) async {
      await _pump(tester);
      await tester.pump(const Duration(seconds: 5));
      await tester.pump();
      await tester.tap(find.byKey(const Key('path-picker-nonit-card')));
      await tester.pump();

      await tester.tap(find.byKey(const Key('path-picker-technical-card')));
      await _pumpAfterTap(tester);

      expect(find.text('Career Departments Screen: non-it'), findsOneWidget);
      expect(find.text('Which path suits you?'), findsNothing);
    });

    testWidgets('step 2 "Non-Technical" navigates to the same Non-IT career browsing screen', (tester) async {
      await _pump(tester);
      await tester.pump(const Duration(seconds: 5));
      await tester.pump();
      await tester.tap(find.byKey(const Key('path-picker-nonit-card')));
      await tester.pump();

      await tester.tap(find.byKey(const Key('path-picker-nontechnical-card')));
      await _pumpAfterTap(tester);

      expect(find.text('Career Departments Screen: non-it'), findsOneWidget);
    });

    testWidgets(
      'REGRESSION (Phase 50): tapping outside the dialog (the barrier) does not dismiss it — '
      'the real <dialog> has no backdrop click handler',
      (tester) async {
        await _pump(tester);
        await tester.pump(const Duration(seconds: 5));
        await tester.pump();
        expect(find.text('Which path suits you?'), findsOneWidget);

        // A point clearly outside the dialog's own content box (near the
        // very top-left corner) but still within the modal barrier.
        await tester.tapAt(const Offset(5, 5));
        await tester.pump();

        expect(find.text('Which path suits you?'), findsOneWidget);
      },
    );

    testWidgets('the close (X) button dismisses the popup without navigating', (tester) async {
      await _pump(tester);
      await tester.pump(const Duration(seconds: 5));
      await tester.pump();

      await tester.tap(find.byKey(const Key('path-picker-close-button')));
      await tester.pump();

      expect(find.text('Which path suits you?'), findsNothing);
      expect(find.text('Career Departments Screen: it'), findsNothing);
    });

    testWidgets('"Maybe later" dismisses the popup without navigating', (tester) async {
      await _pump(tester);
      await tester.pump(const Duration(seconds: 5));
      await tester.pump();

      await tester.tap(find.byKey(const Key('path-picker-maybe-later-button')));
      await tester.pump();

      expect(find.text('Which path suits you?'), findsNothing);
    });

    testWidgets('choosing a path directly (before 5s) cancels the pending popup — it never appears afterward', (
      tester,
    ) async {
      await _pump(tester);

      await tester.ensureVisible(find.text('IT Job Seeker'));
      await tester.tap(find.text('IT Job Seeker'));
      await _pumpAfterTap(tester);
      expect(find.text('Career Departments Screen: it'), findsOneWidget);

      // The popup's own 5s timer was already running when the inline card
      // was tapped directly — it must not still fire afterward and cover
      // the screen the user already navigated to.
      await tester.pump(const Duration(seconds: 5));
      await tester.pump();

      expect(find.text('Which path suits you?'), findsNothing);
    });

    testWidgets('navigating away before 5s (e.g. via the hero CTA) suppresses the popup', (tester) async {
      await _pump(tester);

      await tester.tap(find.text('Get Started Free'));
      await _pumpAfterTap(tester);

      await tester.pump(const Duration(seconds: 5));
      await tester.pump();

      expect(find.text('Which path suits you?'), findsNothing);
    });

    testWidgets('renders without overflow at narrow phone widths, including the step 2 content', (tester) async {
      for (final size in [const Size(320, 700), const Size(360, 700), const Size(390, 700)]) {
        await _pump(tester, size: size);
        await tester.pump(const Duration(seconds: 5));
        await tester.pump();
        expect(tester.takeException(), isNull);

        await tester.tap(find.byKey(const Key('path-picker-nonit-card')));
        await tester.pump();
        expect(tester.takeException(), isNull);
      }
    });

    testWidgets(
      'REGRESSION (Phase 50): repeated pumps/rebuilds after the popup appears never produce a 2nd dialog',
      (tester) async {
        await _pump(tester);
        await tester.pump(const Duration(seconds: 5));
        await tester.pump();
        expect(find.byType(Dialog), findsOneWidget);

        // Several more frames/rebuilds (the Buddy launcher's own repeating
        // float animation alone causes ongoing rebuilds) must not stack a
        // 2nd popup instance.
        for (var i = 0; i < 5; i++) {
          await tester.pump(const Duration(milliseconds: 200));
        }

        expect(find.byType(Dialog), findsOneWidget);
        expect(find.text('Which path suits you?'), findsOneWidget);
      },
    );
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
