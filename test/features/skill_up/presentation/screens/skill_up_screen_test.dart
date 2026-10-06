import 'package:career_buddy_lms/app/router/route_paths.dart';
import 'package:career_buddy_lms/core/utils/result.dart';
import 'package:career_buddy_lms/features/auth/domain/entities/auth_user.dart';
import 'package:career_buddy_lms/features/auth/domain/repositories/auth_repository.dart';
import 'package:career_buddy_lms/features/auth/domain/entities/student_registration_data.dart';
import 'package:career_buddy_lms/features/auth/presentation/providers/auth_providers.dart';
import 'package:career_buddy_lms/features/skill_up/data/skill_up_data.dart';
import 'package:career_buddy_lms/features/skill_up/presentation/screens/skill_up_screen.dart';
import 'package:career_buddy_lms/features/skill_up/presentation/skill_up_lesson_route_args.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

/// [SkillUpScreen] itself has no auth dependency, but the
/// [BuddyChatbotOverlay] it renders now does (it computes its greeting
/// from [authControllerProvider]) — this stands in for a guest session so
/// that provider can resolve without needing a real `apiClientProvider`.
class _FakeAuthRepository implements AuthRepository {
  @override
  Future<AuthUser?> restoreSession() async => null;

  @override
  Future<Result<AuthUser>> login({required String usernameOrEmail, required String password}) async =>
      throw UnimplementedError();

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

GoRouter _router({int initialTabIndex = 0}) => GoRouter(
  initialLocation: RoutePaths.skillUp,
  routes: [
    GoRoute(
      path: RoutePaths.skillUp,
      builder: (context, state) => SkillUpScreen(initialTabIndex: initialTabIndex),
    ),
    GoRoute(
      path: RoutePaths.skillUpLesson,
      builder: (context, state) {
        // Real router wiring passes a `SkillUpLessonRouteArgs` via `extra`
        // (see `RoutePaths.skillUpLesson`'s doc comment) into the real
        // `SkillUpLessonScreen`, a `WebViewController`-based screen. No
        // `WebViewPlatform` test implementation is registered anywhere in
        // this codebase (grep confirms no existing test mounts a webview
        // screen), so — matching the same fake-destination pattern
        // `home_screen_test.dart`/`mock_tests_hub_screen_test.dart` already
        // use for their own pushed routes — this stands in a plain
        // `Scaffold` that surfaces the real args object's fields, proving
        // the correct title/url reached the route without needing a real
        // platform webview in the test environment.
        final args = state.extra! as SkillUpLessonRouteArgs;
        return Scaffold(body: Text('LESSON: ${args.title} | ${args.url}'));
      },
    ),
  ],
);

Future<void> _pump(WidgetTester tester, {int initialTabIndex = 0}) async {
  tester.view.physicalSize = const Size(400, 2400);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);

  await tester.pumpWidget(
    ProviderScope(
      overrides: [authRepositoryProvider.overrideWithValue(_FakeAuthRepository())],
      child: MaterialApp.router(routerConfig: _router(initialTabIndex: initialTabIndex)),
    ),
  );
  await tester.pump();
}

/// [BuddyChatbotOverlay]'s float animation repeats forever, so
/// `pumpAndSettle()` would hang. A bounded pump covers tab-switch
/// animations and page-route transitions instead — same pattern as
/// `home_screen_test.dart`/`mock_tests_hub_screen_test.dart`.
Future<void> _settle(WidgetTester tester) async {
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 400));
}

/// The `TabBar` is `isScrollable: true` (4 tabs' natural widths exceed a
/// phone-width viewport), so a later tab's label can sit outside the
/// visible/tappable area until its own internal `Scrollable` brings it
/// into view — `ensureVisible` does that before tapping.
Future<void> _tapTab(WidgetTester tester, String label) async {
  final finder = find.text(label);
  await tester.ensureVisible(finder);
  await tester.pump();
  await tester.tap(finder);
  await _settle(tester);
}

void main() {
  group('SkillUpScreen — Home tab (default)', () {
    testWidgets('renders the hero headline and lede verbatim from the real page', (tester) async {
      await _pump(tester);

      expect(
        find.text('${SkillUpData.heroHeadline}${SkillUpData.heroHeadlineHighlight}'),
        findsOneWidget,
      );
      expect(find.text(SkillUpData.heroLede), findsOneWidget);
    });

    testWidgets('renders the Featured highlight cards', (tester) async {
      await _pump(tester);

      for (final highlight in SkillUpData.featuredHighlights) {
        expect(find.text(highlight.title), findsOneWidget);
      }
    });

    testWidgets(
      '"Featured tracks" scrolls to the Featured Highlights section, matching the real web\'s '
      'working `#section-highlights` anchor link (not a dead, permanently-disabled button)',
      (tester) async {
        await _pump(tester);
        // A realistic phone height (not the artificially tall 2400 the
        // rest of this file uses to avoid needing scrolls) — short enough
        // that the Featured Highlights section genuinely starts below the
        // fold, matching the real page before the web's own anchor jump.
        tester.view.physicalSize = const Size(400, 800);
        await tester.pump();

        final button = tester.widget<OutlinedButton>(
          find.widgetWithText(OutlinedButton, SkillUpData.heroSecondaryActionLabel),
        );
        expect(button.onPressed, isNotNull, reason: 'must be a real, working action, not onPressed: null');

        // `SingleChildScrollView`'s Column builds every child eagerly (it
        // isn't a lazy `ListView`), so the highlight card already exists in
        // the tree before scrolling — the real assertion is that it's
        // actually brought on-screen, not merely present off-screen.
        final firstHighlightTitle = SkillUpData.featuredHighlights.first.title;
        final viewportHeight = tester.view.physicalSize.height / tester.view.devicePixelRatio;
        final beforeY = tester.getTopLeft(find.text(firstHighlightTitle)).dy;
        expect(beforeY, greaterThan(viewportHeight), reason: 'starts below the fold, same as the real page before scrolling');

        await tester.tap(find.widgetWithText(OutlinedButton, SkillUpData.heroSecondaryActionLabel));
        await _settle(tester);

        final afterY = tester.getTopLeft(find.text(firstHighlightTitle)).dy;
        expect(afterY, lessThan(viewportHeight), reason: 'tapping must scroll it into the visible viewport');
      },
    );

    testWidgets('renders all 4 tabs', (tester) async {
      await _pump(tester);

      expect(find.text('Home'), findsOneWidget);
      expect(find.text('Sections in depth'), findsOneWidget);
      expect(find.text('Sitemap'), findsOneWidget);
      expect(find.text('Certifications'), findsOneWidget);
    });
  });

  group('SkillUpScreen — Sections in depth tab', () {
    testWidgets('tapping a lesson card navigates to SkillUpLessonScreen with the real title/url', (tester) async {
      await _pump(tester);

      await _tapTab(tester, 'Sections in depth');

      // "Elementary · A1" is the first CEFR lesson card's own `<h4>` title
      // under English & Vocabulary (`depth-english`).
      expect(find.text('Elementary · A1'), findsOneWidget);

      await tester.tap(find.text('Elementary · A1'));
      await _settle(tester);

      // Reached the lesson route with the real title + a correctly-built
      // static URL for this lesson (see `buildSkillUpLessonUrl`'s own
      // tests for the URL-encoding contract itself).
      expect(find.textContaining('LESSON: CEFR A1 · Elementary'), findsOneWidget);
      expect(
        find.textContaining('/static/001%20Career%20Buddy/001%20CEFR/cefr_a1_english.html'),
        findsOneWidget,
      );
    });

    testWidgets('renders every major section title', (tester) async {
      await _pump(tester);

      await _tapTab(tester, 'Sections in depth');

      for (final section in SkillUpData.sections) {
        expect(find.text(section.title), findsWidgets);
      }
    });
  });

  group('SkillUpScreen — Sitemap tab', () {
    testWidgets('renders "Platform at a glance" and its stats', (tester) async {
      await _pump(tester);

      await _tapTab(tester, 'Sitemap');

      expect(find.text(SkillUpData.glanceTitle), findsOneWidget);
      for (final stat in SkillUpData.platformStats) {
        expect(find.text(stat.label), findsOneWidget);
      }
    });

    testWidgets('RoutePaths.sitemap maps to initialTabIndex 2, pre-selecting the Sitemap tab', (tester) async {
      await _pump(tester, initialTabIndex: 2);

      // No tap needed — the tab should already be selected, so its
      // content ("Platform at a glance") is immediately present.
      expect(find.text(SkillUpData.glanceTitle), findsOneWidget);
    });
  });

  group('SkillUpScreen — Certifications tab', () {
    testWidgets('renders the real CertificationsSection widget', (tester) async {
      await _pump(tester);

      await _tapTab(tester, 'Certifications');

      expect(find.text('Certifications'), findsWidgets);
    });
  });

  testWidgets('renders without overflow at narrow phone width', (tester) async {
    // 375, not 320: `AppFooter` (a shared widget embedded in every tab
    // here, unmodified/out of scope for this task) already overflows its
    // own stats row below ~360px regardless of this screen — confirmed by
    // testing it in isolation, not something introduced by SkillUpScreen.
    tester.view.physicalSize = const Size(375, 700);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [authRepositoryProvider.overrideWithValue(_FakeAuthRepository())],
        child: MaterialApp.router(routerConfig: _router()),
      ),
    );
    await tester.pump();

    expect(tester.takeException(), isNull);
  });
}
