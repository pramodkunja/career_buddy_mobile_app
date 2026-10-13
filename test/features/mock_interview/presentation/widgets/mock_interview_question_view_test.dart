import 'package:career_buddy_lms/core/utils/result.dart';
import 'package:career_buddy_lms/features/mock_interview/domain/entities/answer_submission_result.dart';
import 'package:career_buddy_lms/features/mock_interview/domain/entities/interview_analytics.dart';
import 'package:career_buddy_lms/features/mock_interview/domain/entities/interview_question.dart';
import 'package:career_buddy_lms/features/mock_interview/domain/entities/malpractice.dart';
import 'package:career_buddy_lms/features/mock_interview/domain/entities/next_question_outcome.dart';
import 'package:career_buddy_lms/features/mock_interview/domain/repositories/mock_interview_repository.dart';
import 'package:career_buddy_lms/features/mock_interview/presentation/controllers/mock_interview_controller.dart';
import 'package:career_buddy_lms/features/mock_interview/presentation/providers/mock_interview_providers.dart';
import 'package:career_buddy_lms/features/mock_interview/presentation/widgets/mock_interview_question_view.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

/// REGRESSION (Phase 17) — the blocking violation-warning dialog's
/// denominator used to be a hardcoded `/3` (`mock_interview_question_view.dart`'s
/// old `'Warning ${warning.count}/3'`), stale against the updated backend's
/// now-configurable `MALPRACTICE_TERMINATE_THRESHOLD`. It must always read
/// [MockInterviewQuestionActive.terminateThreshold] instead — never a baked-in
/// number — and degrade to showing just the count (no denominator) when that
/// threshold hasn't loaded.
///
/// Only `acknowledgeWarning()` is ever exercised here (pure state mutation,
/// no repository call), so this fake's every other method is an
/// [UnimplementedError] — exactly the convention already used by
/// `test/app/router/ai_*_route_test.dart`'s fakes for methods a given test
/// never reaches.
class _UnreachableMockInterviewRepository implements MockInterviewRepository {
  @override
  Future<Result<void>> startInterview() async => throw UnimplementedError();

  @override
  Future<Result<void>> confirmCameraLive() async => throw UnimplementedError();

  @override
  Future<Result<NextQuestionOutcome>> getNextQuestion({required bool advance}) async => throw UnimplementedError();

  @override
  Future<Result<AnswerSubmissionResult>> submitAnswer({required int questionId, required String answerText}) async =>
      throw UnimplementedError();

  @override
  Future<Result<ViolationState>> getViolationState() async => throw UnimplementedError();

  @override
  Future<Result<ViolationRecordResult>> recordViolation({required ViolationType type, double? durationSeconds}) async =>
      throw UnimplementedError();

  @override
  Future<Result<bool>> uploadInterviewVideo(String filePath) async => throw UnimplementedError();

  @override
  Future<Result<InterviewAnalyticsResult>> getAnalytics() async => throw UnimplementedError();
}

const _question = InterviewQuestion(
  id: 1,
  text: 'Tell me about yourself.',
  topic: 'Behavioural',
  difficulty: 'Easy',
  isCoding: false,
  questionType: 'theory',
  progress: '1/20',
  timeLimitSeconds: 30,
  timeRemainingSeconds: 25,
);

Future<void> _pump(WidgetTester tester, MockInterviewQuestionActive state) async {
  await tester.pumpWidget(
    ProviderScope(
      overrides: [mockInterviewRepositoryProvider.overrideWithValue(_UnreachableMockInterviewRepository())],
      child: MaterialApp(home: Scaffold(body: MockInterviewQuestionView(state: state))),
    ),
  );
  await tester.pump(); // let the post-frame callback schedule showDialog
  await tester.pump(); // let the dialog route's entrance animation complete
}

void main() {
  testWidgets('a terminate_threshold of 3 shows "Warning 1/3" — matches the backend response it came from', (tester) async {
    await _pump(
      tester,
      MockInterviewQuestionActive(
        question: _question,
        secondsRemaining: 25,
        answerText: '',
        violationCount: 1,
        terminateThreshold: 3,
        activeWarning: const ViolationRecordResult(
          count: 1,
          status: MalpracticeStatus.clean,
          action: ViolationAction.warn,
          typeOccurrenceNumber: 1,
        ),
      ),
    );

    expect(find.textContaining('Warning 1/3'), findsOneWidget);
    expect(find.textContaining('Warning 1/2'), findsNothing);
  });

  testWidgets(
    'a terminate_threshold of 2 shows "Warning 1/2", never the old hardcoded "/3" — proves the denominator is dynamic',
    (tester) async {
      await _pump(
        tester,
        MockInterviewQuestionActive(
          question: _question,
          secondsRemaining: 25,
          answerText: '',
          violationCount: 1,
          terminateThreshold: 2,
          activeWarning: const ViolationRecordResult(
            count: 1,
            status: MalpracticeStatus.clean,
            action: ViolationAction.warn,
            typeOccurrenceNumber: 1,
          ),
        ),
      );

      expect(find.textContaining('Warning 1/2'), findsOneWidget);
      expect(find.textContaining('Warning 1/3'), findsNothing);
    },
  );

  testWidgets('an unknown (not-yet-loaded) terminate_threshold shows the count alone, never a guessed denominator', (
    tester,
  ) async {
    await _pump(
      tester,
      MockInterviewQuestionActive(
        question: _question,
        secondsRemaining: 25,
        answerText: '',
        violationCount: 1,
        // terminateThreshold intentionally omitted (null) — simulates the
        // fetch not having completed/failed.
        activeWarning: const ViolationRecordResult(
          count: 1,
          status: MalpracticeStatus.clean,
          action: ViolationAction.warn,
          typeOccurrenceNumber: 1,
        ),
      ),
    );

    expect(find.textContaining('Warning 1'), findsOneWidget);
    expect(find.textContaining('Warning 1/'), findsNothing);
  });

  testWidgets('a "flagged" action still shows the flagged title, unaffected by the denominator fix', (tester) async {
    await _pump(
      tester,
      MockInterviewQuestionActive(
        question: _question,
        secondsRemaining: 25,
        answerText: '',
        violationCount: 2,
        terminateThreshold: 3,
        activeWarning: const ViolationRecordResult(
          count: 2,
          status: MalpracticeStatus.flagged,
          action: ViolationAction.flagged,
          typeOccurrenceNumber: 2,
        ),
      ),
    );

    expect(find.text('Suspicious Activity Detected — Flagged for Review'), findsOneWidget);
    expect(find.textContaining('Warning 2/3'), findsOneWidget);
  });
}
