import 'package:career_buddy_lms/app/router/route_paths.dart';
import 'package:career_buddy_lms/core/errors/failures.dart';
import 'package:career_buddy_lms/core/utils/result.dart';
import 'package:career_buddy_lms/features/auth/domain/entities/auth_user.dart';
import 'package:career_buddy_lms/features/auth/domain/entities/student_registration_data.dart';
import 'package:career_buddy_lms/features/auth/domain/repositories/auth_repository.dart';
import 'package:career_buddy_lms/features/auth/presentation/providers/auth_providers.dart';
import 'package:career_buddy_lms/features/jam/domain/entities/jam_history_profile.dart';
import 'package:career_buddy_lms/features/jam/domain/repositories/jam_history_repository.dart';
import 'package:career_buddy_lms/features/jam/domain/entities/jam_assessment.dart';
import 'package:career_buddy_lms/features/jam/domain/entities/jam_session_result.dart';
import 'package:career_buddy_lms/features/jam/presentation/providers/jam_providers.dart';
import 'package:career_buddy_lms/features/jam/presentation/screens/jam_history_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

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

class _FakeRepository implements JamHistoryRepository {
  _FakeRepository(this.result);

  Result<JamHistoryPage> result;
  int? lastDeletedSessionId;
  int? lastDeletedAssessmentId;

  @override
  Future<Result<JamHistoryPage>> getHistoryPage() async => result;

  @override
  Future<Result<JamSessionResult>> getSessionDetail(int sessionId) async => throw UnimplementedError();

  @override
  Future<Result<JamAssessmentResult>> getAssessmentResult(int assessmentId) async => throw UnimplementedError();

  @override
  Future<Result<void>> deleteSession(int sessionId) async {
    lastDeletedSessionId = sessionId;
    return const Success(null);
  }

  @override
  Future<Result<void>> deleteAssessment(int assessmentId) async {
    lastDeletedAssessmentId = assessmentId;
    return const Success(null);
  }
}

const _oneOfEach = JamHistoryPage(
  sessions: [
    JamHistorySession(
      sessionId: 42,
      topicTitle: 'Business Negotiation',
      difficulty: 'medium',
      createdAt: 'Sep 15 2026 02:30 PM',
      durationDisplay: '1m 5s',
      overallScore: 18,
    ),
  ],
  assessments: [
    JamHistoryAssessment(
      assessmentId: 7,
      createdAt: 'Sep 20 2026 11:00 AM',
      easyTopicTitle: 'Self Introduction',
      mediumTopicTitle: 'Business Negotiation',
      hardTopicTitle: 'Conflict Resolution',
    ),
  ],
);

Future<_FakeRepository> _pump(WidgetTester tester, Result<JamHistoryPage> result) async {
  final repo = _FakeRepository(result);
  final router = GoRouter(
    initialLocation: RoutePaths.jamHistory,
    routes: [
      GoRoute(path: RoutePaths.jamHistory, builder: (context, state) => const JamHistoryScreen()),
      GoRoute(
        path: RoutePaths.jamSessionDetailPattern,
        builder: (context, state) => Scaffold(body: Text('SESSION:${state.pathParameters['id']}')),
      ),
      GoRoute(
        path: RoutePaths.jamAssessmentDetailPattern,
        builder: (context, state) => Scaffold(body: Text('ASSESSMENT:${state.pathParameters['id']}')),
      ),
    ],
  );

  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        authRepositoryProvider.overrideWithValue(_FakeAuthRepository()),
        jamHistoryRepositoryProvider.overrideWithValue(repo),
      ],
      child: MaterialApp.router(routerConfig: router),
    ),
  );
  await tester.pump();
  return repo;
}

void main() {
  group('JamHistoryScreen', () {
    testWidgets('renders the Regular Sessions tab by default', (tester) async {
      await _pump(tester, const Success(_oneOfEach));

      expect(find.text('Business Negotiation'), findsOneWidget);
      expect(find.text('1m 5s'), findsOneWidget);
      expect(find.text('★ 18'), findsOneWidget);
    });

    testWidgets('switching to the Assessments tab shows assessments', (tester) async {
      await _pump(tester, const Success(_oneOfEach));

      await tester.tap(find.text('Assessments'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));

      expect(find.textContaining('Assessment on Sep 20 2026'), findsOneWidget);
    });

    testWidgets('tapping a session navigates to its detail screen', (tester) async {
      await _pump(tester, const Success(_oneOfEach));

      await tester.tap(find.text('Business Negotiation'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));

      expect(find.text('SESSION:42'), findsOneWidget);
    });

    testWidgets('deleting a session shows a confirmation and calls the repository', (tester) async {
      final repo = await _pump(tester, const Success(_oneOfEach));

      await tester.tap(find.byIcon(Icons.delete_outline).first);
      await tester.pump();
      expect(find.text('Delete this session?'), findsOneWidget);

      await tester.tap(find.widgetWithText(TextButton, 'Delete'));
      await tester.pump();
      await tester.pump();

      expect(repo.lastDeletedSessionId, 42);
    });

    testWidgets('canceling a delete leaves the session untouched', (tester) async {
      final repo = await _pump(tester, const Success(_oneOfEach));

      await tester.tap(find.byIcon(Icons.delete_outline).first);
      await tester.pump();
      await tester.tap(find.text('Cancel'));
      await tester.pump();

      expect(repo.lastDeletedSessionId, isNull);
    });

    testWidgets('shows empty-state copy for both tabs when there is nothing', (tester) async {
      await _pump(tester, const Success(JamHistoryPage(sessions: [], assessments: [])));

      expect(find.text('No regular sessions found.'), findsOneWidget);
      await tester.tap(find.text('Assessments'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));
      expect(find.text('No diagnostic assessments found.'), findsOneWidget);
    });

    testWidgets('shows a retryable error view for a generic failure', (tester) async {
      await _pump(tester, const Failed(ServerFailure()));

      expect(find.text('Retry'), findsOneWidget);
    });
  });
}
