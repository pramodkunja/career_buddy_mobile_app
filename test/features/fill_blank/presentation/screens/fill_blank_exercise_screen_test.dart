import 'package:career_buddy_lms/core/errors/failures.dart';
import 'package:career_buddy_lms/core/utils/result.dart';
import 'package:career_buddy_lms/features/auth/domain/entities/auth_user.dart';
import 'package:career_buddy_lms/features/auth/domain/repositories/auth_repository.dart';
import 'package:career_buddy_lms/features/auth/domain/entities/student_registration_data.dart';
import 'package:career_buddy_lms/features/auth/presentation/providers/auth_providers.dart';
import 'package:career_buddy_lms/features/fill_blank/domain/entities/fill_blank_exercise.dart';
import 'package:career_buddy_lms/features/fill_blank/domain/entities/fill_blank_question.dart';
import 'package:career_buddy_lms/features/fill_blank/domain/entities/fill_blank_submission_result.dart';
import 'package:career_buddy_lms/features/fill_blank/domain/repositories/fill_blank_exercise_repository.dart';
import 'package:career_buddy_lms/features/fill_blank/presentation/fill_blank_route_args.dart';
import 'package:career_buddy_lms/features/fill_blank/presentation/providers/fill_blank_exercise_providers.dart';
import 'package:career_buddy_lms/features/fill_blank/presentation/screens/fill_blank_exercise_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

class _FakeAuthRepository implements AuthRepository {
  @override
  Future<AuthUser?> restoreSession() async => const AuthUser(username: 'jane');
  @override
  Future<Result<AuthUser>> login({required String usernameOrEmail, required String password}) async {
    throw UnimplementedError();
  }

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

class _FakeFillBlankExerciseRepository implements FillBlankExerciseRepository {
  _FakeFillBlankExerciseRepository({this.getResult, this.submitResult});

  Result<FillBlankExercise>? getResult;
  Result<FillBlankSubmissionResult>? submitResult;

  @override
  Future<Result<FillBlankExercise>> getFillBlankExercise(int exerciseId, {required String title, required int order}) async =>
      getResult!;

  @override
  Future<Result<FillBlankSubmissionResult>> submitFillBlankExercise(
    int exerciseId, {
    required int score,
    required int maxScore,
    required Map<int, ({String given, String correct, bool isCorrect})> answers,
  }) async => submitResult!;
}

FillBlankExercise _exercise({int questionCount = 2}) => FillBlankExercise(
  id: 7,
  title: 'Vocabulary Fill in the Blank',
  order: 1,
  questions: List.generate(
    questionCount,
    (i) => FillBlankQuestion(position: i + 1, questionText: 'Question text $i', correctAnswer: 'answer$i'),
  ),
);

Future<void> _pump(WidgetTester tester, FillBlankExerciseRepository repo, {FillBlankRouteArgs? args, Size? size}) async {
  // The default 800×600 test surface is no longer tall enough for
  // `ExerciseHero` + the question cards to all sit within the
  // hit-testable viewport at once — callers testing a specific size (e.g.
  // the responsive-overflow test) pass their own [size] instead.
  tester.view.physicalSize = size ?? const Size(800, 1400);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);

  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        authRepositoryProvider.overrideWithValue(_FakeAuthRepository()),
        fillBlankExerciseRepositoryProvider.overrideWithValue(repo),
      ],
      child: MaterialApp(
        home: FillBlankExerciseScreen(
          exerciseId: 7,
          args: args ?? const FillBlankRouteArgs(title: 'Vocabulary Fill in the Blank', order: 1, activityId: 12, subActivityId: 34),
        ),
      ),
    ),
  );
  for (var i = 0; i < 5; i++) {
    await tester.pump();
  }
}

void main() {
  testWidgets('shows every question simultaneously with an empty, enabled input and Check button', (tester) async {
    await _pump(tester, _FakeFillBlankExerciseRepository(getResult: Success(_exercise())));

    expect(find.text('Question text 0'), findsOneWidget);
    expect(find.text('Question text 1'), findsOneWidget);
    expect(find.byType(TextField), findsNWidgets(2));
    expect(find.widgetWithText(OutlinedButton, 'Check'), findsNWidgets(2));
    final submitButton = tester.widget<ElevatedButton>(find.widgetWithText(ElevatedButton, 'Submit All Answers'));
    expect(submitButton.onPressed, isNull);
    expect(tester.takeException(), isNull);
  });

  testWidgets('an empty Check shows an inline error and keeps the input editable', (tester) async {
    await _pump(tester, _FakeFillBlankExerciseRepository(getResult: Success(_exercise())));

    await tester.tap(find.widgetWithText(OutlinedButton, 'Check').first);
    await tester.pump();

    expect(find.text('Please enter an answer first.'), findsOneWidget);
    final field = tester.widget<TextField>(find.byType(TextField).first);
    expect(field.enabled, isTrue);
  });

  testWidgets('a correct Check locks the input and shows "Correct!"', (tester) async {
    await _pump(tester, _FakeFillBlankExerciseRepository(getResult: Success(_exercise())));

    await tester.enterText(find.byType(TextField).first, 'answer0');
    await tester.tap(find.widgetWithText(OutlinedButton, 'Check').first);
    await tester.pump();

    expect(find.text('Correct!'), findsOneWidget);
    final field = tester.widget<TextField>(find.byType(TextField).first);
    expect(field.enabled, isFalse);
  });

  testWidgets('a wrong Check locks the input and reveals the correct answer', (tester) async {
    await _pump(tester, _FakeFillBlankExerciseRepository(getResult: Success(_exercise())));

    await tester.enterText(find.byType(TextField).first, 'nope');
    await tester.tap(find.widgetWithText(OutlinedButton, 'Check').first);
    await tester.pump();

    expect(find.textContaining('Incorrect. Correct answer: answer0'), findsOneWidget);
  });

  testWidgets('Submit All Answers enables only once every question is checked, even if all are wrong', (tester) async {
    const result = FillBlankSubmissionResult(exerciseId: 7, score: 0, maxScore: 2, percentage: 0, attemptNumber: 1);
    await _pump(
      tester,
      _FakeFillBlankExerciseRepository(getResult: Success(_exercise()), submitResult: const Success(result)),
    );

    await tester.enterText(find.byType(TextField).at(0), 'wrong');
    await tester.tap(find.widgetWithText(OutlinedButton, 'Check').at(0));
    await tester.pump();
    var submitButton = tester.widget<ElevatedButton>(find.widgetWithText(ElevatedButton, 'Submit All Answers'));
    expect(submitButton.onPressed, isNull); // only 1 of 2 checked

    await tester.enterText(find.byType(TextField).at(0), 'still wrong');
    await tester.tap(find.widgetWithText(OutlinedButton, 'Check').at(0));
    await tester.pump();
    // Already checked/locked — re-tapping Check on a locked question is a
    // no-op via a disabled button; the field stays wrong-but-checked.
    await tester.enterText(find.byType(TextField).at(0), 'irrelevant');

    final secondField = find.byType(TextField).at(0);
    expect(tester.widget<TextField>(secondField).enabled, isFalse);

    await tester.enterText(find.byType(TextField).at(1), 'also wrong');
    await tester.tap(find.widgetWithText(OutlinedButton, 'Check').at(1));
    await tester.pump();

    submitButton = tester.widget<ElevatedButton>(find.widgetWithText(ElevatedButton, 'Submit All Answers'));
    expect(submitButton.onPressed, isNotNull); // both checked now, though both wrong
  });

  testWidgets('submitting shows the generic result view with the server-computed score', (tester) async {
    const result = FillBlankSubmissionResult(exerciseId: 7, score: 2, maxScore: 2, percentage: 100, attemptNumber: 1);
    await _pump(
      tester,
      _FakeFillBlankExerciseRepository(getResult: Success(_exercise()), submitResult: const Success(result)),
    );

    await tester.enterText(find.byType(TextField).at(0), 'answer0');
    await tester.tap(find.widgetWithText(OutlinedButton, 'Check').at(0));
    await tester.pump();
    await tester.enterText(find.byType(TextField).at(1), 'answer1');
    await tester.tap(find.widgetWithText(OutlinedButton, 'Check').at(1));
    await tester.pump();
    await tester.tap(find.widgetWithText(ElevatedButton, 'Submit All Answers'));
    for (var i = 0; i < 5; i++) {
      await tester.pump();
    }

    expect(find.text('2 / 2'), findsOneWidget);
    expect(find.text('100%'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('shows a retryable error view for a load failure', (tester) async {
    await _pump(tester, _FakeFillBlankExerciseRepository(getResult: const Failed(NotFoundFailure())));

    expect(find.text(const NotFoundFailure().message), findsOneWidget);
    expect(find.text('Retry'), findsOneWidget);
  });

  testWidgets('renders without overflow at 320/375/430px and tablet width, with long content', (tester) async {
    for (final size in [const Size(320, 900), const Size(375, 900), const Size(430, 1000), const Size(1024, 1366)]) {
      await _pump(
        tester,
        _FakeFillBlankExerciseRepository(
          getResult: Success(
            FillBlankExercise(
              id: 7,
              title: 'A Genuinely Long Fill in the Blank Exercise Title',
              order: 1,
              questions: [
                FillBlankQuestion(
                  position: 1,
                  questionText:
                      'A genuinely long question sentence with a blank in the middle of it that could wrap onto several lines on a narrow screen.',
                  correctAnswer: 'a-fairly-long-correct-answer-value',
                  explanation: 'A fairly long explanation hint that also needs to wrap without overflowing anywhere.',
                ),
              ],
            ),
          ),
        ),
        size: size,
      );

      expect(tester.takeException(), isNull);
    }
  });
}
