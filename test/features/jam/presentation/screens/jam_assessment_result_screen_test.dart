import 'package:career_buddy_lms/core/utils/result.dart';
import 'package:career_buddy_lms/features/auth/domain/entities/auth_user.dart';
import 'package:career_buddy_lms/features/auth/domain/entities/student_registration_data.dart';
import 'package:career_buddy_lms/features/auth/domain/repositories/auth_repository.dart';
import 'package:career_buddy_lms/features/auth/presentation/providers/auth_providers.dart';
import 'package:career_buddy_lms/features/jam/domain/entities/jam_assessment.dart';
import 'package:career_buddy_lms/features/jam/presentation/screens/jam_assessment_result_screen.dart';
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

Widget _wrap(Widget child) {
  return ProviderScope(
    overrides: [authRepositoryProvider.overrideWithValue(_FakeAuthRepository())],
    child: MaterialApp(home: child),
  );
}

const _result = JamAssessmentResult(
  level: 'Advanced',
  averageDurationSeconds: 52,
  averageFluency: 4.7,
  totalScore: 60,
  stages: [
    JamAssessmentStageSummary(difficulty: 'easy', topicTitle: 'My Family', overallScore: 22),
    JamAssessmentStageSummary(difficulty: 'medium', topicTitle: 'Climate Change', overallScore: 20),
    JamAssessmentStageSummary(difficulty: 'hard', topicTitle: 'AI & Ethics', overallScore: 18),
  ],
  reportText: 'You maintained strong, consistent pacing across all three difficulty levels.',
);

void main() {
  testWidgets('renders the real level/stats/per-stage summary/report content', (tester) async {
    await tester.pumpWidget(_wrap(const JamAssessmentResultScreen(result: _result)));
    await tester.pump();

    expect(find.text('Diagnostic Performance Report'), findsOneWidget);
    expect(find.textContaining('Result Level: Advanced'), findsOneWidget);
    expect(find.text('60/75'), findsOneWidget);
    expect(find.text('52s'), findsOneWidget);
    expect(find.text('4.7/5'), findsOneWidget);

    expect(find.text('My Family'), findsOneWidget);
    expect(find.text('Climate Change'), findsOneWidget);
    expect(find.text('AI & Ethics'), findsOneWidget);
    expect(find.text('★ 22/25'), findsOneWidget);
    expect(find.text('★ 20/25'), findsOneWidget);
    expect(find.text('★ 18/25'), findsOneWidget);

    // The report card sits below the fold.
    await tester.fling(find.byType(ListView), const Offset(0, -2000), 3000, warnIfMissed: false);
    await tester.pump();
    expect(find.text('You maintained strong, consistent pacing across all three difficulty levels.'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('an unscored ("—") stage renders without a numeric score', (tester) async {
    const unscored = JamAssessmentResult(
      level: 'Beginner',
      averageDurationSeconds: 20,
      averageFluency: 2.0,
      totalScore: 15,
      stages: [
        JamAssessmentStageSummary(difficulty: 'easy', topicTitle: 'My Family', overallScore: 10),
        JamAssessmentStageSummary(difficulty: 'medium', topicTitle: 'Climate Change', overallScore: 5),
        JamAssessmentStageSummary(difficulty: 'hard', topicTitle: 'AI Ethics', overallScore: null),
      ],
      reportText: '',
    );
    await tester.pumpWidget(_wrap(const JamAssessmentResultScreen(result: unscored)));
    await tester.pump();

    expect(find.text('—/25'), findsOneWidget);
  });

  testWidgets('"Back to Topics" pops the navigation stack', (tester) async {
    await tester.pumpWidget(
      _wrap(
        Builder(
          builder: (context) => ElevatedButton(
            onPressed: () => Navigator.of(
              context,
            ).push(MaterialPageRoute<void>(builder: (_) => const JamAssessmentResultScreen(result: _result))),
            child: const Text('open'),
          ),
        ),
      ),
    );
    await tester.tap(find.text('open'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    expect(find.byType(JamAssessmentResultScreen), findsOneWidget);

    await tester.fling(find.byType(ListView), const Offset(0, -2000), 3000, warnIfMissed: false);
    await tester.pump();
    await tester.tap(find.text('Back to Topics'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 1000));
    await tester.pump();
    await tester.pump();

    expect(find.byType(JamAssessmentResultScreen), findsNothing);
    expect(find.text('open'), findsOneWidget);
  });
}
