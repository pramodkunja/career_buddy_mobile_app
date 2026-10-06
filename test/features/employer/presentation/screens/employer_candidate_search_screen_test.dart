import 'package:career_buddy_lms/core/errors/failures.dart';
import 'package:career_buddy_lms/core/utils/result.dart';
import 'package:career_buddy_lms/features/auth/domain/entities/auth_user.dart';
import 'package:career_buddy_lms/features/auth/domain/entities/student_registration_data.dart';
import 'package:career_buddy_lms/features/auth/domain/repositories/auth_repository.dart';
import 'package:career_buddy_lms/features/auth/presentation/providers/auth_providers.dart';
import 'package:career_buddy_lms/features/employer/domain/entities/employer_candidate_search.dart';
import 'package:career_buddy_lms/features/employer/domain/repositories/employer_candidate_search_repository.dart';
import 'package:career_buddy_lms/features/employer/presentation/providers/employer_candidate_search_providers.dart';
import 'package:career_buddy_lms/features/employer/presentation/screens/employer_candidate_search_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

/// `BuddyChatbotOverlay` (now part of every screen's `Scaffold`, per the
/// web's unconditional `{% include 'includes/aria_assistant.html' %}`)
/// reads `authControllerProvider` for its greeting, which otherwise falls
/// through to `authRepositoryProvider` -> `authRemoteDataSourceProvider` ->
/// `apiClientProvider` (unimplemented outside `main()`). Overriding
/// `authRepositoryProvider` directly — same pattern as
/// `GrammarDetailScreen`'s own test doubles — avoids that without this
/// screen's own tests needing to care about auth at all.
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

class _FakeRepository implements EmployerCandidateSearchRepository {
  _FakeRepository(this.result);

  Result<List<EmployerCandidateSearchResult>> result;
  String? lastQuery;
  int callCount = 0;

  @override
  Future<Result<List<EmployerCandidateSearchResult>>> search({
    String query = '',
    String location = '',
    String experience = '',
  }) async {
    callCount++;
    lastQuery = query;
    return result;
  }
}

const _oneCandidate = [
  EmployerCandidateSearchResult(
    name: 'Priya Sharma',
    email: 'priya@example.com',
    phone: '+919876543210',
    location: 'Bengaluru',
    experience: '5+ Years',
    skillCount: 2,
    industry: 'Information Technology',
    education: 'B.Tech',
    skills: ['Python', 'Django'],
    resumeUrl: '/media/resumes/priya.pdf',
  ),
];

Future<_FakeRepository> _pump(WidgetTester tester, Result<List<EmployerCandidateSearchResult>> result) async {
  tester.view.physicalSize = const Size(400, 2200);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);

  final repo = _FakeRepository(result);
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        authRepositoryProvider.overrideWithValue(_FakeAuthRepository()),
        employerCandidateSearchRepositoryProvider.overrideWithValue(repo),
      ],
      child: const MaterialApp(home: EmployerCandidateSearchScreen()),
    ),
  );
  await tester.pump();
  return repo;
}

void main() {
  group('EmployerCandidateSearchScreen', () {
    testWidgets('loads results on first build with no filters, matching the web default', (tester) async {
      final repo = await _pump(tester, const Success(_oneCandidate));

      expect(repo.callCount, 1);
      expect(repo.lastQuery, '');
      expect(find.text('Priya Sharma'), findsOneWidget);
      expect(find.text('Found 1 Candidates'), findsOneWidget);
      expect(find.text('2 matches'), findsOneWidget);
    });

    testWidgets('shows the no-filters empty-state copy when results are empty and nothing was searched', (tester) async {
      await _pump(tester, const Success([]));

      expect(find.text('No candidates available'), findsOneWidget);
    });

    testWidgets('typing a query and tapping Search refetches with that query', (tester) async {
      final repo = await _pump(tester, const Success(_oneCandidate));

      await tester.enterText(find.widgetWithText(TextField, 'Skills or Keywords'), 'python');
      await tester.tap(find.text('Search'));
      await tester.pump();

      expect(repo.lastQuery, 'python');
      expect(repo.callCount, 2);
    });

    testWidgets('shows a retryable error view for a generic failure', (tester) async {
      await _pump(tester, const Failed(ServerFailure()));

      expect(find.text('Retry'), findsOneWidget);
    });
  });
}
