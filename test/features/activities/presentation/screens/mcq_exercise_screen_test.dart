import 'package:career_buddy_lms/core/errors/failures.dart';
import 'package:career_buddy_lms/core/utils/result.dart';
import 'package:career_buddy_lms/features/activities/domain/entities/mcq_exercise.dart';
import 'package:career_buddy_lms/features/activities/domain/entities/mcq_question.dart';
import 'package:career_buddy_lms/features/activities/domain/repositories/mcq_exercise_repository.dart';
import 'package:career_buddy_lms/features/activities/presentation/providers/activities_providers.dart';
import 'package:career_buddy_lms/features/activities/presentation/screens/mcq_exercise_screen.dart';
import 'package:career_buddy_lms/features/auth/domain/entities/auth_user.dart';
import 'package:career_buddy_lms/features/auth/domain/repositories/auth_repository.dart';
import 'package:career_buddy_lms/features/auth/domain/entities/student_registration_data.dart';
import 'package:career_buddy_lms/features/auth/presentation/providers/auth_providers.dart';
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

class _FakeMcqExerciseRepository implements McqExerciseRepository {
  _FakeMcqExerciseRepository({this.getResult});

  Result<McqExercise>? getResult;

  @override
  Future<Result<McqExercise>> getMcqExercise(int exerciseId) async => getResult!;

  @override
  Future<Result<McqSubmitEcho>> submitMcqExercise(
    int exerciseId, {
    required int score,
    required int maxScore,
    required Map<int, String> answers,
  }) async {
    // Mirrors the real `submit_exercise` endpoint for MCQ: it doesn't
    // grade, it just echoes back whatever the client sent.
    final percentage = maxScore > 0 ? (score / maxScore * 100).round() : 0;
    return Success((score: score, maxScore: maxScore, percentage: percentage, attemptNumber: 1));
  }
}

McqExercise _exercise({
  String title = 'Vocabulary Quiz with a Genuinely Long Title That Could Wrap',
  int questionCount = 2,
}) => McqExercise(
  id: 56,
  title: title,
  questions: List.generate(
    questionCount,
    (i) => McqQuestion(
      id: 100 + i,
      questionText: 'This is a fairly long question text number $i, long enough that it could wrap onto multiple lines.',
      options: const {
        'a': 'A reasonably long first option',
        'b': 'A second, also fairly long option',
        'c': 'Option C',
        'd': 'Option D',
      },
      correctAnswer: 'a',
      explanation: 'Because A is correct.',
    ),
  ),
);

Future<void> _pump(WidgetTester tester, McqExerciseRepository repo, {Size? size}) async {
  // The default 800×600 test surface is no longer tall enough for
  // `ExerciseHero` + the question card to all sit within the
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
        mcqExerciseRepositoryProvider.overrideWithValue(repo),
      ],
      child: const MaterialApp(home: McqExerciseScreen(exerciseId: 56)),
    ),
  );
  for (var i = 0; i < 5; i++) {
    await tester.pump();
  }
}

void main() {
  testWidgets('shows the first question once loaded, Next disabled until answered', (tester) async {
    await _pump(tester, _FakeMcqExerciseRepository(getResult: Success(_exercise())));

    expect(find.text('Question 1 of 2'), findsOneWidget);
    final nextButton = tester.widget<ElevatedButton>(find.widgetWithText(ElevatedButton, 'Next'));
    expect(nextButton.onPressed, isNull);
    expect(tester.takeException(), isNull);
  });

  testWidgets('selecting an answer enables Next; Submit stays disabled until all answered', (tester) async {
    await _pump(tester, _FakeMcqExerciseRepository(getResult: Success(_exercise())));

    await tester.tap(find.text('A reasonably long first option'));
    await tester.pump();
    final nextButton = tester.widget<ElevatedButton>(find.widgetWithText(ElevatedButton, 'Next'));
    expect(nextButton.onPressed, isNotNull);

    await tester.tap(find.text('Next'));
    await tester.pump();
    expect(find.text('Question 2 of 2'), findsOneWidget);
    // On the last question with only 1/2 answered, Submit must stay disabled.
    final submitButton = tester.widget<ElevatedButton>(find.widgetWithText(ElevatedButton, 'Submit'));
    expect(submitButton.onPressed, isNull);
  });

  testWidgets('submitting shows the client-graded score — both questions correctly answer "a"', (tester) async {
    await _pump(tester, _FakeMcqExerciseRepository(getResult: Success(_exercise())));

    await tester.tap(find.text('A reasonably long first option')); // 'a' — correct for Q1
    await tester.pump();
    await tester.tap(find.text('Next'));
    await tester.pump();
    await tester.tap(find.text('A reasonably long first option')); // 'a' — correct for Q2
    await tester.pump();
    await tester.tap(find.text('Submit'));
    for (var i = 0; i < 5; i++) {
      await tester.pump();
    }

    expect(find.text('2 / 2'), findsOneWidget);
    expect(find.text('100%'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('submitting with one wrong answer shows the correctly graded partial score', (tester) async {
    await _pump(tester, _FakeMcqExerciseRepository(getResult: Success(_exercise())));

    await tester.tap(find.text('A reasonably long first option')); // 'a' — correct for Q1
    await tester.pump();
    await tester.tap(find.text('Next'));
    await tester.pump();
    await tester.tap(find.text('A second, also fairly long option')); // 'b' — wrong for Q2 (correct is 'a')
    await tester.pump();
    await tester.tap(find.text('Submit'));
    for (var i = 0; i < 5; i++) {
      await tester.pump();
    }

    expect(find.text('1 / 2'), findsOneWidget);
    expect(find.text('50%'), findsOneWidget);
  });

  testWidgets('shows a retryable error view for a load failure', (tester) async {
    await _pump(tester, _FakeMcqExerciseRepository(getResult: const Failed(NotFoundFailure())));

    expect(find.text(const NotFoundFailure().message), findsOneWidget);
    expect(find.text('Retry'), findsOneWidget);
  });

  testWidgets('renders without overflow at narrow phone and tablet widths', (tester) async {
    for (final size in [const Size(320, 640), const Size(1024, 1366)]) {
      await _pump(tester, _FakeMcqExerciseRepository(getResult: Success(_exercise())), size: size);

      expect(tester.takeException(), isNull);
    }
  });
}
