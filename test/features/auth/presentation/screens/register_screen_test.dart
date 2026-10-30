import 'package:career_buddy_lms/core/utils/result.dart';
import 'package:career_buddy_lms/features/auth/domain/entities/auth_user.dart';
import 'package:career_buddy_lms/features/auth/domain/entities/student_registration_data.dart';
import 'package:career_buddy_lms/features/auth/domain/repositories/auth_repository.dart';
import 'package:career_buddy_lms/features/auth/presentation/providers/auth_providers.dart';
import 'package:career_buddy_lms/features/auth/presentation/screens/register_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

/// Phase 68 (`UI-A-004`) added this screen's first-ever test file, scoped
/// to its new header. Phase 69 fixes the real, pre-existing dropdown
/// overflow Phase 68 found and documented but deliberately left untouched
/// (`docs/PHASE_68_AUTH_UI_PARITY_REPORT.md`) — the exception-draining
/// workaround that phase added is removed here now that the root cause is
/// fixed: every test below asserts `tester.takeException()` is `null`
/// after each pump, so a real regression would fail loudly instead of
/// being silently absorbed.
class _FakeAuthRepository implements AuthRepository {
  @override
  Future<AuthUser?> restoreSession() async => null;

  @override
  Future<Result<AuthUser>> login({required String usernameOrEmail, required String password}) async =>
      throw UnimplementedError();

  @override
  Future<Result<void>> logout() async => throw UnimplementedError();

  @override
  Future<Result<String>> sendOtp(String email) async => throw UnimplementedError();

  @override
  Future<Result<String>> verifyOtp({required String email, required String code}) async =>
      throw UnimplementedError();

  @override
  Future<Result<AuthUser>> register(StudentRegistrationData data) async => throw UnimplementedError();
}

/// Bounded pumps instead of `pumpAndSettle` — `BuddyChatbotOverlay`'s float
/// animation repeats forever, so `pumpAndSettle` never returns (same
/// reasoning as every other screen test in this app that includes it).
Future<void> _settle(WidgetTester tester, {int times = 6}) async {
  for (var i = 0; i < times; i++) {
    await tester.pump(const Duration(milliseconds: 100));
  }
}

Future<void> _pumpFullScreen(WidgetTester tester, {Size size = const Size(400, 3000)}) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);

  await tester.pumpWidget(
    ProviderScope(
      overrides: [authRepositoryProvider.overrideWithValue(_FakeAuthRepository())],
      child: const MaterialApp(home: RegisterScreen()),
    ),
  );
  await tester.pump();
}

void main() {
  group('RegisterHeader (Phase 68) — isolated', () {
    testWidgets('shows the real "Candidate Registration" header, subtitle, and icon', (tester) async {
      await tester.pumpWidget(const MaterialApp(home: Scaffold(body: RegisterHeader())));

      expect(find.text('Candidate Registration'), findsOneWidget);
      expect(
        find.text('Create your account to access learning activities, resume builder & job matching'),
        findsOneWidget,
      );
      expect(find.byIcon(Icons.person_add_outlined), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('renders without overflow at a narrow phone width', (tester) async {
      tester.view.physicalSize = const Size(320, 400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      await tester.pumpWidget(const MaterialApp(home: Scaffold(body: RegisterHeader())));

      expect(tester.takeException(), isNull);
    });
  });

  group('RegisterScreen', () {
    testWidgets('shows the new header and no longer duplicates it in the AppBar', (tester) async {
      await _pumpFullScreen(tester);
      expect(tester.takeException(), isNull);

      expect(find.text('Candidate Registration'), findsOneWidget);
      // The AppBar no longer shows its own title — the in-body header is
      // the sole heading now, matching the real page's own single header.
      // ("Create Account" still legitimately appears once, as the form's
      // own submit button label — unrelated to the removed AppBar title.)
      expect(
        find.descendant(of: find.byType(AppBar), matching: find.text('Create Account')),
        findsNothing,
      );
    });

    testWidgets('existing form fields are still present and unchanged', (tester) async {
      await _pumpFullScreen(tester);
      expect(tester.takeException(), isNull);

      expect(find.text('First Name'), findsOneWidget);
      expect(find.text('Last Name'), findsOneWidget);
      expect(find.text('Email Address'), findsOneWidget);
      expect(find.text('Choose a Username'), findsOneWidget);
      expect(find.text('Password'), findsOneWidget);
    });

    // Phase 69 — reproduces, and then demonstrates the fix for, the real
    // `RenderFlex` overflow Phase 68 discovered and deliberately left
    // unfixed. `tester.takeException()` is asserted `null` directly after
    // the pump that used to throw it — no draining, no suppression.
    group('dropdown overflow fix (Phase 69)', () {
      testWidgets('renders at a 400-logical-pixel width with no layout exceptions', (tester) async {
        await _pumpFullScreen(tester, size: const Size(400, 3000));

        expect(tester.takeException(), isNull);
      });

      testWidgets('renders at a 360-logical-pixel width with no layout exceptions', (tester) async {
        await _pumpFullScreen(tester, size: const Size(360, 3000));

        expect(tester.takeException(), isNull);
      });

      testWidgets('renders at a 320-logical-pixel width with no layout exceptions', (tester) async {
        await _pumpFullScreen(tester, size: const Size(320, 3000));

        expect(tester.takeException(), isNull);
      });

      testWidgets('all 5 dropdown fields built by the shared helper are present', (tester) async {
        await _pumpFullScreen(tester);
        expect(tester.takeException(), isNull);

        expect(find.widgetWithText(DropdownButtonFormField<String>, 'Select Gender'), findsOneWidget);
        expect(find.widgetWithText(DropdownButtonFormField<String>, 'Select Blood Group'), findsOneWidget);
        expect(find.widgetWithText(DropdownButtonFormField<String>, 'Select Highest Education'), findsOneWidget);
        expect(find.widgetWithText(DropdownButtonFormField<String>, 'Select Additional Education'), findsOneWidget);
        expect(find.widgetWithText(DropdownButtonFormField<String>, 'Select Industry'), findsOneWidget);
      });

      testWidgets(
        'the longest real option labels (Education and Industry) fit within the closed field with no overflow',
        (tester) async {
          // The 2 option lists whose longest label actually caused the
          // confirmed overflow (`kEducationLevelOptions`'s "Under-Graduate
          // / Degree", `kIndustryOptions`'s "Agriculture & Food
          // Processing") — reproduced directly before this phase's fix.
          // `DropdownButtonFormField` builds a real `DropdownButton`
          // internally (`DropdownButton._formField`), which is where
          // `isExpanded` actually lands — checked directly here rather
          // than just trusting the absence of an exception.
          await _pumpFullScreen(tester, size: const Size(360, 3000));
          expect(tester.takeException(), isNull);

          final educationButton = tester.widget<DropdownButton<String>>(
            find.descendant(
              of: find.widgetWithText(DropdownButtonFormField<String>, 'Select Highest Education'),
              matching: find.byType(DropdownButton<String>),
            ),
          );
          expect(educationButton.isExpanded, isTrue);

          final industryButton = tester.widget<DropdownButton<String>>(
            find.descendant(
              of: find.widgetWithText(DropdownButtonFormField<String>, 'Select Industry'),
              matching: find.byType(DropdownButton<String>),
            ),
          );
          expect(industryButton.isExpanded, isTrue);
        },
      );

      testWidgets('opening the Education dropdown and selecting its longest label works, with no overflow', (
        tester,
      ) async {
        await _pumpFullScreen(tester, size: const Size(360, 3000));
        expect(tester.takeException(), isNull);

        await tester.ensureVisible(find.widgetWithText(DropdownButtonFormField<String>, 'Select Highest Education'));
        await tester.pump();
        await tester.tap(find.widgetWithText(DropdownButtonFormField<String>, 'Select Highest Education'));
        await _settle(tester);
        expect(tester.takeException(), isNull);
        expect(find.text('Under-Graduate / Degree'), findsWidgets);

        await tester.tap(find.text('Under-Graduate / Degree').last);
        await _settle(tester);

        expect(tester.takeException(), isNull);
        // The closed field now shows the selected value — confirms the
        // callback/state update still works after adding `isExpanded` and
        // the item `Text`'s `maxLines`/`overflow`.
        expect(find.text('Under-Graduate / Degree'), findsOneWidget);
      });

      testWidgets('opening the Industry dropdown and selecting its longest label works, with no overflow', (
        tester,
      ) async {
        await _pumpFullScreen(tester, size: const Size(360, 3000));
        expect(tester.takeException(), isNull);

        await tester.ensureVisible(find.widgetWithText(DropdownButtonFormField<String>, 'Select Industry'));
        await tester.pump();
        await tester.tap(find.widgetWithText(DropdownButtonFormField<String>, 'Select Industry'));
        await _settle(tester);
        expect(tester.takeException(), isNull);
        expect(find.text('Agriculture & Food Processing'), findsWidgets);

        await tester.tap(find.text('Agriculture & Food Processing').last);
        await _settle(tester);

        expect(tester.takeException(), isNull);
        expect(find.text('Agriculture & Food Processing'), findsOneWidget);
      });

      testWidgets('selecting a short-label option (Gender) still works exactly as before', (tester) async {
        await _pumpFullScreen(tester, size: const Size(360, 3000));
        expect(tester.takeException(), isNull);

        await tester.tap(find.widgetWithText(DropdownButtonFormField<String>, 'Select Gender'));
        await _settle(tester);
        expect(tester.takeException(), isNull);

        await tester.tap(find.text('Female').last);
        await _settle(tester);

        expect(tester.takeException(), isNull);
        expect(find.text('Female'), findsOneWidget);
      });
    });

    testWidgets('a required-field validation error still appears on submit with nothing filled in', (tester) async {
      await _pumpFullScreen(tester);
      expect(tester.takeException(), isNull);

      await tester.ensureVisible(find.widgetWithText(ElevatedButton, 'Create Account'));
      await tester.tap(find.widgetWithText(ElevatedButton, 'Create Account'));
      await _settle(tester);

      expect(tester.takeException(), isNull);
      expect(find.text('This field is required.'), findsWidgets);
    });
  });
}
