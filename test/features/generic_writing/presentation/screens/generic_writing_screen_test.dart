import 'package:career_buddy_lms/core/errors/failures.dart';
import 'package:career_buddy_lms/core/utils/result.dart';
import 'package:career_buddy_lms/features/auth/domain/entities/auth_user.dart';
import 'package:career_buddy_lms/features/auth/domain/repositories/auth_repository.dart';
import 'package:career_buddy_lms/features/auth/domain/entities/student_registration_data.dart';
import 'package:career_buddy_lms/features/auth/presentation/providers/auth_providers.dart';
import 'package:career_buddy_lms/features/generic_writing/domain/entities/generic_writing_exercise.dart';
import 'package:career_buddy_lms/features/generic_writing/domain/entities/generic_writing_submission_result.dart';
import 'package:career_buddy_lms/features/generic_writing/domain/entities/writing_prompt.dart';
import 'package:career_buddy_lms/features/generic_writing/domain/repositories/generic_writing_repository.dart';
import 'package:career_buddy_lms/features/generic_writing/presentation/generic_writing_route_args.dart';
import 'package:career_buddy_lms/features/generic_writing/presentation/providers/generic_writing_providers.dart';
import 'package:career_buddy_lms/features/generic_writing/presentation/screens/generic_writing_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

String _words(int start, int count) => List.generate(count, (i) => 'word${start + i}').join(' ');

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

class _FakeGenericWritingRepository implements GenericWritingRepository {
  _FakeGenericWritingRepository({this.getResult, this.submitResult});

  Result<GenericWritingExercise>? getResult;
  Result<GenericWritingSubmissionResult>? submitResult;

  @override
  Future<Result<GenericWritingExercise>> getGenericWritingExercise(int exerciseId, {required String title, required int order}) async =>
      getResult!;

  @override
  Future<Result<GenericWritingSubmissionResult>> submitGenericWritingExercise(
    int exerciseId, {
    required int score,
    required int maxScore,
    required Map<int, String> answers,
  }) async => submitResult!;
}

GenericWritingExercise _exercise({int promptCount = 2}) => GenericWritingExercise(
  id: 7,
  title: 'Negotiation Outcome Reflection',
  order: 1,
  prompts: List.generate(
    promptCount,
    (i) => WritingPrompt(position: i + 1, questionText: 'Prompt text $i', guide: 'Aim for 10-500 words.'),
  ),
);

Future<void> _pump(WidgetTester tester, GenericWritingRepository repo, {GenericWritingRouteArgs? args, Size? size}) async {
  // The default 800×600 test surface is no longer tall enough for
  // `ExerciseHero` + the prompt cards to all sit within the hit-testable
  // viewport at once — callers testing a specific size (e.g. the
  // responsive-overflow test) pass their own [size] instead.
  tester.view.physicalSize = size ?? const Size(800, 1400);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);

  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        authRepositoryProvider.overrideWithValue(_FakeAuthRepository()),
        genericWritingRepositoryProvider.overrideWithValue(repo),
      ],
      child: MaterialApp(
        home: GenericWritingScreen(
          exerciseId: 7,
          args: args ?? const GenericWritingRouteArgs(title: 'Negotiation Outcome Reflection', order: 1, activityId: 12, subActivityId: 34),
        ),
      ),
    ),
  );
  for (var i = 0; i < 5; i++) {
    await tester.pump();
  }
}

void main() {
  testWidgets('shows every prompt simultaneously with an empty textarea and a disabled Submit button', (tester) async {
    await _pump(tester, _FakeGenericWritingRepository(getResult: Success(_exercise())));

    expect(find.text('Prompt text 0'), findsOneWidget);
    expect(find.text('Prompt text 1'), findsOneWidget);
    expect(find.byType(TextField), findsNWidgets(2));
    final submitButton = tester.widget<ElevatedButton>(find.widgetWithText(ElevatedButton, 'Submit Writing'));
    expect(submitButton.onPressed, isNull);
    expect(tester.takeException(), isNull);
  });

  testWidgets('typing updates the live word count and enables Submit once every prompt is within range', (tester) async {
    await _pump(tester, _FakeGenericWritingRepository(getResult: Success(_exercise())));

    await tester.enterText(find.byType(TextField).at(0), _words(1, 10));
    await tester.pump();
    expect(find.text('10 words'), findsOneWidget);
    var submitButton = tester.widget<ElevatedButton>(find.widgetWithText(ElevatedButton, 'Submit Writing'));
    expect(submitButton.onPressed, isNull); // prompt 2 still empty

    await tester.enterText(find.byType(TextField).at(1), _words(1, 10));
    await tester.pump();
    submitButton = tester.widget<ElevatedButton>(find.widgetWithText(ElevatedButton, 'Submit Writing'));
    expect(submitButton.onPressed, isNotNull);
  });

  testWidgets('submitting shows the result view with the server-computed score', (tester) async {
    const result = GenericWritingSubmissionResult(exerciseId: 7, score: 85, maxScore: 100, percentage: 85, attemptNumber: 1);
    await _pump(
      tester,
      _FakeGenericWritingRepository(getResult: Success(_exercise()), submitResult: const Success(result)),
    );

    await tester.enterText(find.byType(TextField).at(0), _words(1, 10));
    await tester.pump();
    await tester.enterText(find.byType(TextField).at(1), _words(1, 10));
    await tester.pump();
    await tester.tap(find.widgetWithText(ElevatedButton, 'Submit Writing'));
    for (var i = 0; i < 5; i++) {
      await tester.pump();
    }

    expect(find.text('85 / 100'), findsOneWidget);
    expect(find.text('85%'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('AI Feedback section appears only when the server returns customSummaryHtml-derived task feedback', (tester) async {
    const resultNoFeedback = GenericWritingSubmissionResult(exerciseId: 7, score: 60, maxScore: 100, percentage: 60, attemptNumber: 1);
    await _pump(
      tester,
      _FakeGenericWritingRepository(getResult: Success(_exercise()), submitResult: const Success(resultNoFeedback)),
    );

    await tester.enterText(find.byType(TextField).at(0), _words(1, 10));
    await tester.pump();
    await tester.enterText(find.byType(TextField).at(1), _words(1, 10));
    await tester.pump();
    await tester.tap(find.widgetWithText(ElevatedButton, 'Submit Writing'));
    for (var i = 0; i < 5; i++) {
      await tester.pump();
    }

    expect(find.text('AI Feedback'), findsNothing);
  });

  testWidgets('shows a retryable error view for a load failure', (tester) async {
    await _pump(tester, _FakeGenericWritingRepository(getResult: const Failed(NotFoundFailure())));

    expect(find.text(const NotFoundFailure().message), findsOneWidget);
    expect(find.text('Retry'), findsOneWidget);
  });

  testWidgets('renders without overflow at 320/375/430px and tablet width, with long content', (tester) async {
    for (final size in [const Size(320, 900), const Size(375, 900), const Size(430, 1000), const Size(1024, 1366)]) {
      await _pump(
        tester,
        _FakeGenericWritingRepository(
          getResult: Success(
            GenericWritingExercise(
              id: 7,
              title: 'A Genuinely Long Generic Writing Exercise Title',
              order: 1,
              prompts: [
                WritingPrompt(
                  position: 1,
                  questionText:
                      'A genuinely long writing prompt sentence that could wrap onto several lines on a narrow screen '
                      'and should not cause any overflow anywhere in the layout.',
                  guide: 'A fairly long guide/hint that also needs to wrap without overflowing anywhere on any screen width.',
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
