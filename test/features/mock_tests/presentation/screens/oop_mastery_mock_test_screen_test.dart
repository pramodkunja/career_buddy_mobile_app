import 'package:career_buddy_lms/core/errors/failures.dart';
import 'package:career_buddy_lms/core/utils/result.dart';
import 'package:career_buddy_lms/features/auth/domain/entities/auth_user.dart';
import 'package:career_buddy_lms/features/auth/domain/entities/student_registration_data.dart';
import 'package:career_buddy_lms/features/auth/domain/repositories/auth_repository.dart';
import 'package:career_buddy_lms/features/auth/presentation/providers/auth_providers.dart';
import 'package:career_buddy_lms/features/mock_tests/data/datasources/mock_test_attempt_history_local_datasource.dart';
import 'package:career_buddy_lms/features/mock_tests/domain/entities/mock_test_attempt_record.dart';
import 'package:career_buddy_lms/features/mock_tests/domain/entities/mock_test_question.dart';
import 'package:career_buddy_lms/features/mock_tests/domain/entities/mock_test_question_result.dart';
import 'package:career_buddy_lms/features/mock_tests/domain/entities/mock_test_submission_result.dart';
import 'package:career_buddy_lms/features/mock_tests/domain/repositories/mock_quiz_repository.dart';
import 'package:career_buddy_lms/features/mock_tests/presentation/providers/mock_test_providers.dart';
import 'package:career_buddy_lms/features/mock_tests/presentation/screens/oop_mastery_mock_test_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

List<MockTestQuestion> _questions({int count = 4}) => List.generate(
  count,
  (i) => MockTestQuestion(
    id: 100 + i,
    questionText:
        'This is question number $i, written long enough that it could plausibly wrap onto more than one line on a narrow phone.',
    options: const [
      'A reasonably long first option that could wrap',
      'A second, also fairly long option here',
      'Option C',
      'Option D',
    ],
    difficulty: 'medium',
    topic: 'oop',
  ),
);

/// `BuddyChatbotOverlay` (now part of every screen's `Scaffold`, per the
/// web's unconditional `{% include 'includes/aria_assistant.html' %}`)
/// reads `authControllerProvider` for its greeting, which otherwise falls
/// through to `authRepositoryProvider` -> `authRemoteDataSourceProvider` ->
/// `apiClientProvider` (unimplemented outside `main()`). Overriding
/// `authRepositoryProvider` directly avoids that without this file's own
/// tests needing to care about auth at all.
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

class _FakeMockQuizRepository implements MockQuizRepository {
  _FakeMockQuizRepository({this.getResult, this.submitResult});

  Result<List<MockTestQuestion>>? getResult;
  Result<MockTestSubmissionResult>? submitResult;

  @override
  Future<Result<List<MockTestQuestion>>> getQuestions() async => getResult!;

  @override
  Future<Result<MockTestSubmissionResult>> submitAnswers(Map<int, int> answers) async => submitResult!;
}

class _FakeAttemptHistoryDataSource implements MockTestAttemptHistoryLocalDataSource {
  final List<MockTestAttemptRecord> recorded = [];

  @override
  Future<List<MockTestAttemptRecord>> getAttempts() async => List.of(recorded);

  @override
  Future<void> recordAttempt(MockTestAttemptRecord attempt) async => recorded.add(attempt);

  @override
  String get storageKey => 'test';
}

Future<void> _pump(WidgetTester tester, MockQuizRepository repo, {MockTestAttemptHistoryLocalDataSource? history}) async {
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        oopMockQuizRepositoryProvider.overrideWithValue(repo),
        oopMockTestAttemptHistoryProvider.overrideWithValue(history ?? _FakeAttemptHistoryDataSource()),
        authRepositoryProvider.overrideWithValue(_FakeAuthRepository()),
      ],
      child: const MaterialApp(home: OopMasteryMockTestScreen()),
    ),
  );
  await tester.pump();
}

/// Unmounts the widget tree so `ProviderScope` disposes its container,
/// which cancels the controller's `Timer.periodic` via `ref.onDispose` —
/// required before any test that reached `MockTestInProgress` ends, or
/// `flutter_test` fails on a pending timer.
Future<void> _unmount(WidgetTester tester) async {
  await tester.pumpWidget(const SizedBox());
  await tester.pump();
}

void main() {
  testWidgets('intro screen shows the rules and a Start Test action', (tester) async {
    await _pump(tester, _FakeMockQuizRepository());

    expect(find.textContaining('OOP Mastery'), findsWidgets);
    expect(find.text('50 questions to attempt'), findsOneWidget);
    expect(find.text('Start Test'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('Start Test fetches questions and shows the first one', (tester) async {
    await _pump(tester, _FakeMockQuizRepository(getResult: Success(_questions())));

    await tester.tap(find.text('Start Test'));
    await tester.pump();
    await tester.pump();

    expect(find.text('Question 1 of 4'), findsOneWidget);
    expect(find.textContaining('Submit Test'), findsOneWidget);
    expect(tester.takeException(), isNull);

    await _unmount(tester);
  });

  testWidgets('selecting an option highlights it and free navigation allows jumping via the palette', (tester) async {
    await _pump(tester, _FakeMockQuizRepository(getResult: Success(_questions())));
    await tester.tap(find.text('Start Test'));
    await tester.pump();
    await tester.pump();

    await tester.scrollUntilVisible(
      find.text('A reasonably long first option that could wrap'),
      200,
      scrollable: find.byType(Scrollable),
    );
    await tester.tap(find.text('A reasonably long first option that could wrap'));
    await tester.pump();
    expect(find.textContaining('Submit Test (1/4'), findsOneWidget);

    // Free navigation: jump straight to question 4 via the palette, skipping 2 and 3.
    // Never pumpAndSettle() once `BuddyChatbotOverlay` is in the tree — its
    // launcher's float animation repeats forever and would hang this.
    await tester.tap(find.byIcon(Icons.grid_view));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    await tester.tap(find.text('4'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    // The header scrolled out of the cache extent when we scrolled down to
    // reach the first option earlier; scroll it back into view rather than
    // assume it's still mounted (same below-the-fold reasoning throughout
    // this file).
    await tester.scrollUntilVisible(find.text('Question 4 of 4'), -200, scrollable: find.byType(Scrollable));
    expect(find.text('Question 4 of 4'), findsOneWidget);
    expect(tester.takeException(), isNull);

    await _unmount(tester);
  });

  testWidgets('Next/Previous move one question at a time and are disabled at the ends', (tester) async {
    await _pump(tester, _FakeMockQuizRepository(getResult: Success(_questions(count: 2))));
    await tester.tap(find.text('Start Test'));
    await tester.pump();
    await tester.pump();

    final previousButton = tester.widget<OutlinedButton>(find.widgetWithText(OutlinedButton, 'Previous'));
    expect(previousButton.onPressed, isNull);

    await tester.tap(find.text('Next'));
    await tester.pump();
    expect(find.text('Question 2 of 2'), findsOneWidget);
    final nextButton = tester.widget<OutlinedButton>(find.widgetWithText(OutlinedButton, 'Next'));
    expect(nextButton.onPressed, isNull);

    await _unmount(tester);
  });

  testWidgets('marking a question for review toggles the button label', (tester) async {
    await _pump(tester, _FakeMockQuizRepository(getResult: Success(_questions())));
    await tester.tap(find.text('Start Test'));
    await tester.pump();
    await tester.pump();

    // The Mark button sits below several long options — off the default
    // test-window viewport + cache extent, so it isn't mounted yet (same
    // reasoning as every other below-the-fold scroll in this app's test
    // suite: scroll it into view via the guaranteed-present `Scrollable`,
    // never a specific card that may not be built).
    await tester.scrollUntilVisible(find.text('☆ Mark for review'), 200, scrollable: find.byType(Scrollable));
    expect(find.text('☆ Mark for review'), findsOneWidget);
    await tester.tap(find.text('☆ Mark for review'));
    await tester.pump();
    expect(find.text('★ Marked'), findsOneWidget);

    await _unmount(tester);
  });

  testWidgets('manual submit shows a confirmation naming the unanswered count, and only submits once confirmed', (tester) async {
    final result = MockTestSubmissionResult(
      score: 1,
      total: 4,
      results: {100: const MockTestQuestionResult(isCorrect: true, correctAnswerIndex: 0, explanation: 'because')},
    );
    await _pump(tester, _FakeMockQuizRepository(getResult: Success(_questions()), submitResult: Success(result)));
    await tester.tap(find.text('Start Test'));
    await tester.pump();
    await tester.pump();

    await tester.tap(find.textContaining('Submit Test'));
    await tester.pump();
    expect(find.text('Submit test?'), findsOneWidget);
    expect(find.textContaining('4 unanswered question(s)'), findsOneWidget);

    // Cancel first: must NOT submit.
    await tester.tap(find.text('Cancel'));
    await tester.pump();
    expect(find.text('Result — OOP Mastery Mock Test'), findsNothing);

    await tester.tap(find.textContaining('Submit Test'));
    await tester.pump();
    await tester.tap(find.widgetWithText(FilledButton, 'Submit test'));
    for (var i = 0; i < 5; i++) {
      await tester.pump();
    }

    expect(find.text('Result — OOP Mastery Mock Test'), findsOneWidget);
    expect(find.text('1 / 4'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('the 4-tier result message matches the web thresholds — 90% shows the "Outstanding" tier', (tester) async {
    final result = MockTestSubmissionResult(score: 36, total: 40, results: const {});
    await _pump(tester, _FakeMockQuizRepository(getResult: Success(_questions(count: 1)), submitResult: Success(result)));
    await tester.tap(find.text('Start Test'));
    await tester.pump();
    await tester.pump();
    await tester.scrollUntilVisible(
      find.text('A reasonably long first option that could wrap'),
      200,
      scrollable: find.byType(Scrollable),
    );
    await tester.tap(find.text('A reasonably long first option that could wrap'));
    await tester.pump();
    await tester.tap(find.textContaining('Submit Test'));
    await tester.pump();
    await tester.tap(find.widgetWithText(FilledButton, 'Submit test'));
    for (var i = 0; i < 5; i++) {
      await tester.pump();
    }

    expect(find.textContaining('Outstanding'), findsOneWidget);
  });

  testWidgets('Take another test fetches a fresh attempt, skipping the intro screen', (tester) async {
    final result = MockTestSubmissionResult(score: 1, total: 1, results: const {});
    await _pump(tester, _FakeMockQuizRepository(getResult: Success(_questions(count: 1)), submitResult: Success(result)));
    await tester.tap(find.text('Start Test'));
    await tester.pump();
    await tester.pump();
    await tester.scrollUntilVisible(
      find.text('A reasonably long first option that could wrap'),
      200,
      scrollable: find.byType(Scrollable),
    );
    await tester.tap(find.text('A reasonably long first option that could wrap'));
    await tester.pump();
    await tester.tap(find.textContaining('Submit Test'));
    await tester.pump();
    await tester.tap(find.widgetWithText(FilledButton, 'Submit test'));
    for (var i = 0; i < 5; i++) {
      await tester.pump();
    }
    expect(find.text('Result — OOP Mastery Mock Test'), findsOneWidget);

    await tester.tap(find.text('Take another test'));
    await tester.pump();
    await tester.pump();

    expect(find.text('Question 1 of 1'), findsOneWidget); // straight into the exam, no splash shown again
    expect(find.text('Start Test'), findsNothing);

    await _unmount(tester);
  });

  testWidgets('Close from the result screen returns to the intro screen', (tester) async {
    final result = MockTestSubmissionResult(score: 1, total: 1, results: const {});
    await _pump(tester, _FakeMockQuizRepository(getResult: Success(_questions(count: 1)), submitResult: Success(result)));
    await tester.tap(find.text('Start Test'));
    await tester.pump();
    await tester.pump();
    await tester.scrollUntilVisible(
      find.text('A reasonably long first option that could wrap'),
      200,
      scrollable: find.byType(Scrollable),
    );
    await tester.tap(find.text('A reasonably long first option that could wrap'));
    await tester.pump();
    await tester.tap(find.textContaining('Submit Test'));
    await tester.pump();
    await tester.tap(find.widgetWithText(FilledButton, 'Submit test'));
    for (var i = 0; i < 5; i++) {
      await tester.pump();
    }

    await tester.tap(find.text('Close'));
    await tester.pump();

    expect(find.text('Start Test'), findsOneWidget);
  });

  testWidgets('a load failure shows a retryable error view, not a crash', (tester) async {
    await _pump(tester, _FakeMockQuizRepository(getResult: const Failed(ServerFailure())));

    await tester.tap(find.text('Start Test'));
    await tester.pump();
    await tester.pump();

    expect(find.text(const ServerFailure().message), findsOneWidget);
    expect(find.text('Retry'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('renders without overflow at narrow phone and tablet widths across intro/in-progress/result', (tester) async {
    for (final size in [const Size(320, 640), const Size(1024, 1366)]) {
      tester.view.physicalSize = size;
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final result = MockTestSubmissionResult(
        score: 2,
        total: 4,
        results: {100: const MockTestQuestionResult(isCorrect: true, correctAnswerIndex: 0, explanation: 'A long explanation that could wrap across multiple lines on a narrow screen without overflowing.')},
      );
      await _pump(tester, _FakeMockQuizRepository(getResult: Success(_questions()), submitResult: Success(result)));
      expect(tester.takeException(), isNull);

      await tester.scrollUntilVisible(find.text('Start Test'), 200, scrollable: find.byType(Scrollable));
      await tester.tap(find.text('Start Test'));
      await tester.pump();
      await tester.pump();
      expect(tester.takeException(), isNull);

      await tester.scrollUntilVisible(
        find.text('A reasonably long first option that could wrap'),
        200,
        scrollable: find.byType(Scrollable),
      );
      await tester.tap(find.text('A reasonably long first option that could wrap'));
      await tester.pump();
      await tester.tap(find.textContaining('Submit Test'));
      await tester.pump();
      await tester.tap(find.widgetWithText(FilledButton, 'Submit test'));
      for (var i = 0; i < 5; i++) {
        await tester.pump();
      }
      expect(tester.takeException(), isNull);

      await _unmount(tester);
    }
  });
}
