import 'package:career_buddy_lms/app/router/route_paths.dart';
import 'package:career_buddy_lms/core/utils/result.dart';
import 'package:career_buddy_lms/features/activities/domain/entities/mcq_exercise.dart';
import 'package:career_buddy_lms/features/activities/domain/entities/mcq_question.dart';
import 'package:career_buddy_lms/features/activities/domain/repositories/mcq_exercise_repository.dart';
import 'package:career_buddy_lms/features/activities/presentation/providers/activities_providers.dart';
import 'package:career_buddy_lms/features/activities/presentation/screens/mcq_exercise_screen.dart';
import 'package:career_buddy_lms/features/ai_listening/domain/entities/listening_analysis_result.dart';
import 'package:career_buddy_lms/features/ai_listening/domain/repositories/ai_listening_repository.dart';
import 'package:career_buddy_lms/features/ai_listening/presentation/ai_listening_route_args.dart';
import 'package:career_buddy_lms/features/ai_listening/presentation/providers/ai_listening_providers.dart';
import 'package:career_buddy_lms/features/ai_listening/presentation/screens/ai_listening_screen.dart';
import 'package:career_buddy_lms/features/ai_reading/presentation/ai_reading_route_args.dart';
import 'package:career_buddy_lms/features/ai_reading/presentation/screens/ai_reading_screen.dart';
import 'package:career_buddy_lms/features/ai_speaking/presentation/ai_speaking_route_args.dart';
import 'package:career_buddy_lms/features/ai_speaking/presentation/screens/ai_speaking_screen.dart';
import 'package:career_buddy_lms/features/ai_writing/presentation/ai_writing_route_args.dart';
import 'package:career_buddy_lms/features/ai_writing/presentation/screens/ai_writing_screen.dart';
import 'package:career_buddy_lms/features/auth/domain/entities/auth_user.dart';
import 'package:career_buddy_lms/features/auth/domain/repositories/auth_repository.dart';
import 'package:career_buddy_lms/features/auth/domain/entities/student_registration_data.dart';
import 'package:career_buddy_lms/features/auth/presentation/providers/auth_providers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

/// W017's new route (`/activities/exercise/:id/reading`,
/// `RoutePaths.aiReadingPattern`) has two path segments after
/// `/activities/exercise/`, one more than `mcqExercisePattern`
/// (`/activities/exercise/:id`) — the same collision-safety reasoning
/// already verified for `aiSpeakingPattern`/`aiWritingPattern`/
/// `aiListeningPattern`. This also confirms all four AI-module routes
/// coexist without collision.
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

/// `AiListeningScreen` fetches an `attempt_token` immediately on build
/// (unlike Speaking/Writing/Reading, which start ready synchronously) —
/// this override lets the `.../listening` route build without hitting the
/// real network/platform-channel-backed `ApiClient` in a plain
/// `flutter_test` environment.
class _FakeAiListeningRepository implements AiListeningRepository {
  @override
  Future<Result<String>> fetchAttemptToken(int exerciseId) async => const Success('tok-1');

  @override
  Future<Result<ListeningAnalysisResult>> analyze({
    required int exerciseId,
    required String text,
    required String referenceText,
    required int durationSeconds,
    required int pauseCount,
    required String attemptToken,
    required String language,
  }) async => throw UnimplementedError();
}

class _FakeMcqExerciseRepository implements McqExerciseRepository {
  @override
  Future<Result<McqExercise>> getMcqExercise(int exerciseId) async => Success(
    McqExercise(
      id: exerciseId,
      title: 'A Quiz',
      questions: const [McqQuestion(id: 1, questionText: 'Q1?', options: {'a': 'A', 'b': 'B'}, correctAnswer: 'a')],
    ),
  );

  @override
  Future<Result<McqSubmitEcho>> submitMcqExercise(
    int exerciseId, {
    required int score,
    required int maxScore,
    required Map<int, String> answers,
  }) async => throw UnimplementedError();
}

GoRouter _buildRouter(String initialLocation) {
  return GoRouter(
    initialLocation: initialLocation,
    routes: [
      // Same order as the real, fixed app_router.dart.
      GoRoute(
        path: RoutePaths.mcqExercisePattern,
        builder: (context, state) {
          final id = int.tryParse(state.pathParameters['id'] ?? '') ?? -1;
          return McqExerciseScreen(exerciseId: id);
        },
      ),
      GoRoute(
        path: RoutePaths.aiSpeakingPattern,
        builder: (context, state) {
          final id = int.tryParse(state.pathParameters['id'] ?? '') ?? -1;
          final args = state.extra;
          return AiSpeakingScreen(
            exerciseId: id,
            activityId: args is AiSpeakingRouteArgs ? args.activityId : -1,
            subActivityId: args is AiSpeakingRouteArgs ? args.subActivityId : -1,
            activityTitle: args is AiSpeakingRouteArgs ? args.activityTitle : '',
            previousAttempt: args is AiSpeakingRouteArgs ? args.previousAttempt : null,
          );
        },
      ),
      GoRoute(
        path: RoutePaths.aiWritingPattern,
        builder: (context, state) {
          final id = int.tryParse(state.pathParameters['id'] ?? '') ?? -1;
          final args = state.extra;
          return AiWritingScreen(
            exerciseId: id,
            activityId: args is AiWritingRouteArgs ? args.activityId : -1,
            subActivityId: args is AiWritingRouteArgs ? args.subActivityId : -1,
            activityTitle: args is AiWritingRouteArgs ? args.activityTitle : '',
            previousAttempt: args is AiWritingRouteArgs ? args.previousAttempt : null,
          );
        },
      ),
      GoRoute(
        path: RoutePaths.aiListeningPattern,
        builder: (context, state) {
          final id = int.tryParse(state.pathParameters['id'] ?? '') ?? -1;
          final args = state.extra;
          return AiListeningScreen(
            exerciseId: id,
            activityId: args is AiListeningRouteArgs ? args.activityId : -1,
            subActivityId: args is AiListeningRouteArgs ? args.subActivityId : -1,
            activityTitle: args is AiListeningRouteArgs ? args.activityTitle : '',
            previousAttempt: args is AiListeningRouteArgs ? args.previousAttempt : null,
          );
        },
      ),
      GoRoute(
        path: RoutePaths.aiReadingPattern,
        builder: (context, state) {
          final id = int.tryParse(state.pathParameters['id'] ?? '') ?? -1;
          final args = state.extra;
          return AiReadingScreen(
            exerciseId: id,
            activityId: args is AiReadingRouteArgs ? args.activityId : -1,
            subActivityId: args is AiReadingRouteArgs ? args.subActivityId : -1,
            activityTitle: args is AiReadingRouteArgs ? args.activityTitle : '',
            previousAttempt: args is AiReadingRouteArgs ? args.previousAttempt : null,
          );
        },
      ),
    ],
  );
}

Future<void> _pumpAt(WidgetTester tester, String location) async {
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        authRepositoryProvider.overrideWithValue(_FakeAuthRepository()),
        mcqExerciseRepositoryProvider.overrideWithValue(_FakeMcqExerciseRepository()),
        aiListeningRepositoryProvider.overrideWithValue(_FakeAiListeningRepository()),
      ],
      child: MaterialApp.router(routerConfig: _buildRouter(location)),
    ),
  );
  await tester.pump();
}

void main() {
  testWidgets('/activities/exercise/<id> still resolves to McqExerciseScreen', (tester) async {
    await _pumpAt(tester, RoutePaths.mcqExercise(5));

    expect(find.byType(McqExerciseScreen), findsOneWidget);
    expect(find.byType(AiReadingScreen), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    '/activities/exercise/<id>/reading resolves to AiReadingScreen, not McqExerciseScreen/AiSpeakingScreen/AiWritingScreen/AiListeningScreen',
    (tester) async {
      await _pumpAt(tester, RoutePaths.aiReading(5));

      expect(find.byType(AiReadingScreen), findsOneWidget);
      expect(find.byType(McqExerciseScreen), findsNothing);
      expect(find.byType(AiSpeakingScreen), findsNothing);
      expect(find.byType(AiWritingScreen), findsNothing);
      expect(find.byType(AiListeningScreen), findsNothing);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('/activities/exercise/<id>/speaking still resolves to AiSpeakingScreen, not AiReadingScreen', (
    tester,
  ) async {
    await _pumpAt(tester, RoutePaths.aiSpeaking(5));

    expect(find.byType(AiSpeakingScreen), findsOneWidget);
    expect(find.byType(AiReadingScreen), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('/activities/exercise/<id>/writing still resolves to AiWritingScreen, not AiReadingScreen', (
    tester,
  ) async {
    await _pumpAt(tester, RoutePaths.aiWriting(5));

    expect(find.byType(AiWritingScreen), findsOneWidget);
    expect(find.byType(AiReadingScreen), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('/activities/exercise/<id>/listening still resolves to AiListeningScreen, not AiReadingScreen', (
    tester,
  ) async {
    await _pumpAt(tester, RoutePaths.aiListening(5));

    expect(find.byType(AiListeningScreen), findsOneWidget);
    expect(find.byType(AiReadingScreen), findsNothing);
    expect(tester.takeException(), isNull);
  });
}
