import 'package:career_buddy_lms/core/errors/failures.dart';
import 'package:career_buddy_lms/core/utils/result.dart';
import 'package:career_buddy_lms/features/auth/domain/entities/auth_user.dart';
import 'package:career_buddy_lms/features/auth/domain/entities/student_registration_data.dart';
import 'package:career_buddy_lms/features/auth/domain/repositories/auth_repository.dart';
import 'package:career_buddy_lms/features/auth/presentation/providers/auth_providers.dart';
import 'package:career_buddy_lms/features/group_discussion/domain/entities/gd_report.dart';
import 'package:career_buddy_lms/features/group_discussion/domain/entities/gd_session_summary.dart';
import 'package:career_buddy_lms/features/group_discussion/presentation/providers/gd_providers.dart';
import 'package:career_buddy_lms/features/group_discussion/presentation/screens/gd_history_screen.dart';
import 'package:career_buddy_lms/features/group_discussion/presentation/screens/gd_report_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../gd_test_doubles.dart';

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

const _report = GdReport(
  overallScore: 78,
  fluency: GdReportDimension(score: 20, feedback: 'Good pace.'),
  grammar: GdReportDimension(score: 18, feedback: 'Minor errors.'),
  relevance: GdReportDimension(score: 20, feedback: 'On topic.'),
  confidence: GdReportDimension(score: 20, feedback: 'Confident tone.'),
  strengths: ['Clear articulation'],
  improvements: ['Use more varied vocabulary'],
  summary: 'A solid discussion overall.',
);

Future<FakeGdRepository> _pump(WidgetTester tester, FakeGdRepository repo) async {
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        authRepositoryProvider.overrideWithValue(_FakeAuthRepository()),
        gdRepositoryProvider.overrideWithValue(repo),
      ],
      child: const MaterialApp(home: GdHistoryScreen()),
    ),
  );
  await tester.pump();
  return repo;
}

void main() {
  group('GdHistoryScreen', () {
    testWidgets('shows the empty state when the user has no past discussions', (tester) async {
      await _pump(tester, FakeGdRepository());

      expect(find.textContaining("haven't had a Group Discussion yet"), findsOneWidget);
    });

    testWidgets('renders every real session, preserving the API\'s own (newest-first) ordering', (tester) async {
      await _pump(
        tester,
        FakeGdRepository(
          sessionsResult: const Success([
            GdSessionSummary(id: 2, topic: 'AI will replace human jobs', createdAt: '2026-09-20T10:00:00', isActive: false),
            GdSessionSummary(id: 1, topic: 'Work from home vs office', createdAt: '2026-09-10T10:00:00', isActive: true),
          ]),
        ),
      );

      final titles = tester.widgetList<Text>(find.byType(Text)).map((t) => t.data).toList();
      expect(titles.indexOf('AI will replace human jobs') < titles.indexOf('Work from home vs office'), isTrue);
      expect(find.text('In progress'), findsOneWidget); // only the active session gets the pill
    });

    testWidgets('shows a retryable error view on failure', (tester) async {
      await _pump(tester, FakeGdRepository(sessionsResult: const Failed(ServerFailure())));

      expect(find.text(const ServerFailure().message), findsOneWidget);
      expect(find.text('Retry'), findsOneWidget);
    });

    testWidgets('tapping a session with a real report navigates to GdReportScreen', (tester) async {
      await _pump(
        tester,
        FakeGdRepository(
          sessionsResult: const Success([
            GdSessionSummary(id: 1, topic: 'AI will replace human jobs', createdAt: '2026-09-20T10:00:00', isActive: false),
          ]),
          reportResult: const Success(_report),
        ),
      );

      await tester.tap(find.text('AI will replace human jobs'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));

      expect(find.byType(GdReportScreen), findsOneWidget);
      expect(find.text('78'), findsOneWidget);
    });

    testWidgets('tapping a session with no report yet shows an honest message, never a fabricated report', (tester) async {
      await _pump(
        tester,
        FakeGdRepository(
          sessionsResult: const Success([
            GdSessionSummary(id: 1, topic: 'Work from home vs office', createdAt: '2026-09-10T10:00:00', isActive: true),
          ]),
          reportResult: const Success(null),
        ),
      );

      await tester.tap(find.text('Work from home vs office'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));

      expect(find.byType(GdReportScreen), findsNothing);
      expect(find.textContaining("hasn't been analyzed yet"), findsOneWidget);
    });
  });
}
