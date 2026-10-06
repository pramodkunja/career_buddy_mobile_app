import 'dart:async';

import 'package:career_buddy_lms/core/errors/failures.dart';
import 'package:career_buddy_lms/core/utils/result.dart';
import 'package:career_buddy_lms/features/activities/domain/entities/exercise_attempt.dart';
import 'package:career_buddy_lms/features/ai_reading/domain/entities/reading_analysis_result.dart';
import 'package:career_buddy_lms/features/ai_reading/domain/entities/reading_issue.dart';
import 'package:career_buddy_lms/features/ai_reading/domain/entities/reading_passage.dart';
import 'package:career_buddy_lms/features/ai_reading/domain/repositories/ai_reading_repository.dart';
import 'package:career_buddy_lms/features/ai_reading/presentation/providers/ai_reading_providers.dart';
import 'package:career_buddy_lms/features/ai_reading/presentation/screens/ai_reading_screen.dart';
import 'package:career_buddy_lms/features/ai_speaking/domain/services/audio_recorder_service.dart';
import 'package:career_buddy_lms/features/ai_speaking/presentation/providers/ai_speaking_providers.dart' show audioRecorderServiceProvider;
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

class _FakeAudioRecorderService implements AudioRecorderService {
  bool permissionGranted = true;
  String? stopPath = '/tmp/rec.m4a';

  @override
  Future<bool> hasPermission() async => permissionGranted;

  @override
  Future<void> start() async {}

  @override
  Future<void> pause() async {}

  @override
  Future<void> resume() async {}

  @override
  Future<String?> stop() async => stopPath;

  @override
  Future<void> cancel() async {}
}

class _FakeAiReadingRepository implements AiReadingRepository {
  Result<ReadingAnalysisResult>? analyzeResult;
  Completer<Result<ReadingAnalysisResult>>? pendingAnalyze;
  int analyzeCallCount = 0;

  @override
  Future<Result<ReadingAnalysisResult>> analyze({
    required int exerciseId,
    required String audioFilePath,
    required double durationSeconds,
    required int pauseCount,
    required String language,
    required String referenceText,
  }) async {
    analyzeCallCount++;
    if (pendingAnalyze != null) return pendingAnalyze!.future;
    return analyzeResult!;
  }
}

ReadingAnalysisResult _result({int score25 = 21}) => ReadingAnalysisResult(
  text: 'The reference passage with issues highlighted.',
  issues: const [ReadingIssue(phrase: 'a apple', type: 'Pronunciation', message: 'Mispronounced.', suggestion: 'an apple')],
  improvedPassage: 'An improved reading passage.',
  feedback: 'Great reading. You are improving with good pace and clarity.',
  quickTip: 'Track each word carefully and try to match the passage exactly as written.',
  scores: const {'accuracy': 90},
  score25: score25,
);

Future<void> _pump(
  WidgetTester tester, {
  required _FakeAiReadingRepository repo,
  _FakeAudioRecorderService? recorder,
  ExerciseAttempt? previousAttempt,
  double width = 800,
}) async {
  // A tall viewport keeps the whole page (mic button, Submit, Try Again,
  // Previous Score) realized and on-screen at once, avoiding both the
  // plain ListView's below-the-fold lazy-child gotcha and hit-test misses
  // against controls pushed down the page.
  tester.view.physicalSize = Size(width, 3000);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  // Force full teardown of any previously-pumped tree first — `ProviderScope`
  // reuses its existing container across a same-type `pumpWidget` call in
  // the same test, which silently leaks a permanently-locked `ReadingResult`
  // state across loop iterations otherwise (see the responsive test).
  await tester.pumpWidget(const SizedBox.shrink());
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        authRepositoryProvider.overrideWithValue(_FakeAuthRepository()),
        audioRecorderServiceProvider.overrideWithValue(recorder ?? _FakeAudioRecorderService()),
        aiReadingRepositoryProvider.overrideWithValue(repo),
      ],
      child: MaterialApp(
        home: AiReadingScreen(exerciseId: 1, activityId: 12, subActivityId: 34, activityTitle: 'Professional Reading', previousAttempt: previousAttempt),
      ),
    ),
  );
  await tester.pump();
}

void main() {
  group('rendering — idle', () {
    testWidgets('shows the level-1 passage, its text, and a disabled Pause with an enabled mic', (tester) async {
      final repo = _FakeAiReadingRepository();
      await _pump(tester, repo: repo);

      expect(find.text('Tap to Start Recording'), findsOneWidget);
      expect(find.byIcon(Icons.mic), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('"New" switches to a different passage from the same level', (tester) async {
      final repo = _FakeAiReadingRepository();
      await _pump(tester, repo: repo);
      final initialTitle = find.byType(Text).evaluate().map((e) => (e.widget as Text).data).whereType<String>().toList();

      await tester.tap(find.text('New'));
      await tester.pump();

      final afterTitles = find.byType(Text).evaluate().map((e) => (e.widget as Text).data).whereType<String>().toList();
      expect(afterTitles, isNot(equals(initialTitle)));
    });

    testWidgets('tapping a level chip switches level', (tester) async {
      final repo = _FakeAiReadingRepository();
      await _pump(tester, repo: repo);

      await tester.tap(find.text('Level 2'));
      await tester.pump();

      final level2Titles = kReadingPassagesByLevel[2]!.map((p) => p.title);
      expect(level2Titles.any((t) => find.text(t).evaluate().isNotEmpty), isTrue);
    });
  });

  group('real controller flow', () {
    testWidgets('idle -> recording -> recorded -> submitted -> result, end to end', (tester) async {
      final recorder = _FakeAudioRecorderService();
      final repo = _FakeAiReadingRepository()..analyzeResult = Success(_result(score25: 21));
      await _pump(tester, repo: repo, recorder: recorder);

      expect(find.text('Tap to Start Recording'), findsOneWidget);

      await tester.tap(find.byIcon(Icons.mic));
      await tester.pump();
      expect(find.byIcon(Icons.stop), findsOneWidget);

      await tester.tap(find.byIcon(Icons.stop));
      await tester.pump();
      expect(find.text('Submit for Analysis'), findsOneWidget);

      await tester.tap(find.text('Submit for Analysis'));
      for (var i = 0; i < 5; i++) {
        await tester.pump();
      }

      expect(find.text('21/25'), findsOneWidget);
      expect(find.text('An improved reading passage.'), findsOneWidget);
      expect(find.text('Great reading. You are improving with good pace and clarity.'), findsOneWidget);
      expect(find.text('Track each word carefully and try to match the passage exactly as written.'), findsOneWidget);
      expect(find.text('"a apple"'), findsOneWidget);
      expect(find.text('Try Again'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('submitting shows a loading indicator via a controllable pending analyze call', (tester) async {
      final recorder = _FakeAudioRecorderService();
      final repo = _FakeAiReadingRepository()..pendingAnalyze = Completer<Result<ReadingAnalysisResult>>();
      await _pump(tester, repo: repo, recorder: recorder);

      await tester.tap(find.byIcon(Icons.mic));
      await tester.pump();
      await tester.tap(find.byIcon(Icons.stop));
      await tester.pump();
      await tester.tap(find.text('Submit for Analysis'));
      await tester.pump();

      expect(find.byType(CircularProgressIndicator), findsOneWidget);

      repo.pendingAnalyze!.complete(Success(_result(score25: 19)));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));

      expect(find.text('19/25'), findsOneWidget);
    });

    testWidgets('denied microphone permission shows an error without entering the recording state', (tester) async {
      final recorder = _FakeAudioRecorderService()..permissionGranted = false;
      final repo = _FakeAiReadingRepository();
      await _pump(tester, repo: repo, recorder: recorder);

      await tester.tap(find.byIcon(Icons.mic));
      await tester.pump();

      expect(find.textContaining('Microphone access denied'), findsOneWidget);
      expect(find.byIcon(Icons.stop), findsNothing);
    });

    testWidgets('"Try Again" resets to idle on the same passage after a result, unlocking submission', (tester) async {
      final recorder = _FakeAudioRecorderService();
      final repo = _FakeAiReadingRepository()..analyzeResult = Success(_result(score25: 18));
      await _pump(tester, repo: repo, recorder: recorder);

      await tester.tap(find.byIcon(Icons.mic));
      await tester.pump();
      await tester.tap(find.byIcon(Icons.stop));
      await tester.pump();
      await tester.tap(find.text('Submit for Analysis'));
      for (var i = 0; i < 5; i++) {
        await tester.pump();
      }
      expect(find.text('18/25'), findsOneWidget);

      await tester.tap(find.text('Try Again'));
      await tester.pump();

      expect(find.text('Tap to Start Recording'), findsOneWidget);
      expect(find.text('18/25'), findsNothing);
    });

    testWidgets('a failed submission shows the failure message and allows retrying', (tester) async {
      final recorder = _FakeAudioRecorderService();
      final repo = _FakeAiReadingRepository()..analyzeResult = const Failed(ServerFailure());
      await _pump(tester, repo: repo, recorder: recorder);

      await tester.tap(find.byIcon(Icons.mic));
      await tester.pump();
      await tester.tap(find.byIcon(Icons.stop));
      await tester.pump();
      await tester.tap(find.text('Submit for Analysis'));
      for (var i = 0; i < 5; i++) {
        await tester.pump();
      }

      expect(find.text(const ServerFailure().message), findsOneWidget);
      expect(find.text('Retry Analysis'), findsOneWidget);

      repo.analyzeResult = Success(_result(score25: 17));
      await tester.tap(find.text('Retry Analysis'));
      for (var i = 0; i < 5; i++) {
        await tester.pump();
      }

      expect(find.text('17/25'), findsOneWidget);
      expect(repo.analyzeCallCount, 2);
    });
  });

  group('previous score', () {
    testWidgets('shows the Previous Score card when a previous attempt is supplied', (tester) async {
      final repo = _FakeAiReadingRepository();
      await _pump(
        tester,
        repo: repo,
        previousAttempt: ExerciseAttempt(score: 16, maxScore: 25, percentage: 64, attemptNumber: 1, completedAt: DateTime(2026, 4, 1)),
      );

      expect(find.text('Previous Score'), findsOneWidget);
      expect(find.text('16/25'), findsOneWidget);
    });

    testWidgets('shows no Previous Score card when there is no previous attempt', (tester) async {
      final repo = _FakeAiReadingRepository();
      await _pump(tester, repo: repo);

      expect(find.text('Previous Score'), findsNothing);
    });
  });

  group('responsive', () {
    testWidgets('renders the idle and result states without overflow at 320/375/430px', (tester) async {
      for (final width in [320.0, 375.0, 430.0]) {
        final repo = _FakeAiReadingRepository()..analyzeResult = Success(_result());
        await _pump(
          tester,
          repo: repo,
          width: width,
          previousAttempt: ExerciseAttempt(score: 16, maxScore: 25, percentage: 64, attemptNumber: 1, completedAt: DateTime(2026, 4, 1)),
        );
        await tester.tap(find.byIcon(Icons.mic));
        await tester.pump();
        await tester.tap(find.byIcon(Icons.stop));
        await tester.pump();
        await tester.tap(find.text('Submit for Analysis'));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 400));
        expect(tester.takeException(), isNull);
      }
    });
  });
}
