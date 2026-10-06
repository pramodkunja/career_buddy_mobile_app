import 'package:career_buddy_lms/core/utils/result.dart';
import 'package:career_buddy_lms/features/auth/domain/entities/auth_user.dart';
import 'package:career_buddy_lms/features/auth/domain/entities/student_registration_data.dart';
import 'package:career_buddy_lms/features/auth/domain/repositories/auth_repository.dart';
import 'package:career_buddy_lms/features/auth/presentation/providers/auth_providers.dart';
import 'package:career_buddy_lms/features/jam/domain/entities/jam_session_result.dart';
import 'package:career_buddy_lms/features/jam/presentation/screens/jam_result_screen.dart';
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

Widget _wrap(Widget child) {
  return ProviderScope(
    overrides: [authRepositoryProvider.overrideWithValue(_FakeAuthRepository())],
    child: MaterialApp(home: child),
  );
}

const _result = JamSessionResult(
  sessionId: 42,
  topicTitle: 'Describe your favorite hobby',
  topicDifficulty: 'easy',
  durationDisplay: '45s',
  confidenceScore: 4,
  fluencyScore: 3,
  languageScore: 5,
  pronunciationScore: 4,
  timeManagementScore: 5,
  overallScore: 21,
  transcript: 'I really enjoy hiking on weekends.',
  aiFeedback: 'Great job overall, your fluency was strong.',
  improvementTips: 'Try to slow down slightly for clarity.',
  audioUrl: '/media/audio/session_42.webm',
  createdAtDisplay: 'Feb 10 2026 03:45 PM',
);

void main() {
  testWidgets('renders every real field from the parsed result — topic, scores, feedback, transcript, tips', (tester) async {
    await tester.pumpWidget(_wrap(const JamResultScreen(result: _result)));
    await tester.pump();

    expect(find.text('Describe your favorite hobby'), findsOneWidget);
    expect(find.text('Easy Difficulty'), findsOneWidget);
    expect(find.text('45s spoken'), findsOneWidget);
    expect(find.text('Feb 10 2026 03:45 PM'), findsOneWidget);
    expect(find.text('21'), findsOneWidget);
    expect(find.text('4/5'), findsWidgets); // confidence + pronunciation both 4/5
    expect(find.text('3/5'), findsOneWidget);
    expect(find.text('5/5'), findsWidgets); // language + time management both 5/5
    expect(find.text('Great job overall, your fluency was strong.'), findsOneWidget);

    // The transcript/roadmap cards sit below the fold — scroll before
    // asserting on them (same pattern as `ai_speaking_screen_test.dart`).
    await tester.fling(find.byType(ListView), const Offset(0, -2000), 3000, warnIfMissed: false);
    await tester.pump();
    expect(find.text('I really enjoy hiking on weekends.'), findsOneWidget);
    expect(find.text('Try to slow down slightly for clarity.'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('omits the transcript card when there is no transcript', (tester) async {
    const noTranscript = JamSessionResult(
      sessionId: 1,
      topicTitle: 'A topic',
      topicDifficulty: 'medium',
      durationDisplay: '10s',
      confidenceScore: 0,
      fluencyScore: 0,
      languageScore: 0,
      pronunciationScore: 0,
      timeManagementScore: 0,
      overallScore: 0,
      transcript: '',
      aiFeedback: 'No speech detected.',
      improvementTips: '',
      audioUrl: null,
      createdAtDisplay: '',
    );
    await tester.pumpWidget(_wrap(const JamResultScreen(result: noTranscript)));
    await tester.pump();

    expect(find.text('Speech Transcript'), findsNothing);
    expect(find.text('Growth Roadmap'), findsNothing);
    expect(find.text('No speech detected.'), findsOneWidget);
  });

  testWidgets('"Back to Topics" pops the navigation stack', (tester) async {
    await tester.pumpWidget(
      _wrap(
        Builder(
          builder: (context) => ElevatedButton(
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute<void>(builder: (_) => const JamResultScreen(result: _result)),
            ),
            child: const Text('open'),
          ),
        ),
      ),
    );
    await tester.tap(find.text('open'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 1000));
    await tester.pump();
    expect(find.byType(JamResultScreen), findsOneWidget);

    await tester.fling(find.byType(ListView), const Offset(0, -2000), 3000, warnIfMissed: false);
    await tester.pump();
    await tester.tap(find.text('Back to Topics'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 1000));
    await tester.pump();
    await tester.pump();

    expect(find.byType(JamResultScreen), findsNothing);
    expect(find.text('open'), findsOneWidget);
  });
}
