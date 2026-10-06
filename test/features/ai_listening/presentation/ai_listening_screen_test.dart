import 'package:career_buddy_lms/core/errors/failures.dart';
import 'package:career_buddy_lms/core/utils/result.dart';
import 'package:career_buddy_lms/features/activities/domain/entities/exercise_attempt.dart';
import 'package:career_buddy_lms/features/ai_listening/domain/entities/listening_analysis_result.dart';
import 'package:career_buddy_lms/features/ai_listening/domain/repositories/ai_listening_repository.dart';
import 'package:career_buddy_lms/features/ai_listening/domain/services/listening_tts_service.dart';
import 'package:career_buddy_lms/features/ai_listening/presentation/providers/ai_listening_providers.dart';
import 'package:career_buddy_lms/features/ai_listening/presentation/screens/ai_listening_screen.dart';
import 'package:career_buddy_lms/features/auth/domain/entities/auth_user.dart';
import 'package:career_buddy_lms/features/auth/domain/entities/student_registration_data.dart';
import 'package:career_buddy_lms/features/auth/domain/repositories/auth_repository.dart';
import 'package:career_buddy_lms/features/auth/presentation/providers/auth_providers.dart';
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

class _FakeListeningTtsService implements ListeningTtsService {
  void Function()? _onStart;

  @override
  Future<void> speak(String text, {required double rate}) async =>
      _onStart?.call();

  @override
  Future<void> pause() async {}

  @override
  Future<void> stop() async {}

  @override
  void setOnStart(void Function() callback) => _onStart = callback;

  @override
  void setOnComplete(void Function() callback) {}

  @override
  void setOnError(void Function(String message) callback) {}
}

class _FakeAiListeningRepository implements AiListeningRepository {
  Result<String>? tokenResult;
  Result<ListeningAnalysisResult>? analyzeResult;
  int analyzeCallCount = 0;

  @override
  Future<Result<String>> fetchAttemptToken(int exerciseId) async =>
      tokenResult!;

  @override
  Future<Result<ListeningAnalysisResult>> analyze({
    required int exerciseId,
    required String text,
    required String referenceText,
    required int durationSeconds,
    required int pauseCount,
    required String attemptToken,
    required String language,
  }) async {
    analyzeCallCount++;
    return analyzeResult!;
  }
}

ListeningAnalysisResult _result({int score25 = 20, int match = 80}) =>
    ListeningAnalysisResult(
      text: 'My summary.',
      issues: const [],
      improvedPassage: 'An improved summary.',
      feedback: 'Nice job.',
      scores: const {'fluency': 90},
      score25: score25,
      contentMatchPercent: match,
    );

Future<void> _pump(
  WidgetTester tester, {
  required _FakeAiListeningRepository repo,
  ExerciseAttempt? previousAttempt,
  bool tallViewport = false,
}) async {
  if (tallViewport) {
    tester.view.physicalSize = const Size(800, 3000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
  }
  // Force full teardown of any previously-pumped tree first: `ProviderScope`
  // reuses its existing `ProviderContainer` (and thus controller state)
  // across a same-type `pumpWidget` call in the same test, which is fine
  // for freely-resubmittable modules (Writing) but silently leaks a
  // permanently-locked `SubmissionSucceeded` state across loop iterations
  // here (Listening locks after one success) — this only matters for tests
  // that call `_pump` more than once, e.g. the responsive width loop.
  await tester.pumpWidget(const SizedBox.shrink());
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        authRepositoryProvider.overrideWithValue(_FakeAuthRepository()),
        aiListeningRepositoryProvider.overrideWithValue(repo),
        listeningTtsServiceProvider.overrideWithValue(
          _FakeListeningTtsService(),
        ),
      ],
      child: MaterialApp(
        home: AiListeningScreen(
          exerciseId: 1,
          activityId: 12,
          subActivityId: 34,
          activityTitle: 'Listen & Write',
          previousAttempt: previousAttempt,
        ),
      ),
    ),
  );
  for (var i = 0; i < 5; i++) {
    await tester.pump();
  }
}

void main() {
  group('loading and error', () {
    testWidgets(
      'shows a loading indicator while the attempt token is being fetched',
      (tester) async {
        final repo = _FakeAiListeningRepository()
          ..tokenResult = const Success('tok-1');
        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              authRepositoryProvider.overrideWithValue(_FakeAuthRepository()),
              aiListeningRepositoryProvider.overrideWithValue(repo),
              listeningTtsServiceProvider.overrideWithValue(
                _FakeListeningTtsService(),
              ),
            ],
            child: const MaterialApp(
              home: AiListeningScreen(
                exerciseId: 1,
                activityId: 12,
                subActivityId: 34,
                activityTitle: 'Listen & Write',
              ),
            ),
          ),
        );
        // No pump yet — the token fetch hasn't resolved.
        expect(find.byType(CircularProgressIndicator), findsOneWidget);
      },
    );

    testWidgets('shows a retryable error view when the token fetch fails', (
      tester,
    ) async {
      final repo = _FakeAiListeningRepository()
        ..tokenResult = const Failed(ForbiddenFailure());
      await _pump(tester, repo: repo);

      expect(find.text(const ForbiddenFailure().message), findsOneWidget);
      expect(find.text('Retry'), findsOneWidget);
    });

    testWidgets(
      'Retry re-fetches the token and recovers into the active state',
      (tester) async {
        final repo = _FakeAiListeningRepository()
          ..tokenResult = const Failed(ServerFailure());
        await _pump(tester, repo: repo);
        expect(find.text('Retry'), findsOneWidget);

        repo.tokenResult = const Success('tok-2');
        await tester.tap(find.text('Retry'));
        for (var i = 0; i < 5; i++) {
          await tester.pump();
        }

        expect(find.text('Retry'), findsNothing);
        expect(find.text('What Did You Understand?'), findsOneWidget);
      },
    );
  });

  group('rendering — active/idle', () {
    testWidgets(
      'shows the story title, player controls, and an always-enabled Submit button',
      (tester) async {
        final repo = _FakeAiListeningRepository()
          ..tokenResult = const Success('tok-1');
        await _pump(tester, repo: repo);

        expect(find.text('What Did You Understand?'), findsOneWidget);
        final submitButton = tester.widget<ElevatedButton>(
          find.widgetWithText(ElevatedButton, 'Submit for Analysis'),
        );
        expect(submitButton.onPressed, isNotNull);
        expect(tester.takeException(), isNull);
      },
    );

    testWidgets(
      'the story text is hidden until Play is tapped, then revealed',
      (tester) async {
        final repo = _FakeAiListeningRepository()
          ..tokenResult = const Success('tok-1');
        await _pump(tester, repo: repo);
        expect(find.text('Status: Ready'), findsOneWidget);

        await tester.tap(find.byIcon(Icons.play_arrow));
        await tester.pump();

        expect(find.text('Status: Playing'), findsOneWidget);
      },
    );
  });

  group('submission', () {
    testWidgets(
      'a successful submission shows the score, content match, and locks the form',
      (tester) async {
        final repo = _FakeAiListeningRepository()
          ..tokenResult = const Success('tok-1')
          ..analyzeResult = Success(_result(score25: 21, match: 85));
        await _pump(tester, repo: repo, tallViewport: true);

        await tester.enterText(
          find.byType(TextField).last,
          'A meaningful enough summary of the story goes here.',
        );
        await tester.pump();
        await tester.tap(find.text('Submit for Analysis'));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 400));

        expect(find.text('21/25'), findsOneWidget);
        expect(find.text('85% Match'), findsOneWidget);
        expect(find.text('Already Submitted'), findsOneWidget);
        final button = tester.widget<ElevatedButton>(
          find.widgetWithText(ElevatedButton, 'Already Submitted'),
        );
        expect(button.onPressed, isNull);
        expect(tester.takeException(), isNull);
      },
    );

    testWidgets(
      'a failed submission shows the failure message and stays retryable',
      (tester) async {
        final repo = _FakeAiListeningRepository()
          ..tokenResult = const Success('tok-1')
          ..analyzeResult = const Failed(ServerFailure());
        await _pump(tester, repo: repo, tallViewport: true);

        await tester.enterText(
          find.byType(TextField).last,
          'A meaningful enough summary of the story goes here.',
        );
        await tester.pump();
        await tester.tap(find.text('Submit for Analysis'));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 400));

        expect(find.text(const ServerFailure().message), findsOneWidget);

        repo.analyzeResult = Success(_result(score25: 19));
        await tester.tap(find.text('Submit for Analysis'));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 400));

        expect(find.text('19/25'), findsOneWidget);
        expect(repo.analyzeCallCount, 2);
      },
    );

    testWidgets(
      'submitting too-short text shows a local validation message without calling the server',
      (tester) async {
        final repo = _FakeAiListeningRepository()
          ..tokenResult = const Success('tok-1');
        await _pump(tester, repo: repo, tallViewport: true);

        await tester.enterText(find.byType(TextField).last, 'too short');
        await tester.pump();
        await tester.tap(find.text('Submit for Analysis'));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 400));

        expect(
          find.text(
            'Write your listening summary first, then click Analyze to see highlighted mistakes.',
          ),
          findsOneWidget,
        );
        expect(repo.analyzeCallCount, 0);
      },
    );
  });

  group('previous score', () {
    testWidgets(
      'shows the Previous Score card when a previous attempt is supplied',
      (tester) async {
        final repo = _FakeAiListeningRepository()
          ..tokenResult = const Success('tok-1');
        await _pump(
          tester,
          repo: repo,
          tallViewport: true,
          previousAttempt: ExerciseAttempt(
            score: 15,
            maxScore: 25,
            percentage: 60,
            attemptNumber: 1,
            completedAt: DateTime(2026, 3, 1),
          ),
        );

        expect(find.text('Previous Score'), findsOneWidget);
        expect(find.text('15/25'), findsOneWidget);
      },
    );

    testWidgets(
      'shows no Previous Score card when there is no previous attempt',
      (tester) async {
        final repo = _FakeAiListeningRepository()
          ..tokenResult = const Success('tok-1');
        await _pump(tester, repo: repo);

        expect(find.text('Previous Score'), findsNothing);
      },
    );
  });

  group('responsive', () {
    testWidgets(
      'renders the idle and result states without overflow at 320/375/430px',
      (tester) async {
        for (final width in [320.0, 375.0, 430.0]) {
          // A tall viewport keeps the whole page realized at once — avoids
          // the plain ListView's below-the-fold lazy-child gotcha (see the
          // `_pump`/`tallViewport` helper's doc comment) while still
          // exercising layout at each narrow width.
          tester.view.physicalSize = Size(width, 3000);
          tester.view.devicePixelRatio = 1.0;
          addTearDown(tester.view.resetPhysicalSize);
          addTearDown(tester.view.resetDevicePixelRatio);

          final repo = _FakeAiListeningRepository()
            ..tokenResult = const Success('tok-1')
            ..analyzeResult = Success(_result());
          await _pump(
            tester,
            repo: repo,
            previousAttempt: ExerciseAttempt(
              score: 15,
              maxScore: 25,
              percentage: 60,
              attemptNumber: 1,
              completedAt: DateTime(2026, 3, 1),
            ),
          );
          await tester.enterText(
            find.byType(TextField).last,
            'A meaningful enough summary of the story goes here.',
          );
          await tester.pump();
          await tester.tap(find.text('Submit for Analysis'));
          await tester.pump();
          await tester.pump(const Duration(milliseconds: 400));
          expect(tester.takeException(), isNull);
        }
      },
    );
  });
}
