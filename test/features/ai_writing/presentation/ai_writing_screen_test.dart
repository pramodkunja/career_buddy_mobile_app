import 'dart:async';

import 'package:career_buddy_lms/core/errors/failures.dart';
import 'package:career_buddy_lms/core/utils/result.dart';
import 'package:career_buddy_lms/features/activities/domain/entities/exercise_attempt.dart';
import 'package:career_buddy_lms/features/ai_writing/domain/entities/writing_analysis_result.dart';
import 'package:career_buddy_lms/features/ai_writing/domain/entities/writing_issue.dart';
import 'package:career_buddy_lms/features/ai_writing/domain/entities/writing_topic.dart';
import 'package:career_buddy_lms/features/ai_writing/domain/repositories/ai_writing_repository.dart';
import 'package:career_buddy_lms/features/ai_writing/presentation/providers/ai_writing_providers.dart';
import 'package:career_buddy_lms/features/ai_writing/presentation/screens/ai_writing_screen.dart';
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

class _FakeAiWritingRepository implements AiWritingRepository {
  Result<WritingAnalysisResult>? analyzeResult;
  int analyzeCallCount = 0;

  /// When set, `analyze()` awaits this instead of returning immediately —
  /// lets a test observe the transient `WritingSubmitting` frame, which a
  /// same-microtask-resolving fake would otherwise skip straight past
  /// before the first `pump()` ever renders it.
  Completer<Result<WritingAnalysisResult>>? pendingAnalyze;

  @override
  Future<Result<WritingAnalysisResult>> analyze({
    required int exerciseId,
    required String text,
    required String language,
    required String referenceText,
    String? previousImprovedPassage,
  }) async {
    analyzeCallCount++;
    if (pendingAnalyze != null) return pendingAnalyze!.future;
    return analyzeResult!;
  }
}

WritingAnalysisResult _result({int score25 = 21}) => WritingAnalysisResult(
  text: 'This is my essay text.',
  issues: const [WritingIssue(phrase: 'a apple', type: 'Grammar', message: 'Article mismatch.', suggestion: 'an apple')],
  improvedPassage: 'This is my improved essay.',
  feedback: 'Solid attempt overall.',
  quickTip: 'Read your draft once more.',
  scores: const {'grammar': 90},
  score25: score25,
);

Future<void> _pump(
  WidgetTester tester, {
  _FakeAiWritingRepository? repo,
  ExerciseAttempt? previousAttempt,
}) async {
  // The default 800×600 test surface is no longer tall enough for
  // `ModuleHero` + the rest of the idle content to all sit within the
  // hit-testable viewport at once.
  tester.view.physicalSize = const Size(800, 1400);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);

  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        authRepositoryProvider.overrideWithValue(_FakeAuthRepository()),
        aiWritingRepositoryProvider.overrideWithValue(repo ?? _FakeAiWritingRepository()),
      ],
      child: MaterialApp(
        home: AiWritingScreen(exerciseId: 1, activityId: 12, subActivityId: 34, activityTitle: 'Professional Passage Writing', previousAttempt: previousAttempt),
      ),
    ),
  );
  await tester.pump();
}

void main() {
  group('rendering — idle', () {
    testWidgets('shows the hardcoded initial topic, "general" type, and an empty, disabled-submit writing area', (
      tester,
    ) async {
      await _pump(tester);

      expect(find.text(kWritingInitialTopic), findsOneWidget);
      expect(find.text('Your Answer'), findsOneWidget);
      expect(find.text('0 / 500–900 chars'), findsOneWidget);
      final submitButton = tester.widget<ElevatedButton>(find.widgetWithText(ElevatedButton, 'Submit for Analysis'));
      expect(submitButton.onPressed, isNull);
      expect(tester.takeException(), isNull);
    });

    testWidgets('typing text updates the character counter live', (tester) async {
      await _pump(tester);

      await tester.enterText(find.byType(TextField), 'hello world');
      await tester.pump();

      expect(find.text('10 / 500–900 chars'), findsOneWidget); // "helloworld" = 10 non-space chars
    });

    testWidgets('Submit stays disabled below 500 non-space characters, with the "at least" warning', (tester) async {
      await _pump(tester);

      await tester.enterText(find.byType(TextField), 'a' * 100);
      await tester.pump();

      final submitButton = tester.widget<ElevatedButton>(find.widgetWithText(ElevatedButton, 'Submit for Analysis'));
      expect(submitButton.onPressed, isNull);
      expect(find.text('Please write at least 500 characters.'), findsOneWidget);
    });

    testWidgets('Submit stays disabled above 900 non-space characters, with the "within" warning', (tester) async {
      await _pump(tester);

      await tester.enterText(find.byType(TextField), 'a' * 950);
      await tester.pump();

      final submitButton = tester.widget<ElevatedButton>(find.widgetWithText(ElevatedButton, 'Submit for Analysis'));
      expect(submitButton.onPressed, isNull);
      expect(find.text('Please keep your answer within 900 characters.'), findsOneWidget);
    });

    testWidgets('Submit becomes enabled within the 500-900 range, with no warning shown', (tester) async {
      await _pump(tester);

      await tester.enterText(find.byType(TextField), 'a' * 600);
      await tester.pump();

      final submitButton = tester.widget<ElevatedButton>(find.widgetWithText(ElevatedButton, 'Submit for Analysis'));
      expect(submitButton.onPressed, isNotNull);
      expect(find.text('Please write at least 500 characters.'), findsNothing);
      expect(find.text('Please keep your answer within 900 characters.'), findsNothing);
    });

    testWidgets('"New Topic" switches to a topic from the same pool and clears the text field', (tester) async {
      await _pump(tester);
      await tester.enterText(find.byType(TextField), 'a' * 600);
      await tester.pump();

      await tester.tap(find.text('New Topic'));
      await tester.pump();

      expect((tester.widget(find.byType(TextField)) as TextField).controller!.text, isEmpty);
      expect(find.text('0 / 500–900 chars'), findsOneWidget);
    });

    testWidgets('changing the writing type switches topic pool and clears the text field', (tester) async {
      await _pump(tester);
      await tester.enterText(find.byType(TextField), 'a' * 600);
      await tester.pump();

      await tester.tap(find.byType(DropdownButton<String>).first);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));
      await tester.tap(find.text('Story').last);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));

      expect((tester.widget(find.byType(TextField)) as TextField).controller!.text, isEmpty);
      expect(kWritingTopicsByType['story']!.any((t) => find.text(t).evaluate().isNotEmpty), isTrue);
    });
  });

  group('submission', () {
    /// A plain `ListView(children: …)` is still a Sliver-backed list — it
    /// only builds children within/near the viewport. Rather than juggling
    /// flings to bring newly-appended children (the result/error card,
    /// added once state moves past `WritingIdle`) into view, these
    /// submission tests use a tall enough viewport that the whole page
    /// fits without scrolling at all.
    Future<void> useTallViewport(WidgetTester tester) async {
      tester.view.physicalSize = const Size(800, 3000);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
    }

    testWidgets('submitting shows the loading state, then the server-computed result', (tester) async {
      await useTallViewport(tester);
      final repo = _FakeAiWritingRepository()..pendingAnalyze = Completer<Result<WritingAnalysisResult>>();
      await _pump(tester, repo: repo);
      await tester.enterText(find.byType(TextField), 'a' * 600);
      await tester.pump();

      await tester.tap(find.text('Submit for Analysis'));
      await tester.pump();

      // AppButton with isLoading:true swaps the label for a spinner
      // entirely — it never renders "Analyzing…" as text.
      expect(find.byType(CircularProgressIndicator), findsOneWidget);

      repo.pendingAnalyze!.complete(Success(_result(score25: 21)));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));

      expect(find.text('21/25'), findsOneWidget);
      expect(find.text('This is my improved essay.'), findsOneWidget);
      expect(find.text('Solid attempt overall.'), findsOneWidget);
      expect(find.text('Read your draft once more.'), findsOneWidget);
      expect(find.text('"a apple"'), findsOneWidget);
      expect(tester.takeException(), isNull);
      // The textarea keeps the text — Writing has no "Try Again" reset,
      // unlike AI Speaking.
      expect((tester.widget(find.byType(TextField)) as TextField).controller!.text, 'a' * 600);
    });

    testWidgets('a failed submission shows the failure message and stays retryable', (tester) async {
      await useTallViewport(tester);
      final repo = _FakeAiWritingRepository()..analyzeResult = const Failed(ServerFailure());
      await _pump(tester, repo: repo);
      await tester.enterText(find.byType(TextField), 'a' * 600);
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
    });

    testWidgets('resubmitting after a result re-analyzes instead of being blocked', (tester) async {
      await useTallViewport(tester);
      final repo = _FakeAiWritingRepository()..analyzeResult = Success(_result(score25: 15));
      await _pump(tester, repo: repo);
      await tester.enterText(find.byType(TextField), 'a' * 600);
      await tester.pump();
      await tester.tap(find.text('Submit for Analysis'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));
      expect(find.text('15/25'), findsOneWidget);

      repo.analyzeResult = Success(_result(score25: 24));
      await tester.enterText(find.byType(TextField), 'b' * 650);
      await tester.pump();
      await tester.tap(find.text('Submit for Analysis'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));

      expect(find.text('24/25'), findsOneWidget);
      expect(repo.analyzeCallCount, 2);
    });
  });

  group('previous score', () {
    testWidgets('shows the Previous Score card when a previous attempt is supplied', (tester) async {
      await _pump(
        tester,
        previousAttempt: ExerciseAttempt(score: 18, maxScore: 25, percentage: 72, attemptNumber: 1, completedAt: DateTime(2026, 2, 10)),
      );

      await tester.fling(find.byType(ListView), const Offset(0, -2000), 3000, warnIfMissed: false);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 1000));

      expect(find.text('Previous Score'), findsOneWidget);
      expect(find.text('18/25'), findsOneWidget);
    });

    testWidgets('shows no Previous Score card when there is no previous attempt', (tester) async {
      await _pump(tester);

      expect(find.text('Previous Score'), findsNothing);
    });
  });

  group('responsive', () {
    testWidgets('renders the idle and result states without overflow at 320/375/430px', (tester) async {
      for (final width in [320.0, 375.0, 430.0]) {
        tester.view.physicalSize = Size(width, 800);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);

        await _pump(
          tester,
          previousAttempt: ExerciseAttempt(score: 18, maxScore: 25, percentage: 72, attemptNumber: 1, completedAt: DateTime(2026, 2, 10)),
        );
        expect(tester.takeException(), isNull);

        final repo = _FakeAiWritingRepository()..analyzeResult = Success(_result());
        await _pump(tester, repo: repo);
        await tester.enterText(find.byType(TextField), 'a' * 600);
        await tester.pump();
        await tester.fling(find.byType(ListView), const Offset(0, -2000), 3000, warnIfMissed: false);
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 1000));
        await tester.tap(find.text('Submit for Analysis'));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 400));
        expect(tester.takeException(), isNull);
      }
    });
  });
}
