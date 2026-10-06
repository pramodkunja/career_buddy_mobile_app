import 'package:career_buddy_lms/core/errors/failures.dart';
import 'package:career_buddy_lms/core/utils/result.dart';
import 'package:career_buddy_lms/features/auth/domain/entities/auth_user.dart';
import 'package:career_buddy_lms/features/auth/domain/entities/student_registration_data.dart';
import 'package:career_buddy_lms/features/auth/domain/repositories/auth_repository.dart';
import 'package:career_buddy_lms/features/auth/presentation/providers/auth_providers.dart';
import 'package:career_buddy_lms/features/roleplay/domain/entities/roleplay_analysis_result.dart';
import 'package:career_buddy_lms/features/roleplay/domain/entities/roleplay_generated_content.dart';
import 'package:career_buddy_lms/features/roleplay/domain/entities/roleplay_issue.dart';
import 'package:career_buddy_lms/features/roleplay/domain/repositories/roleplay_repository.dart';
import 'package:career_buddy_lms/features/roleplay/presentation/controllers/roleplay_controller.dart';
import 'package:career_buddy_lms/features/roleplay/presentation/providers/roleplay_providers.dart';
import 'package:career_buddy_lms/features/roleplay/presentation/screens/roleplay_practice_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

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

class _FakeRoleplayRepository implements RoleplayRepository {
  Result<RoleplayGeneratedContent>? generateResult;
  Result<RoleplayAnalysisResult>? analyzeResult;

  @override
  Future<Result<RoleplayGeneratedContent>> generatePractice({
    required String topicSlug,
    required String prompt,
    required String language,
  }) async => generateResult!;

  @override
  Future<Result<RoleplayAnalysisResult>> analyze({
    required String topicLabel,
    required String audioFilePath,
    required double durationSeconds,
    required int pauseCount,
    required String language,
    required String referenceText,
  }) async => analyzeResult!;
}

/// A [RoleplayController] that starts from a fixed, caller-supplied state —
/// lets widget tests render every sealed state directly, without driving
/// the real recorder/timer machinery. `build()` deliberately skips
/// `super.build()`'s `_recorder` wiring — tests using this must not tap a
/// control that touches the recorder (`startQuestions`/`finishAndAnalyze`).
class _FixedController extends RoleplayController {
  _FixedController(super.topicSlug, this.fixedState);
  final RoleplayState fixedState;

  @override
  RoleplayState build() => fixedState;
}

Future<void> _pumpFixed(WidgetTester tester, String topicSlug, RoleplayState fixedState, {RoleplayRepository? repo}) async {
  tester.view.physicalSize = const Size(800, 1400);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);

  final router = GoRouter(
    initialLocation: '/',
    routes: [
      GoRoute(path: '/', builder: (context, state) => RoleplayPracticeScreen(topicSlug: topicSlug)),
      GoRoute(path: '/pro', builder: (context, state) => const Scaffold(body: Text('Pro placeholder'))),
    ],
  );

  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        roleplayControllerProvider(topicSlug).overrideWith(() => _FixedController(topicSlug, fixedState)),
        if (repo != null) roleplayRepositoryProvider.overrideWithValue(repo),
        authRepositoryProvider.overrideWithValue(_FakeAuthRepository()),
      ],
      child: MaterialApp.router(routerConfig: router),
    ),
  );
  await tester.pump();
}

RoleplayGeneratedContent _content() => const RoleplayGeneratedContent(
  usedPrompt: 'a rainy day',
  title: 'A Rainy Day',
  contentHeading: 'Short story',
  content: 'Once upon a time, it rained all day.',
  followUps: ['Who is the main character?', 'What happened?', 'What is the lesson?'],
  coachTip: 'Answer clearly.',
);

RoleplayAnalysisResult _analysis() => const RoleplayAnalysisResult(
  transcript: 'My full answer.',
  issues: [RoleplayIssue(phrase: 'a apple', type: 'Grammar', message: 'Article mismatch.', suggestion: 'an apple')],
  improvedPassage: 'My improved answer.',
  feedback: 'Solid attempt overall.',
  quickTip: 'Speak a little slower.',
  scores: {'overall': 72, 'fluency': 75, 'grammar': 80, 'clarity': 65},
  durationSeconds: 30,
  pauseCount: 0,
);

void main() {
  group('rendering — setup', () {
    testWidgets('shows the real placeholder and example chips for the topic', (tester) async {
      await _pumpFixed(tester, 'storytelling', const RoleplaySetup(topicSlug: 'storytelling'));

      expect(find.text('A rainy school day, a missing key, a brave child...'), findsOneWidget);
      expect(find.text('A shy singer on stage'), findsOneWidget);
      expect(find.text('Create Session'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('shows a validation error when set', (tester) async {
      await _pumpFixed(
        tester,
        'roleplay',
        const RoleplaySetup(topicSlug: 'roleplay', validationError: 'Please provide another character to start the roleplay.'),
      );

      expect(find.text('Please provide another character to start the roleplay.'), findsOneWidget);
    });

    testWidgets('tapping an example chip fills the prompt field', (tester) async {
      await _pumpFixed(tester, 'storytelling', const RoleplaySetup(topicSlug: 'storytelling'));

      await tester.tap(find.text('A puppy in the park'));
      await tester.pump();

      final field = tester.widget<TextField>(find.byType(TextField));
      expect(field.controller!.text, 'A puppy in the park');
    });
  });

  group('rendering — locked / generate failed / generating', () {
    testWidgets('RoleplayLocked shows the message and a View Plans action', (tester) async {
      await _pumpFixed(
        tester,
        'roleplay',
        const RoleplayLocked(topicSlug: 'roleplay', promptText: '', message: "You don't have permission to do that."),
      );

      expect(find.text("You don't have permission to do that."), findsOneWidget);
      expect(find.text('View Plans'), findsOneWidget);
    });

    testWidgets('RoleplayGenerateFailed shows the failure message', (tester) async {
      await _pumpFixed(
        tester,
        'storytelling',
        const RoleplayGenerateFailed(topicSlug: 'storytelling', promptText: 'x', failure: ServerFailure()),
      );

      expect(find.text(const ServerFailure().message), findsOneWidget);
      expect(find.text('Create Session'), findsOneWidget);
    });

    testWidgets('RoleplayGenerating shows a loading indicator', (tester) async {
      await _pumpFixed(tester, 'storytelling', const RoleplayGenerating(topicSlug: 'storytelling', promptText: 'x'));

      expect(find.byType(CircularProgressIndicator), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  });

  group('rendering — reading / recording / submitting / failed', () {
    testWidgets('RoleplayReading shows the generated content and the ready action', (tester) async {
      await _pumpFixed(tester, 'storytelling', RoleplayReading(topicSlug: 'storytelling', content: _content()));

      expect(find.text('A Rainy Day'), findsOneWidget);
      expect(find.text('Once upon a time, it rained all day.'), findsOneWidget);
      expect(find.text("I'm Ready - Start Questions"), findsOneWidget);
    });

    testWidgets('RoleplayRecording shows the current question, elapsed time, and Next Question', (tester) async {
      await _pumpFixed(
        tester,
        'storytelling',
        RoleplayRecording(topicSlug: 'storytelling', content: _content(), questionIndex: 0, elapsedSeconds: 5),
      );

      expect(find.text('Question 1 of 3'), findsOneWidget);
      expect(find.text('Who is the main character?'), findsOneWidget);
      expect(find.text('5s'), findsOneWidget);
      expect(find.text('Done - Next Question'), findsOneWidget);
      expect(find.text('Analyze Performance'), findsNothing);
    });

    testWidgets('RoleplayRecording on the last question shows Analyze Performance instead', (tester) async {
      await _pumpFixed(
        tester,
        'storytelling',
        RoleplayRecording(topicSlug: 'storytelling', content: _content(), questionIndex: 2, elapsedSeconds: 20),
      );

      expect(find.text('Question 3 of 3'), findsOneWidget);
      expect(find.text('Analyze Performance'), findsOneWidget);
      expect(find.text('Done - Next Question'), findsNothing);
    });

    testWidgets('RoleplaySubmitting shows a loading indicator', (tester) async {
      await _pumpFixed(
        tester,
        'storytelling',
        RoleplaySubmitting(topicSlug: 'storytelling', content: _content(), audioFilePath: '/tmp/a.m4a', elapsedSeconds: 20),
      );

      expect(find.byType(CircularProgressIndicator), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('RoleplaySubmitFailed shows the failure message and Retry Analysis', (tester) async {
      await _pumpFixed(
        tester,
        'storytelling',
        RoleplaySubmitFailed(
          topicSlug: 'storytelling',
          content: _content(),
          audioFilePath: '/tmp/a.m4a',
          elapsedSeconds: 20,
          failure: const ServerFailure(),
        ),
      );

      expect(find.text(const ServerFailure().message), findsOneWidget);
      expect(find.text('Retry Analysis'), findsOneWidget);
    });

    testWidgets('tapping Retry Analysis re-submits and shows the result on success', (tester) async {
      final repo = _FakeRoleplayRepository()..analyzeResult = Success(_analysis());
      await _pumpFixed(
        tester,
        'storytelling',
        RoleplaySubmitFailed(
          topicSlug: 'storytelling',
          content: _content(),
          audioFilePath: '/tmp/a.m4a',
          elapsedSeconds: 20,
          failure: const ServerFailure(),
        ),
        repo: repo,
      );

      await tester.tap(find.text('Retry Analysis'));
      for (var i = 0; i < 5; i++) {
        await tester.pump();
      }

      expect(find.text('72'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  });

  group('rendering — result', () {
    testWidgets('shows the real scores, feedback, quick tip, and issues from the API response', (tester) async {
      await _pumpFixed(tester, 'storytelling', RoleplayResult(topicSlug: 'storytelling', content: _content(), result: _analysis()));

      expect(find.text('72'), findsOneWidget); // overall
      expect(find.text('75'), findsOneWidget); // fluency
      expect(find.text('80'), findsOneWidget); // grammar
      expect(find.text('65'), findsOneWidget); // clarity
      expect(find.text('Solid attempt overall.'), findsOneWidget);
      expect(find.text('Speak a little slower.'), findsOneWidget);
      expect(find.text('"a apple"'), findsOneWidget);
      expect(find.text('Article mismatch.'), findsOneWidget);
      expect(find.text('Practice Again'), findsOneWidget);
    });

    testWidgets('falls back to the real web fallback feedback string when feedback is empty', (tester) async {
      await _pumpFixed(
        tester,
        'storytelling',
        RoleplayResult(
          topicSlug: 'storytelling',
          content: _content(),
          result: const RoleplayAnalysisResult(
            transcript: 'x',
            issues: [],
            improvedPassage: 'x',
            feedback: null,
            quickTip: null,
            scores: {},
            durationSeconds: 1,
            pauseCount: 0,
          ),
        ),
      );

      expect(find.text('Good job practicing!'), findsOneWidget);
    });

    testWidgets('"Practice Again" resets to an empty Setup', (tester) async {
      await _pumpFixed(tester, 'storytelling', RoleplayResult(topicSlug: 'storytelling', content: _content(), result: _analysis()));

      await tester.tap(find.text('Practice Again'));
      await tester.pump();

      expect(find.text('Create Session'), findsOneWidget);
    });
  });

  group('responsive', () {
    testWidgets('renders the setup and result states without overflow at 320/375/430px', (tester) async {
      for (final width in [320.0, 375.0, 430.0]) {
        tester.view.physicalSize = Size(width, 900);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);

        await _pumpFixed(tester, 'storytelling', const RoleplaySetup(topicSlug: 'storytelling'));
        expect(tester.takeException(), isNull);

        await _pumpFixed(tester, 'storytelling', RoleplayResult(topicSlug: 'storytelling', content: _content(), result: _analysis()));
        expect(tester.takeException(), isNull);
      }
    });
  });
}
