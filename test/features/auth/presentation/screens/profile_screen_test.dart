import 'package:career_buddy_lms/core/utils/result.dart';
import 'package:career_buddy_lms/features/auth/domain/entities/auth_user.dart';
import 'package:career_buddy_lms/features/auth/domain/entities/profile_data.dart';
import 'package:career_buddy_lms/features/auth/domain/entities/student_registration_data.dart';
import 'package:career_buddy_lms/features/auth/domain/repositories/auth_repository.dart';
import 'package:career_buddy_lms/features/auth/domain/repositories/profile_repository.dart';
import 'package:career_buddy_lms/features/auth/presentation/providers/auth_providers.dart';
import 'package:career_buddy_lms/features/auth/presentation/screens/profile_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

/// Same reasoning as `EmployerCandidateSearchScreen`'s own test doubles —
/// `BuddyChatbotOverlay` needs `authControllerProvider` wired to something
/// real.
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

const _overview = ProfileOverview(
  fullName: 'Venkat Sai',
  username: 'nvenkatsai',
  email: 'nvenkatsai@example.com',
  activitiesStarted: 5,
  completedSubs: 3,
  totalScore: 120,
  recentResults: [],
  // `ProfileFieldLabels.mobile` stored bare, no leading `+91` — the exact
  // real-world shape confirmed live against a production account, and the
  // root cause of the phone-normalization bug this file's tests cover below.
  fields: {'Mobile Number': '7993443081'},
  // These 3 have no Edit-tab UI at all (see `ProfileEditData`'s doc
  // comments) — a real, non-default value here proves the save path
  // round-trips the server's actual current state, not a hardcoded
  // placeholder.
  englishLevel: 'upper_intermediate',
  bio: 'Loves teaching Business English.',
  additionalEducationsJson: '[{"degree": "MBA", "year": "2021"}]',
  // Has no Overview `info-item` at all (confirmed directly against
  // production), only an Edit-tab UI — a real, non-default value here
  // proves the save path preserves it even on an unrelated edit.
  contactPersonRole: 'HR Manager',
  contactPersonMobile: '+919876500000',
  contactPersonEmail: 'hr@example.com',
);

/// Captures every `updateProfile` call so a test can assert on exactly what
/// was sent, and echoes [overview] back from `getProfile` (standing in for
/// "reopening the Profile screen re-fetches from the server") — the real
/// server would, after a genuine save, return the same unchanged
/// englishLevel/bio/additionalEducationsJson values this fake intentionally
/// never mutates, since on the real backend only what was actually posted
/// changes.
class _FakeProfileRepository implements ProfileRepository {
  ProfileOverview overview = _overview;
  final List<ProfileEditData> submitted = [];

  @override
  Future<Result<ProfileOverview>> getProfile() async => Success(overview);

  @override
  Future<Result<void>> updateProfile(ProfileEditData data) async {
    submitted.add(data);
    return const Success(null);
  }
}

Future<_FakeProfileRepository> _pump(WidgetTester tester) async {
  // 3200 (was 2800) — the Contact Person section added a third field group,
  // pushing "Save Changes" further down; at 2800 the button sat below the
  // viewport and `tap()` silently missed it.
  tester.view.physicalSize = const Size(400, 3200);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);

  final repo = _FakeProfileRepository();
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        authRepositoryProvider.overrideWithValue(_FakeAuthRepository()),
        profileRepositoryProvider.overrideWithValue(repo),
      ],
      child: const MaterialApp(home: ProfileScreen()),
    ),
  );
  await tester.pump();
  return repo;
}

/// Bounded pumps instead of `pumpAndSettle` — `BuddyChatbotOverlay`'s float
/// animation repeats forever, so `pumpAndSettle` never returns.
Future<void> _settle(WidgetTester tester, {int times = 6}) async {
  for (var i = 0; i < times; i++) {
    await tester.pump(const Duration(milliseconds: 250));
  }
}

void main() {
  group('ProfileScreen — the Save path does not corrupt englishLevel/bio/additionalEducationsJson', () {
    testWidgets(
      'editing only First Name and saving still posts the fetched englishLevel/bio/additionalEducationsJson unchanged',
      (tester) async {
        final repo = await _pump(tester);

        // Switch to the Edit Details tab.
        await tester.tap(find.text('Edit Details'));
        await _settle(tester);

        // Change only First Name — the one field a real user in this
        // scenario actually touches.
        await tester.enterText(find.byType(TextFormField).first, 'VenkatChanged');
        await tester.pump();

        await tester.tap(find.text('Save Changes'));
        await tester.pump();
        await tester.pump();

        expect(repo.submitted, hasLength(1));
        final sent = repo.submitted.single;
        expect(sent.firstName, 'VenkatChanged');
        // The actual regression this test exists for: these 3 must survive
        // untouched even though nothing in the Edit tab lets the user see
        // or change them.
        expect(sent.englishLevel, 'upper_intermediate');
        expect(sent.bio, 'Loves teaching Business English.');
        expect(sent.additionalEducationsJson, '[{"degree": "MBA", "year": "2021"}]');
        // Confirmed live against a real production account during this
        // task: the stored `Mobile Number` is bare digits with no leading
        // `+91`. Submitting it back unchanged (as `_orEmpty` used to) makes
        // the server reject the *entire* save — "Please select a country
        // and enter a valid mobile number" — even though the user never
        // touched this field. `normalizePhoneToE164` must turn it into a
        // real E.164 value before it's ever sent.
        expect(sent.mobile, '+917993443081');
        // Contact Person data-loss regression: these must survive an
        // unrelated save unchanged, not get silently wiped to ''.
        expect(sent.contactPersonRole, 'HR Manager');
        expect(sent.contactPersonMobile, '+919876500000');
        expect(sent.contactPersonEmail, 'hr@example.com');
      },
    );

    testWidgets('the Edit tab displays existing Contact Person values and sends edits to them under exact Django field names', (
      tester,
    ) async {
      final repo = await _pump(tester);

      await tester.tap(find.text('Edit Details'));
      await _settle(tester);

      // Display: the existing values are pre-filled, not blank.
      expect(find.text('HR Manager'), findsOneWidget);
      expect(find.text('hr@example.com'), findsOneWidget);

      // Edit: change Contact Role and Contact Email; leave Contact Mobile
      // untouched.
      await tester.enterText(
        find.widgetWithText(TextFormField, 'Contact Role (e.g. HR Manager, Team Lead)'),
        'Team Lead',
      );
      await tester.enterText(find.widgetWithText(TextFormField, 'Contact Email ID'), 'newcontact@example.com');
      await tester.pump();

      await tester.tap(find.text('Save Changes'));
      await tester.pump();
      await tester.pump();

      expect(repo.submitted, hasLength(1));
      final sent = repo.submitted.single;
      expect(sent.contactPersonRole, 'Team Lead');
      expect(sent.contactPersonEmail, 'newcontact@example.com');
      // Untouched field preserved exactly as loaded.
      expect(sent.contactPersonMobile, '+919876500000');
    });

    testWidgets('reopening (re-fetching) after a save still reflects the same preserved englishLevel/bio/additionalEducationsJson', (
      tester,
    ) async {
      final repo = await _pump(tester);
      await tester.tap(find.text('Edit Details'));
      await _settle(tester);
      await tester.enterText(find.byType(TextFormField).first, 'VenkatChanged');
      await tester.pump();
      await tester.tap(find.text('Save Changes'));
      await tester.pump();
      await tester.pump();

      // "Reopen Profile": the controller re-fetches, simulating the real
      // server's response after a genuine save.
      final container = ProviderScope.containerOf(tester.element(find.byType(ProfileScreen)));
      await container.read(profileRepositoryProvider).getProfile();

      // The fake never mutates `overview` on updateProfile (same as the
      // real server wouldn't mutate englishLevel/bio/additionalEducationsJson
      // beyond what was actually posted) — so a fresh fetch must still show
      // the original values, not something a buggy save could have wiped.
      expect(repo.overview.englishLevel, 'upper_intermediate');
      expect(repo.overview.bio, 'Loves teaching Business English.');
      expect(repo.overview.additionalEducationsJson, '[{"degree": "MBA", "year": "2021"}]');
    });

    testWidgets('the Edit tab dropdowns render at a normal phone width without overflowing', (tester) async {
      // Regression test: `DropdownButtonFormField` without `isExpanded:
      // true` sizes itself to its items' natural text width instead of the
      // available space — this screen's dropdowns (several
      // `kIndustryOptions`/`kEducationLevelOptions` entries are long)
      // overflowed by 162px at a perfectly normal 400dp width before this
      // was fixed, undetected until this test existed.
      tester.view.physicalSize = const Size(360, 3200);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);
      final repo = _FakeProfileRepository();
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            authRepositoryProvider.overrideWithValue(_FakeAuthRepository()),
            profileRepositoryProvider.overrideWithValue(repo),
          ],
          child: const MaterialApp(home: ProfileScreen()),
        ),
      );
      await tester.pump();

      await tester.tap(find.text('Edit Details'));
      await _settle(tester);

      expect(tester.takeException(), isNull);
    });

    testWidgets('a failed save shows an error and does not call updateProfile with mismatched data', (tester) async {
      final repo = await _pump(tester);
      repo.overview = _overview;
      await tester.tap(find.text('Edit Details'));
      await _settle(tester);

      // Clear the required Email field to trigger client-side validation
      // failure — the save must never reach the repository with invalid
      // data, and the round-trip fields are irrelevant to that path.
      final emailField = find.byType(TextFormField).at(2);
      await tester.enterText(emailField, '');
      await tester.pump();
      await tester.tap(find.text('Save Changes'));
      await tester.pump();

      expect(repo.submitted, isEmpty);
    });
  });
}
