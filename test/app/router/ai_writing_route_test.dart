import 'package:career_buddy_lms/app/router/route_paths.dart';
import 'package:career_buddy_lms/core/utils/result.dart';
import 'package:career_buddy_lms/features/activities/domain/entities/mcq_exercise.dart';
import 'package:career_buddy_lms/features/activities/domain/entities/mcq_question.dart';
import 'package:career_buddy_lms/features/activities/domain/repositories/mcq_exercise_repository.dart';
import 'package:career_buddy_lms/features/activities/presentation/providers/activities_providers.dart';
import 'package:career_buddy_lms/features/activities/presentation/screens/mcq_exercise_screen.dart';
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

/// W015's new route (`/activities/exercise/:id/writing`,
/// `RoutePaths.aiWritingPattern`) has two path segments after
/// `/activities/exercise/`, one more than `mcqExercisePattern`
/// (`/activities/exercise/:id`) — so it cannot be matched by the wrong
/// route regardless of declaration order, the same reasoning already
/// verified for `aiSpeakingPattern` in `ai_speaking_route_test.dart`. This
/// also confirms `aiWritingPattern` and `aiSpeakingPattern` — two
/// structurally identical patterns differing only in their final segment
/// — don't collide with each other either.
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
    ],
  );
}

Future<void> _pumpAt(WidgetTester tester, String location) async {
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        authRepositoryProvider.overrideWithValue(_FakeAuthRepository()),
        mcqExerciseRepositoryProvider.overrideWithValue(_FakeMcqExerciseRepository()),
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
    expect(find.byType(AiWritingScreen), findsNothing);
    expect(find.byType(AiSpeakingScreen), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('/activities/exercise/<id>/writing resolves to AiWritingScreen, not McqExerciseScreen or AiSpeakingScreen', (
    tester,
  ) async {
    await _pumpAt(tester, RoutePaths.aiWriting(5));

    expect(find.byType(AiWritingScreen), findsOneWidget);
    expect(find.byType(McqExerciseScreen), findsNothing);
    expect(find.byType(AiSpeakingScreen), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('/activities/exercise/<id>/speaking still resolves to AiSpeakingScreen, not AiWritingScreen', (
    tester,
  ) async {
    await _pumpAt(tester, RoutePaths.aiSpeaking(5));

    expect(find.byType(AiSpeakingScreen), findsOneWidget);
    expect(find.byType(AiWritingScreen), findsNothing);
    expect(tester.takeException(), isNull);
  });
}
