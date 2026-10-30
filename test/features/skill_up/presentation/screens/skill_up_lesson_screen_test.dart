import 'package:career_buddy_lms/core/network/api_client.dart';
import 'package:career_buddy_lms/core/providers/core_providers.dart';
import 'package:career_buddy_lms/core/utils/result.dart';
import 'package:career_buddy_lms/features/auth/domain/entities/auth_user.dart';
import 'package:career_buddy_lms/features/auth/domain/entities/student_registration_data.dart';
import 'package:career_buddy_lms/features/auth/domain/repositories/auth_repository.dart';
import 'package:career_buddy_lms/features/auth/presentation/providers/auth_providers.dart';
import 'package:career_buddy_lms/features/skill_up/presentation/screens/skill_up_lesson_screen.dart';
import 'package:career_buddy_lms/features/skill_up/presentation/skill_up_lesson_route_args.dart';
import 'package:career_buddy_lms/shared/widgets/app_error_view.dart';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:webview_flutter_platform_interface/webview_flutter_platform_interface.dart';

/// Phase 75 — the first test coverage this screen has ever had (confirmed:
/// no `WebViewPlatform` fake existed anywhere in this codebase before this
/// phase). `webview_flutter`'s own factories
/// (`PlatformWebViewController`/`PlatformNavigationDelegate`/
/// `PlatformWebViewWidget`) require `WebViewPlatform.instance` to be set
/// before `SkillUpLessonScreen.initState` can even construct a
/// `WebViewController` — this fake is the minimum surface
/// `skill_up_lesson_screen.dart` actually calls (confirmed by reading it:
/// `setJavaScriptMode`/`setBackgroundColor`/`enableZoom`/
/// `setPlatformNavigationDelegate`/`loadRequest`/`canGoBack`/`goBack`, and
/// the navigation delegate's `onPageStarted`/`onPageFinished`/`onHttpError`/
/// `onWebResourceError`), not a general-purpose WebView test harness —
/// every other `PlatformWebViewController`/`PlatformNavigationDelegate`
/// method already has a safe default (throws `UnimplementedError`) from the
/// base class, which is fine since this screen never calls them.
/// Avoids `authRepositoryProvider`'s real implementation, which would reach
/// a real `FlutterSecureStorage` platform channel — unregistered in a plain
/// `flutter test` run. [BuddyChatbotOverlay] (rendered by this screen on
/// every build) reads `authControllerProvider`, so this is needed even
/// though this phase's own fix has nothing to do with authentication.
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

class _FakeWebViewPlatform extends WebViewPlatform {
  final List<_FakeWebViewPlatformController> controllers = [];

  @override
  PlatformWebViewController createPlatformWebViewController(
    PlatformWebViewControllerCreationParams params,
  ) {
    final controller = _FakeWebViewPlatformController(params);
    controllers.add(controller);
    return controller;
  }

  @override
  PlatformNavigationDelegate createPlatformNavigationDelegate(
    PlatformNavigationDelegateCreationParams params,
  ) => _FakeNavigationDelegate(params);

  @override
  PlatformWebViewWidget createPlatformWebViewWidget(
    PlatformWebViewWidgetCreationParams params,
  ) => _FakeWebViewWidget(params);
}

class _FakeWebViewPlatformController extends PlatformWebViewController {
  _FakeWebViewPlatformController(super.params) : super.implementation();

  _FakeNavigationDelegate? delegate;
  LoadRequestParams? lastLoadRequest;
  int loadRequestCallCount = 0;

  /// Settable per-test — simulates whichever page is "currently open" in
  /// this WebView's own navigation history, independent of the Flutter
  /// route stack. See [SkillUpLessonScreenState]'s doc comment (Phase 75).
  bool canGoBackValue = false;
  int goBackCallCount = 0;

  @override
  Future<void> setJavaScriptMode(JavaScriptMode javaScriptMode) async {}

  @override
  Future<void> setBackgroundColor(Color color) async {}

  @override
  Future<void> enableZoom(bool enabled) async {}

  @override
  Future<void> setPlatformNavigationDelegate(PlatformNavigationDelegate handler) async {
    delegate = handler as _FakeNavigationDelegate;
  }

  @override
  Future<void> loadRequest(LoadRequestParams params) async {
    loadRequestCallCount++;
    lastLoadRequest = params;
  }

  @override
  Future<bool> canGoBack() async => canGoBackValue;

  @override
  Future<void> goBack() async {
    goBackCallCount++;
  }
}

class _FakeNavigationDelegate extends PlatformNavigationDelegate {
  _FakeNavigationDelegate(super.params) : super.implementation();

  PageEventCallback? onPageStartedCallback;
  PageEventCallback? onPageFinishedCallback;
  HttpResponseErrorCallback? onHttpErrorCallback;
  WebResourceErrorCallback? onWebResourceErrorCallback;

  @override
  Future<void> setOnPageStarted(PageEventCallback onPageStarted) async {
    onPageStartedCallback = onPageStarted;
  }

  @override
  Future<void> setOnPageFinished(PageEventCallback onPageFinished) async {
    onPageFinishedCallback = onPageFinished;
  }

  @override
  Future<void> setOnHttpError(HttpResponseErrorCallback onHttpError) async {
    onHttpErrorCallback = onHttpError;
  }

  @override
  Future<void> setOnWebResourceError(WebResourceErrorCallback onWebResourceError) async {
    onWebResourceErrorCallback = onWebResourceError;
  }
}

class _FakeWebViewWidget extends PlatformWebViewWidget {
  _FakeWebViewWidget(super.params) : super.implementation();

  @override
  Widget build(BuildContext context) {
    // A real platform view (what `AndroidViewSurface` actually renders)
    // always sizes itself to fill every pixel Flutter gives it — it has to,
    // since the native view needs a fixed canvas size. `SizedBox.expand`
    // reproduces that, which matters here: `skill_up_lesson_screen.dart`'s
    // own `Scaffold.body` is a loose-constrained `Stack`, so a shrink-to-fit
    // fake (e.g. a bare `Text`) would make the *whole* body collapse to a
    // few pixels — starving `BuddyChatbotOverlay`'s own `Positioned`
    // sibling of real screen height and overflowing it, a layout artifact
    // of this fake, not a defect in either `BuddyChatbotOverlay` or this
    // phase's own fix.
    return const SizedBox.expand(child: ColoredBox(color: Colors.white, child: Text('fake webview')));
  }
}

/// Pushes [SkillUpLessonScreen] onto a plain [Navigator] stack (no
/// `go_router`) — this screen's own navigation only uses
/// [Navigator.of]/`PopScope`, so a bare [MaterialApp] is a faithful,
/// minimal host. Returns the [_FakeWebViewPlatformController] the screen's
/// own `initState` created, for the test to drive directly.
Future<_FakeWebViewPlatformController> _pumpLessonScreen(
  WidgetTester tester, {
  String title = 'Phonics · Letter Sounds',
  String url = 'https://careerbuddy4u.com/static/001%20Career%20Buddy/Vocabulary/phonics-01.html',
}) async {
  final platform = _FakeWebViewPlatform();
  WebViewPlatform.instance = platform;
  addTearDown(() {
    // Each test gets its own platform instance (fresh `controllers` list);
    // nothing to restore since `webview_flutter` has no real default to
    // reset to in a `flutter test` process.
  });

  // `flutter test`'s own default surface is far shorter (logical height)
  // than any real phone — too short for [BuddyChatbotOverlay]'s own
  // minimum footprint (confirmed: it overflows below this), the same
  // reason other screens hosting it set an explicit, realistic size
  // (`app_nav_drawer_test.dart`'s own narrow-viewport tests, etc.).
  await tester.binding.setSurfaceSize(const Size(400, 800));
  addTearDown(() => tester.binding.setSurfaceSize(null));

  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        apiClientProvider.overrideWithValue(ApiClient.forTesting(Dio())),
        authRepositoryProvider.overrideWithValue(_FakeAuthRepository()),
      ],
      child: MaterialApp(
        home: Builder(
          builder: (context) => Scaffold(
            body: Center(
              child: ElevatedButton(
                onPressed: () => Navigator.of(context).push(
                  MaterialPageRoute<void>(
                    builder: (_) => SkillUpLessonScreen(args: SkillUpLessonRouteArgs(title: title, url: url)),
                  ),
                ),
                child: const Text('open lesson'),
              ),
            ),
          ),
        ),
      ),
    ),
  );
  await tester.tap(find.text('open lesson'));
  // Not `pumpAndSettle()`: the screen's own loading state is a perpetually
  // -animating `CircularProgressIndicator`, which never "settles" on its
  // own — a fixed pump is enough to flush the push-route transition.
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 400));

  return platform.controllers.single;
}

void main() {
  group('SkillUpLessonScreen', () {
    testWidgets('shows a loading indicator, then the WebView once the page finishes loading', (tester) async {
      final controller = await _pumpLessonScreen(tester);

      expect(find.byType(CircularProgressIndicator), findsOneWidget);
      expect(find.text('fake webview'), findsOneWidget);

      controller.delegate!.onPageFinishedCallback!(controller.lastLoadRequest!.uri.toString());
      await tester.pump();

      expect(find.byType(CircularProgressIndicator), findsNothing);
      expect(find.text('fake webview'), findsOneWidget);
    });

    testWidgets('sends the lesson URL built from the route args as the real request', (tester) async {
      final controller = await _pumpLessonScreen(tester, url: 'https://example.com/lesson.html');

      expect(controller.loadRequestCallCount, 1);
      expect(controller.lastLoadRequest!.uri.toString(), 'https://example.com/lesson.html');
    });

    testWidgets(
      'Phase 38 regression: a 403 from SkillUpAccessMiddleware shows the locked view, not a generic error',
      (tester) async {
        final controller = await _pumpLessonScreen(tester);

        controller.delegate!.onHttpErrorCallback!(
          const HttpResponseError(response: WebResourceResponse(uri: null, statusCode: 403)),
        );
        await tester.pump();

        expect(find.text('fake webview'), findsNothing);
        expect(find.byType(CircularProgressIndicator), findsNothing);
      },
    );

    testWidgets('a non-403 HTTP error is not treated as locked content', (tester) async {
      final controller = await _pumpLessonScreen(tester);

      controller.delegate!.onHttpErrorCallback!(
        const HttpResponseError(response: WebResourceResponse(uri: null, statusCode: 500)),
      );
      await tester.pump();

      // Still showing the (loading) WebView stack — a 403 is the only HTTP
      // status this screen treats specially (`onHttpError`'s own early
      // return for anything else), matching `SkillUpAccessMiddleware`'s own
      // single, unambiguous status code for this exact request.
      expect(find.byType(CircularProgressIndicator), findsOneWidget);
    });

    testWidgets(
      'a main-frame web resource error shows a retryable error view, and Retry reloads the lesson',
      (tester) async {
        final controller = await _pumpLessonScreen(tester);

        controller.delegate!.onWebResourceErrorCallback!(
          const WebResourceError(errorCode: -2, description: 'net::ERR_INTERNET_DISCONNECTED', isForMainFrame: true),
        );
        await tester.pump();

        expect(
          find.text('This lesson page could not be loaded. Please check your connection and try again.'),
          findsOneWidget,
        );
        expect(controller.loadRequestCallCount, 1);

        await tester.tap(find.text('Retry'));
        await tester.pump();

        expect(controller.loadRequestCallCount, 2);
        // Retrying goes back to the loading state, not a stale error.
        expect(find.byType(CircularProgressIndicator), findsOneWidget);
      },
    );

    testWidgets('a sub-resource (non-main-frame) error is ignored, matching real browser-tab behavior', (
      tester,
    ) async {
      final controller = await _pumpLessonScreen(tester);
      controller.delegate!.onPageFinishedCallback!(controller.lastLoadRequest!.uri.toString());
      await tester.pump();

      controller.delegate!.onWebResourceErrorCallback!(
        const WebResourceError(errorCode: -2, description: 'a failed inline image', isForMainFrame: false),
      );
      await tester.pump();

      expect(find.text('fake webview'), findsOneWidget);
      expect(find.byType(AppErrorView), findsNothing);
    });

    group('Phase 75 — Android back navigation', () {
      testWidgets('pops the lesson screen when the WebView has no internal history', (tester) async {
        final controller = await _pumpLessonScreen(tester);
        controller.canGoBackValue = false;

        await simulateSystemBack(tester);
        for (var i = 0; i < 10; i++) {
          await tester.pump(const Duration(milliseconds: 100));
        }

        expect(controller.goBackCallCount, 0);
        // `Navigator` keeps the previous route's widgets in the tree even
        // while covered, so `find.text('open lesson')` alone can't tell
        // whether the lesson screen was actually popped — its own AppBar
        // title disappearing is the reliable signal.
        expect(
          find.text('Phonics · Letter Sounds'),
          findsNothing,
          reason: 'the lesson screen should have been popped',
        );
      });

      testWidgets(
        'navigates within the WebView instead of leaving the screen when internal history exists '
        '(e.g. a real lesson hub page like Vocabulary/Basicindex.html linking to its own phonics pages)',
        (tester) async {
          final controller = await _pumpLessonScreen(tester);
          controller.canGoBackValue = true;

          await simulateSystemBack(tester);
          await tester.pump();

          expect(controller.goBackCallCount, 1);
          expect(
            find.text('Phonics · Letter Sounds'),
            findsOneWidget,
            reason: 'the lesson screen must still be on screen',
          );
        },
      );
    });
  });
}

/// Mirrors the Android hardware/gesture back button, the same way
/// [PopScope] observes it — `Navigator.pop()` alone would skip
/// `PopScope.onPopInvokedWithResult` entirely (it's a system-back hook, not
/// a plain Navigator API), so a direct pop call cannot exercise this fix.
/// Same helper convention as `client_flow_test.dart`'s own `_systemBack`.
Future<void> simulateSystemBack(WidgetTester tester) async {
  await tester.binding.handlePopRoute();
}
