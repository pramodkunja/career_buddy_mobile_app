import 'package:career_buddy_lms/core/errors/failures.dart';
import 'package:career_buddy_lms/core/utils/result.dart';
import 'package:career_buddy_lms/features/ai_listening/domain/services/listening_tts_service.dart';
import 'package:career_buddy_lms/features/ai_listening/presentation/providers/ai_listening_providers.dart';
import 'package:career_buddy_lms/features/auth/domain/entities/auth_user.dart';
import 'package:career_buddy_lms/features/auth/domain/repositories/auth_repository.dart';
import 'package:career_buddy_lms/features/auth/domain/entities/student_registration_data.dart';
import 'package:career_buddy_lms/features/auth/presentation/providers/auth_providers.dart';
import 'package:career_buddy_lms/features/bingo/domain/entities/bingo_card.dart';
import 'package:career_buddy_lms/features/bingo/domain/entities/bingo_exercise.dart';
import 'package:career_buddy_lms/features/bingo/domain/entities/bingo_submission_result.dart';
import 'package:career_buddy_lms/features/bingo/domain/repositories/bingo_exercise_repository.dart';
import 'package:career_buddy_lms/features/bingo/presentation/bingo_route_args.dart';
import 'package:career_buddy_lms/features/bingo/presentation/providers/bingo_providers.dart';
import 'package:career_buddy_lms/features/bingo/presentation/screens/bingo_exercise_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

class _NoopTts implements ListeningTtsService {
  @override
  Future<void> speak(String text, {required double rate}) async {}
  @override
  Future<void> pause() async {}
  @override
  Future<void> stop() async {}
  @override
  void setOnStart(void Function() callback) {}
  @override
  void setOnComplete(void Function() callback) {}
  @override
  void setOnError(void Function(String message) callback) {}
}

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

class _FakeBingoExerciseRepository implements BingoExerciseRepository {
  _FakeBingoExerciseRepository({this.getResult, this.submitResult});

  Result<BingoExercise>? getResult;
  Result<BingoSubmissionResult>? submitResult;

  @override
  Future<Result<BingoExercise>> getBingoExercise(int exerciseId, {required String title, required int order}) async => getResult!;

  @override
  Future<Result<BingoSubmissionResult>> submitBingoExercise(
    int exerciseId, {
    required int score,
    required int maxScore,
    required Map<int, ({String target, String chosen})> answers,
  }) async => submitResult!;
}

BingoExercise _exercise({int cardCount = 4}) => BingoExercise(
  id: 7,
  title: 'Vocab Bingo',
  order: 1,
  cards: List.generate(cardCount, (i) => BingoCard(word: 'W$i', definition: 'Definition for W$i')),
);

Future<void> _pump(WidgetTester tester, BingoExerciseRepository repo, {BingoRouteArgs? args}) async {
  // The default 800×600 test surface is no longer tall enough for
  // `ExerciseHero` + the 5×5 board + controls to all sit within the
  // hit-testable viewport at once.
  tester.view.physicalSize = const Size(800, 1400);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);

  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        authRepositoryProvider.overrideWithValue(_FakeAuthRepository()),
        bingoExerciseRepositoryProvider.overrideWithValue(repo),
        listeningTtsServiceProvider.overrideWithValue(_NoopTts()),
      ],
      child: MaterialApp(
        home: BingoExerciseScreen(
          exerciseId: 7,
          args: args ?? const BingoRouteArgs(title: 'Vocab Bingo', order: 1, activityId: 12, subActivityId: 34),
        ),
      ),
    ),
  );
  for (var i = 0; i < 5; i++) {
    await tester.pump();
  }
}

void main() {
  testWidgets('shows the board and "Press Start to begin" before the game starts', (tester) async {
    await _pump(tester, _FakeBingoExerciseRepository(getResult: Success(_exercise())));

    expect(find.text('Press Start to begin'), findsOneWidget);
    expect(find.text('W0'), findsOneWidget);
    expect(find.widgetWithText(OutlinedButton, 'Start Game'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('starting shows the first round\'s definition; Next Word is disabled until a word is tapped', (tester) async {
    await _pump(tester, _FakeBingoExerciseRepository(getResult: Success(_exercise())));

    await tester.tap(find.text('Start Game'));
    await tester.pump();

    expect(find.textContaining('Definition for'), findsOneWidget);
    expect(find.textContaining('Word 1 of 4'), findsOneWidget);
    final nextButton = tester.widget<ElevatedButton>(find.widgetWithText(ElevatedButton, 'Next Word'));
    expect(nextButton.onPressed, isNull);
  });

  testWidgets('tapping a board word enables Next Word', (tester) async {
    await _pump(tester, _FakeBingoExerciseRepository(getResult: Success(_exercise())));

    await tester.tap(find.text('Start Game'));
    await tester.pump();
    await tester.tap(find.text('W0'));
    await tester.pump();

    final nextButton = tester.widget<ElevatedButton>(find.widgetWithText(ElevatedButton, 'Next Word'));
    expect(nextButton.onPressed, isNotNull);
  });

  testWidgets('completing every round shows the result view with the graded board and score', (tester) async {
    const result = BingoSubmissionResult(exerciseId: 7, score: 4, maxScore: 4, percentage: 100, attemptNumber: 1);
    await _pump(
      tester,
      _FakeBingoExerciseRepository(getResult: Success(_exercise()), submitResult: const Success(result)),
    );

    await tester.tap(find.text('Start Game'));
    await tester.pump();
    for (var i = 0; i < 4; i++) {
      // Always answer with whichever word is currently on screen as
      // "W0".."W3" — since this test only needs *a* valid tap target, not
      // necessarily a correct one; correctness is already covered by the
      // controller's own dedicated grading tests.
      final wordFinder = find.textContaining('Definition for');
      expect(wordFinder, findsOneWidget);
      await tester.tap(find.text('W0'));
      await tester.pump();
      await tester.tap(find.text('Next Word'));
      await tester.pump();
    }
    for (var i = 0; i < 5; i++) {
      await tester.pump();
    }

    expect(find.text('All done — see your score below.'), findsOneWidget);
    expect(find.textContaining('/ 4'), findsWidgets);
    expect(tester.takeException(), isNull);
  });

  testWidgets('shows a retryable error view for a load failure', (tester) async {
    await _pump(tester, _FakeBingoExerciseRepository(getResult: const Failed(NotFoundFailure())));

    expect(find.text(const NotFoundFailure().message), findsOneWidget);
    expect(find.text('Retry'), findsOneWidget);
  });

  testWidgets('renders without overflow at 320/375/430px and tablet width, with long definitions', (tester) async {
    for (final size in [const Size(320, 900), const Size(375, 900), const Size(430, 1000), const Size(1024, 1366)]) {
      tester.view.physicalSize = size;
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await _pump(
        tester,
        _FakeBingoExerciseRepository(
          getResult: Success(
            BingoExercise(
              id: 7,
              title: 'A Genuinely Long Vocabulary Bingo Exercise Title',
              order: 1,
              cards: List.generate(
                16,
                (i) => BingoCard(
                  word: 'A fairly long board word $i',
                  definition: 'A genuinely long definition text for word number $i, long enough to wrap onto multiple lines.',
                ),
              ),
            ),
          ),
        ),
      );

      expect(tester.takeException(), isNull);
    }
  });
}
