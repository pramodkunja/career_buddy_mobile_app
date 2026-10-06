import 'package:career_buddy_lms/core/errors/failures.dart';
import 'package:career_buddy_lms/core/utils/result.dart';
import 'package:career_buddy_lms/features/auth/domain/entities/auth_user.dart';
import 'package:career_buddy_lms/features/auth/domain/entities/student_registration_data.dart';
import 'package:career_buddy_lms/features/auth/domain/repositories/auth_repository.dart';
import 'package:career_buddy_lms/features/auth/presentation/providers/auth_providers.dart';
import 'package:career_buddy_lms/features/mock_tests/data/datasources/mock_test_attempt_history_local_datasource.dart';
import 'package:career_buddy_lms/features/mock_tests/domain/entities/mock_test_attempt_record.dart';
import 'package:career_buddy_lms/features/mock_tests/domain/entities/mock_test_question.dart';
import 'package:career_buddy_lms/features/mock_tests/domain/entities/mock_test_submission_result.dart';
import 'package:career_buddy_lms/features/mock_tests/domain/repositories/mock_quiz_repository.dart';
import 'package:career_buddy_lms/features/mock_tests/presentation/providers/mock_test_providers.dart';
import 'package:career_buddy_lms/features/mock_tests/presentation/screens/subject_quiz_mock_test_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

List<MockTestQuestion> _questions({int count = 4}) => List.generate(
  count,
  (i) => MockTestQuestion(
    id: 100 + i,
    questionText: 'Question $i',
    options: const ['A', 'B', 'C', 'D'],
    difficulty: '',
    topic: '',
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
  Future<Result<AuthUser>> login({
    required String usernameOrEmail,
    required String password,
  }) async => throw UnimplementedError();

  @override
  Future<Result<void>> logout() async => const Success(null);

  @override
  Future<Result<String>> sendOtp(String email) async =>
      throw UnimplementedError();

  @override
  Future<Result<String>> verifyOtp({
    required String email,
    required String code,
  }) async => throw UnimplementedError();

  @override
  Future<Result<AuthUser>> register(StudentRegistrationData data) async =>
      throw UnimplementedError();
}

class _FakeMockQuizRepository implements MockQuizRepository {
  _FakeMockQuizRepository({this.getResult, this.submitResult});

  Result<List<MockTestQuestion>>? getResult;
  Result<MockTestSubmissionResult>? submitResult;

  @override
  Future<Result<List<MockTestQuestion>>> getQuestions() async => getResult!;

  @override
  Future<Result<MockTestSubmissionResult>> submitAnswers(
    Map<int, int> answers,
  ) async => submitResult!;
}

class _FakeAttemptHistoryDataSource
    implements MockTestAttemptHistoryLocalDataSource {
  @override
  Future<List<MockTestAttemptRecord>> getAttempts() async => [];
  @override
  Future<void> recordAttempt(MockTestAttemptRecord attempt) async {}
  @override
  String get storageKey => 'test';
}

Future<void> _unmount(WidgetTester tester) async {
  await tester.pumpWidget(const SizedBox());
  await tester.pump();
}

void main() {
  testWidgets('shows the DSA-specific title on the AppBar and intro splash', (
    tester,
  ) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          subjectQuizRepositoryProvider(
            'dsa',
          ).overrideWithValue(_FakeMockQuizRepository()),
          subjectQuizAttemptHistoryProvider(
            'dsa',
          ).overrideWithValue(_FakeAttemptHistoryDataSource()),
          authRepositoryProvider.overrideWithValue(_FakeAuthRepository()),
        ],
        child: const MaterialApp(
          home: SubjectQuizMockTestScreen(subject: 'dsa', title: 'DSA Mastery'),
        ),
      ),
    );
    await tester.pump();

    expect(
      find.text('DSA Mastery — Mock Test'),
      findsWidgets,
    ); // AppBar + splash heading both compose this
    expect(find.text('🎯 DSA Mastery — Mock Test'), findsOneWidget);
    expect(find.text('Start Test'), findsOneWidget);
  });

  testWidgets(
    'the result header uses the subject title, and the confirm dialog wording matches W020 exactly',
    (tester) async {
      final result = MockTestSubmissionResult(
        score: 1,
        total: 4,
        results: const {},
      );
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            subjectQuizRepositoryProvider('python').overrideWithValue(
              _FakeMockQuizRepository(
                getResult: Success(_questions()),
                submitResult: Success(result),
              ),
            ),
            subjectQuizAttemptHistoryProvider(
              'python',
            ).overrideWithValue(_FakeAttemptHistoryDataSource()),
            authRepositoryProvider.overrideWithValue(_FakeAuthRepository()),
          ],
          child: const MaterialApp(
            home: SubjectQuizMockTestScreen(
              subject: 'python',
              title: 'Python Mastery',
            ),
          ),
        ),
      );
      await tester.pump();

      await tester.tap(find.text('Start Test'));
      await tester.pump();
      await tester.pump();

      // Manual submit with 0 answered — confirm dialog must still appear
      // (Subject Quiz's own web copy always shows it, same as OOP's).
      await tester.tap(find.textContaining('Submit Test'));
      await tester.pump();
      expect(find.text('Submit test?'), findsOneWidget);
      expect(find.textContaining('4 unanswered question(s)'), findsOneWidget);

      await tester.tap(find.widgetWithText(FilledButton, 'Submit test'));
      for (var i = 0; i < 5; i++) {
        await tester.pump();
      }

      expect(find.text('Result — Python Mastery Mock Test'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('a load failure shows a retryable error view', (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          subjectQuizRepositoryProvider('robotics').overrideWithValue(
            _FakeMockQuizRepository(getResult: const Failed(ServerFailure())),
          ),
          subjectQuizAttemptHistoryProvider(
            'robotics',
          ).overrideWithValue(_FakeAttemptHistoryDataSource()),
          authRepositoryProvider.overrideWithValue(_FakeAuthRepository()),
        ],
        child: const MaterialApp(
          home: SubjectQuizMockTestScreen(
            subject: 'robotics',
            title: 'Robotics',
          ),
        ),
      ),
    );
    await tester.pump();
    await tester.tap(find.text('Start Test'));
    await tester.pump();
    await tester.pump();

    expect(find.text('Retry'), findsOneWidget);
    expect(tester.takeException(), isNull);

    await _unmount(tester);
  });
}
