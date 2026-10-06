import 'dart:async';

import 'package:career_buddy_lms/app/router/route_paths.dart';
import 'package:career_buddy_lms/core/errors/failures.dart';
import 'package:career_buddy_lms/core/utils/result.dart';
import 'package:career_buddy_lms/features/activities/domain/entities/activity_detail.dart';
import 'package:career_buddy_lms/features/activities/domain/entities/activity_list_data.dart';
import 'package:career_buddy_lms/features/activities/domain/entities/exercise_attempt.dart';
import 'package:career_buddy_lms/features/activities/domain/entities/exercise_summary.dart';
import 'package:career_buddy_lms/features/activities/domain/entities/sub_activity_detail.dart';
import 'package:career_buddy_lms/features/activities/domain/entities/sub_activity_status.dart';
import 'package:career_buddy_lms/features/activities/domain/entities/sub_activity_summary.dart';
import 'package:career_buddy_lms/features/activities/domain/repositories/activities_repository.dart';
import 'package:career_buddy_lms/features/activities/presentation/providers/activities_providers.dart';
import 'package:career_buddy_lms/features/activities/presentation/screens/sub_activity_detail_screen.dart';
import 'package:career_buddy_lms/features/auth/domain/entities/auth_user.dart';
import 'package:career_buddy_lms/features/auth/domain/repositories/auth_repository.dart';
import 'package:career_buddy_lms/features/auth/domain/entities/student_registration_data.dart';
import 'package:career_buddy_lms/features/auth/presentation/providers/auth_providers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

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

/// [subResult] is a fixed value shared across all `getSubActivityDetail`
/// calls — realistic enough since these tests never navigate to a second
/// sub-activity mid-test. [activityDetailResult] backs
/// `SubActivitySiblingsController` (Previous/Next + sidebar), matching the
/// web's own `activity.subactivities.all` sibling list.
class _FakeActivitiesRepository implements ActivitiesRepository {
  _FakeActivitiesRepository({
    required this.subResult,
    this.activityDetailResult,
    this.markCompleteResult,
  });

  Result<SubActivityDetail> subResult;
  Result<ActivityDetail>? activityDetailResult;
  Result<void>? markCompleteResult;
  int markCompleteCallCount = 0;
  int? lastMarkedSubActivityId;
  Completer<Result<void>>? pendingMarkComplete;

  @override
  Future<Result<SubActivityDetail>> getSubActivityDetail(int activityId, int subActivityId) async => subResult;

  @override
  Future<Result<ActivityDetail>> getActivityDetail(int id) async =>
      activityDetailResult ?? const Failed(NotFoundFailure());

  @override
  Future<Result<ActivityListData>> getActivityList({String? category}) async => throw UnimplementedError();

  @override
  Future<Result<ActivityListData>> getWorkshopModules() async => throw UnimplementedError();

  @override
  Future<Result<void>> markSubComplete(int subActivityId) async {
    markCompleteCallCount++;
    lastMarkedSubActivityId = subActivityId;
    if (pendingMarkComplete != null) return pendingMarkComplete!.future;
    return markCompleteResult ?? const Success(null);
  }
}

SubActivityDetail _detail({
  int id = 34,
  SubActivityStatus status = SubActivityStatus.inProgress,
  bool allExercisesDone = false,
  List<ExerciseSummary> exercises = const [],
  DateTime? completedAt,
  int order = 2,
  int activityId = 12,
  String activityTitle = 'Business Vocabulary Building Games',
}) => SubActivityDetail(
  id: id,
  title: 'Common Business Terms',
  description: 'An overview of common business vocabulary used in meetings.',
  instructions: 'Read through each term and its usage before starting the exercises.',
  order: order,
  activityId: activityId,
  activityTitle: activityTitle,
  status: status,
  allExercisesDone: allExercisesDone,
  exercises: exercises,
  completedAt: completedAt,
);

ExerciseSummary _exercise({
  int id = 1,
  String type = 'mcq',
  String typeDisplay = 'Multiple Choice',
  ExerciseAttempt? lastAttempt,
}) => ExerciseSummary(
  id: id,
  title: 'Vocabulary Quiz',
  exerciseType: type,
  exerciseTypeDisplay: typeDisplay,
  order: 1,
  lastAttempt: lastAttempt,
);

ActivityDetail _activityDetail(List<SubActivitySummary> subs) => ActivityDetail(
  id: 12,
  title: 'Business Vocabulary Building Games',
  description: 'd',
  category: 'vocabulary',
  categoryDisplay: 'Vocabulary & Idioms',
  level: 'Intermediate',
  duration: '30 min',
  isWorkshop: false,
  isModule: false,
  completionRate: 0,
  subActivities: subs,
);

SubActivitySummary _sibling(int id, String title, {int order = 1, SubActivityStatus status = SubActivityStatus.notStarted}) =>
    SubActivitySummary(id: id, title: title, description: 'd', order: order, status: status, exerciseCount: 1);

Future<_FakeActivitiesRepository> _pump(
  WidgetTester tester,
  Result<SubActivityDetail> subResult, {
  Result<ActivityDetail>? activityDetailResult,
  Result<void>? markCompleteResult,
}) async {
  final repo = _FakeActivitiesRepository(
    subResult: subResult,
    activityDetailResult: activityDetailResult,
    markCompleteResult: markCompleteResult,
  );
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        authRepositoryProvider.overrideWithValue(_FakeAuthRepository()),
        activitiesRepositoryProvider.overrideWithValue(repo),
      ],
      child: const MaterialApp(home: SubActivityDetailScreen(activityId: 12, subActivityId: 34)),
    ),
  );
  for (var i = 0; i < 5; i++) {
    await tester.pump();
  }
  return repo;
}

/// Wraps [SubActivityDetailScreen] in a real `GoRouter` for tests that
/// exercise actual navigation.
Future<_FakeActivitiesRepository> _pumpWithRouter(
  WidgetTester tester,
  Result<SubActivityDetail> subResult, {
  Result<ActivityDetail>? activityDetailResult,
}) async {
  final repo = _FakeActivitiesRepository(subResult: subResult, activityDetailResult: activityDetailResult);
  final router = GoRouter(
    initialLocation: RoutePaths.subActivityDetail(12, 34),
    routes: [
      GoRoute(
        path: RoutePaths.subActivityDetailPattern,
        builder: (context, state) {
          final activityId = int.tryParse(state.pathParameters['activityId'] ?? '') ?? -1;
          final subId = int.tryParse(state.pathParameters['subId'] ?? '') ?? -1;
          return SubActivityDetailScreen(activityId: activityId, subActivityId: subId);
        },
      ),
      GoRoute(
        path: RoutePaths.activityDetailPattern,
        builder: (context, state) => const Scaffold(body: Text('Activity Detail Screen')),
      ),
      GoRoute(
        path: RoutePaths.mcqExercisePattern,
        builder: (context, state) => const Scaffold(body: Text('MCQ Exercise Screen')),
      ),
      GoRoute(
        path: RoutePaths.matchingExercisePattern,
        builder: (context, state) => const Scaffold(body: Text('Matching Exercise Screen')),
      ),
      GoRoute(
        path: RoutePaths.bingoExercisePattern,
        builder: (context, state) => const Scaffold(body: Text('Bingo Exercise Screen')),
      ),
      GoRoute(
        path: RoutePaths.fillBlankExercisePattern,
        builder: (context, state) => const Scaffold(body: Text('Fill Blank Exercise Screen')),
      ),
      GoRoute(
        path: RoutePaths.genericWritingExercisePattern,
        builder: (context, state) => const Scaffold(body: Text('Generic Writing Exercise Screen')),
      ),
      GoRoute(
        path: RoutePaths.timerExercisePattern,
        builder: (context, state) => const Scaffold(body: Text('Timer Exercise Screen')),
      ),
      GoRoute(
        path: RoutePaths.aiSpeakingPattern,
        builder: (context, state) => const Scaffold(body: Text('AI Speaking Screen')),
      ),
      GoRoute(
        path: RoutePaths.aiWritingPattern,
        builder: (context, state) => const Scaffold(body: Text('AI Writing Screen')),
      ),
      GoRoute(
        path: RoutePaths.aiListeningPattern,
        builder: (context, state) => const Scaffold(body: Text('AI Listening Screen')),
      ),
      GoRoute(
        path: RoutePaths.aiReadingPattern,
        builder: (context, state) => const Scaffold(body: Text('AI Reading Screen')),
      ),
      GoRoute(path: RoutePaths.activities, builder: (context, state) => const Scaffold(body: Text('Activities'))),
      GoRoute(path: RoutePaths.pro, builder: (context, state) => const Scaffold(body: Text('Upgrade Plan Screen'))),
    ],
  );
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        authRepositoryProvider.overrideWithValue(_FakeAuthRepository()),
        activitiesRepositoryProvider.overrideWithValue(repo),
      ],
      child: MaterialApp.router(routerConfig: router),
    ),
  );
  for (var i = 0; i < 5; i++) {
    await tester.pump();
  }
  return repo;
}

void main() {
  group('rendering', () {
    testWidgets('renders title, activity title, status, overview, and instructions', (tester) async {
      await _pump(tester, Success(_detail()));

      expect(find.text('Common Business Terms'), findsOneWidget);
      expect(find.text('Business Vocabulary Building Games'), findsOneWidget);
      expect(find.text('In Progress'), findsOneWidget);
      expect(find.text('Overview'), findsOneWidget);
      expect(find.text('An overview of common business vocabulary used in meetings.'), findsOneWidget);
      expect(find.text('Instructions'), findsOneWidget);
      expect(find.text('Read through each term and its usage before starting the exercises.'), findsOneWidget);
    });

    testWidgets('shows "Sub-Activity X of Y" once siblings load, matching the web header', (tester) async {
      await _pump(
        tester,
        Success(_detail(order: 2)),
        activityDetailResult: Success(
          _activityDetail([_sibling(33, 'First'), _sibling(34, 'Second'), _sibling(35, 'Third')]),
        ),
      );
      await tester.pump();

      expect(find.text('Sub-Activity 2 of 3'), findsOneWidget);
    });

    testWidgets('an exercise card shows its type, title, last score, and percentage', (tester) async {
      await _pump(
        tester,
        Success(
          _detail(
            exercises: [
              _exercise(
                lastAttempt: ExerciseAttempt(
                  score: 8,
                  maxScore: 10,
                  percentage: 80,
                  attemptNumber: 2,
                  completedAt: DateTime(2026, 1, 1),
                ),
              ),
            ],
          ),
        ),
      );

      expect(find.text('Vocabulary Quiz'), findsOneWidget);
      expect(find.text('Multiple Choice'), findsOneWidget);
      expect(find.text('Last score: 8/10'), findsOneWidget);
      expect(find.text('80%'), findsOneWidget);
      expect(find.text('Start'), findsOneWidget);
    });

    testWidgets('a non-mcq exercise type genuinely unimplemented (e.g. Ordering) shows "Not available in the app yet." and no "Start"', (
      tester,
    ) async {
      await _pump(tester, Success(_detail(exercises: [_exercise(type: 'ordering', typeDisplay: 'Ordering')])));

      expect(find.text('Ordering'), findsOneWidget);
      expect(find.text('Not available in the app yet.'), findsOneWidget);
      expect(find.text('Start'), findsNothing);
    });

    testWidgets('a Timed Activity (timer) exercise shows "Start" — it has a working screen', (tester) async {
      await _pump(tester, Success(_detail(exercises: [_exercise(type: 'timer', typeDisplay: 'Timed Activity')])));

      expect(find.text('Timed Activity'), findsOneWidget);
      expect(find.text('Start'), findsOneWidget);
      expect(find.text('Not available in the app yet.'), findsNothing);
    });

    testWidgets('the Interactive Exercises section is entirely absent when there are no exercises', (tester) async {
      await _pump(tester, Success(_detail(exercises: const [])));

      expect(find.text('Interactive Exercises'), findsNothing);
    });

    testWidgets('shows the Learning Tips card with the web\'s exact static content', (tester) async {
      await _pump(tester, Success(_detail()));
      // Below the fold in the default test viewport — a plain ListView
      // still lazily realizes far-off children, same as elsewhere in this
      // suite (see the W002/W003/W004 overflow tests' own scroll steps).
      await tester.fling(find.byType(ListView), const Offset(0, -2000), 3000, warnIfMissed: false);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 1000));

      expect(find.text('Learning Tips'), findsOneWidget);
      expect(find.text('Read the instructions carefully before starting.'), findsOneWidget);
      expect(find.text('Complete exercises to reinforce what you learn.'), findsOneWidget);
      expect(find.text('Retry exercises to improve your score.'), findsOneWidget);
      expect(find.text('Mark complete when you feel confident.'), findsOneWidget);
    });
  });

  group('Mark Complete', () {
    testWidgets('is disabled while exercises remain incomplete, with the web\'s exact gating message', (
      tester,
    ) async {
      await _pump(tester, Success(_detail(allExercisesDone: false)));

      expect(find.text('Please complete all interactive exercises first.'), findsOneWidget);
      final button = tester.widget<ElevatedButton>(find.widgetWithText(ElevatedButton, 'Mark Complete'));
      expect(button.onPressed, isNull);
    });

    testWidgets('is enabled once all exercises are done', (tester) async {
      await _pump(tester, Success(_detail(allExercisesDone: true)));

      expect(find.text('Mark it complete to track your overall progress.'), findsOneWidget);
      final button = tester.widget<ElevatedButton>(find.widgetWithText(ElevatedButton, 'Mark Complete'));
      expect(button.onPressed, isNotNull);
    });

    testWidgets('shows a loading state while submitting and does not fire twice', (tester) async {
      final repo = await _pump(tester, Success(_detail(allExercisesDone: true)));
      repo.pendingMarkComplete = Completer<Result<void>>();

      await tester.tap(find.text('Mark Complete'));
      await tester.pump();

      expect(find.text('Mark Complete'), findsNothing); // replaced by a spinner
      expect(find.byType(CircularProgressIndicator), findsWidgets);

      repo.pendingMarkComplete!.complete(const Success(null));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));
    });

    testWidgets(
      'on success, does not claim completion itself — it refetches, and the completed UI only '
      'appears once the server confirms it',
      (tester) async {
        final repo = await _pump(tester, Success(_detail(allExercisesDone: true)));
        // The refetch after a successful submit returns the *new* server
        // truth — this is what proves the screen isn't guessing.
        repo.subResult = Success(
          _detail(allExercisesDone: true, status: SubActivityStatus.completed, completedAt: DateTime(2026, 1, 15)),
        );

        await tester.tap(find.text('Mark Complete'));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 400));

        expect(find.textContaining('Sub-activity completed on January 15, 2026!'), findsOneWidget);
        expect(find.text('Mark Complete'), findsNothing);
      },
    );

    testWidgets('on failure, shows the error and does NOT show the completed state', (tester) async {
      const failure = ServerFailure();
      await _pump(tester, Success(_detail(allExercisesDone: true)), markCompleteResult: const Failed(failure));

      await tester.tap(find.text('Mark Complete'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));

      expect(find.text(failure.message), findsOneWidget);
      expect(find.textContaining('Sub-activity completed on'), findsNothing);
      // Still offered a way to retry — the button is back, not stuck loading.
      expect(find.text('Mark Complete'), findsOneWidget);
    });

    testWidgets('an already-completed sub-activity shows the banner and no Mark Complete card at all', (
      tester,
    ) async {
      await _pump(
        tester,
        Success(_detail(status: SubActivityStatus.completed, completedAt: DateTime(2026, 3, 1))),
      );

      expect(find.textContaining('Sub-activity completed on March 1, 2026!'), findsOneWidget);
      expect(find.text('Mark Complete'), findsNothing);
      expect(find.text('Finished this sub-activity?'), findsNothing);
    });
  });

  group('navigation', () {
    testWidgets('tapping an mcq exercise navigates to the existing MCQ exercise screen', (tester) async {
      await _pumpWithRouter(tester, Success(_detail(exercises: [_exercise()])));

      await tester.tap(find.text('Vocabulary Quiz'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));

      expect(find.text('MCQ Exercise Screen'), findsOneWidget);
    });

    testWidgets('W008 — tapping a matching exercise navigates to the Matching exercise screen', (tester) async {
      await _pumpWithRouter(
        tester,
        Success(_detail(exercises: [_exercise(type: 'matching', typeDisplay: 'Matching')])),
      );

      await tester.tap(find.text('Vocabulary Quiz'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));

      expect(find.text('Matching Exercise Screen'), findsOneWidget);
    });

    testWidgets('W009 — tapping a bingo exercise navigates to the Bingo exercise screen', (tester) async {
      await _pumpWithRouter(tester, Success(_detail(exercises: [_exercise(type: 'bingo', typeDisplay: 'Vocabulary Bingo')])));

      await tester.tap(find.text('Vocabulary Quiz'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));

      expect(find.text('Bingo Exercise Screen'), findsOneWidget);
    });

    testWidgets('W010 — tapping a fill_blank exercise navigates to the Fill Blank exercise screen', (tester) async {
      await _pumpWithRouter(
        tester,
        Success(_detail(exercises: [_exercise(type: 'fill_blank', typeDisplay: 'Fill in the Blank')])),
      );

      await tester.tap(find.text('Vocabulary Quiz'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));

      expect(find.text('Fill Blank Exercise Screen'), findsOneWidget);
    });

    testWidgets(
      'W013 — tapping a writing exercise under an ordinary (non-module) Activity navigates to the Generic Writing screen',
      (tester) async {
        await _pumpWithRouter(
          tester,
          Success(_detail(exercises: [_exercise(type: 'writing', typeDisplay: 'Writing Submission')])),
        );

        await tester.tap(find.text('Vocabulary Quiz'));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 400));

        expect(find.text('Generic Writing Exercise Screen'), findsOneWidget);
      },
    );

    testWidgets(
      'tapping a non-mcq exercise type genuinely unimplemented (e.g. Ordering) shows an honest "not available" '
      'explanation — never a fake exercise',
      (tester) async {
        await _pumpWithRouter(tester, Success(_detail(exercises: [_exercise(type: 'ordering', typeDisplay: 'Ordering')])));

        await tester.tap(find.text('Ordering').first);
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 400));

        // The placeholder's own title (AppBar) and message, not a real
        // question/answer UI.
        expect(find.text('Ordering'), findsWidgets);
        expect(
          find.text('Ordering exercises aren\'t available in the app yet. Please practice this exercise on the Career Buddy website for now.'),
          findsOneWidget,
        );
        // Never anything resembling a real exercise-taking screen.
        expect(find.byType(TextField), findsNothing);
        expect(find.text('Submit'), findsNothing);
        expect(find.text('Check'), findsNothing);
      },
    );

    testWidgets(
      'tapping a Timed Activity (timer) exercise under an ordinary (non-module) Activity navigates to the Timer screen',
      (tester) async {
        await _pumpWithRouter(
          tester,
          Success(_detail(exercises: [_exercise(type: 'timer', typeDisplay: 'Timed Activity')])),
        );

        await tester.tap(find.text('Vocabulary Quiz'));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 400));

        expect(find.text('Timer Exercise Screen'), findsOneWidget);
      },
    );

    testWidgets(
      'W014 — tapping an exercise under a Speaking-module Activity navigates to the AI Speaking screen, '
      'even though its own exercise_type is not mcq',
      (tester) async {
        await _pumpWithRouter(
          tester,
          Success(
            _detail(
              activityTitle: 'Professional Speaking Skills',
              exercises: [_exercise(type: 'speaking', typeDisplay: 'Speaking Practice')],
            ),
          ),
        );

        await tester.tap(find.text('Vocabulary Quiz'));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 400));

        expect(find.text('AI Speaking Screen'), findsOneWidget);
      },
    );

    testWidgets(
      'W015 — tapping an exercise under a Writing-module Activity navigates to the AI Writing screen, '
      'even though its own exercise_type is not mcq',
      (tester) async {
        await _pumpWithRouter(
          tester,
          Success(
            _detail(
              activityTitle: 'Professional Passage Writing',
              exercises: [_exercise(type: 'writing', typeDisplay: 'Writing Practice')],
            ),
          ),
        );

        await tester.tap(find.text('Vocabulary Quiz'));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 400));

        expect(find.text('AI Writing Screen'), findsOneWidget);
      },
    );

    testWidgets(
      'W016 — tapping an exercise under a Listening-module Activity navigates to the AI Listening screen, '
      'even though its own exercise_type is not mcq, and even though the title has no "professional" keyword',
      (tester) async {
        await _pumpWithRouter(
          tester,
          Success(
            _detail(
              activityTitle: 'Listen & Write',
              exercises: [_exercise(type: 'listening', typeDisplay: 'Listening Practice')],
            ),
          ),
        );

        await tester.tap(find.text('Vocabulary Quiz'));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 400));

        expect(find.text('AI Listening Screen'), findsOneWidget);
      },
    );

    testWidgets(
      'W017 — tapping an exercise under a Reading-module Activity navigates to the AI Reading screen, '
      'even though its own exercise_type is not mcq',
      (tester) async {
        await _pumpWithRouter(
          tester,
          Success(
            _detail(
              activityTitle: 'Professional Reading',
              exercises: [_exercise(type: 'reading', typeDisplay: 'Reading Practice')],
            ),
          ),
        );

        await tester.tap(find.text('Vocabulary Quiz'));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 400));

        expect(find.text('AI Reading Screen'), findsOneWidget);
      },
    );

    testWidgets('Previous/Next navigate to sibling sub-activities when they exist', (tester) async {
      await _pump(
        tester,
        Success(_detail(order: 2)),
        activityDetailResult: Success(
          _activityDetail([_sibling(33, 'First Sub'), _sibling(34, 'Second Sub', order: 2), _sibling(35, 'Third Sub', order: 3)]),
        ),
      );
      await tester.pump();

      expect(find.textContaining('First Sub'), findsWidgets);
      expect(find.textContaining('Third Sub'), findsWidgets);
    });

    testWidgets('at the first sub-activity, Previous falls back to "Back to Activity"', (tester) async {
      await _pumpWithRouter(
        tester,
        Success(_detail(order: 1)),
        activityDetailResult: Success(_activityDetail([_sibling(34, 'Second Sub', order: 1), _sibling(35, 'Third Sub', order: 2)])),
      );
      await tester.pump();

      expect(find.text('Back to Activity'), findsOneWidget);
      await tester.tap(find.text('Back to Activity'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));

      expect(find.text('Activity Detail Screen'), findsOneWidget);
    });

    testWidgets('at the last sub-activity, Next falls back to a distinct "Finish Activity"', (tester) async {
      await _pumpWithRouter(
        tester,
        Success(_detail(order: 2)),
        activityDetailResult: Success(_activityDetail([_sibling(33, 'First Sub', order: 1), _sibling(34, 'Second Sub', order: 2)])),
      );
      await tester.pump();

      expect(find.text('Finish Activity'), findsOneWidget);
      await tester.tap(find.text('Finish Activity'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));

      expect(find.text('Activity Detail Screen'), findsOneWidget);
    });

    testWidgets('locked (ForbiddenFailure) shows View Plans / Back to Activities, matching Activity Detail\'s pattern', (
      tester,
    ) async {
      await _pumpWithRouter(tester, const Failed(ForbiddenFailure()));

      expect(find.text('View Plans'), findsOneWidget);
      expect(find.text('Back to Activities'), findsOneWidget);

      await tester.tap(find.text('Back to Activities'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));

      expect(find.text('Activities'), findsOneWidget);
    });
  });

  group('loading, error, and retry', () {
    testWidgets('shows a retryable error for a non-auth failure', (tester) async {
      await _pump(tester, const Failed(NotFoundFailure()));

      expect(find.text(const NotFoundFailure().message), findsOneWidget);
      expect(find.text('Retry'), findsOneWidget);
    });
  });

  testWidgets('renders a rich sub-activity with long titles without overflow at 320px and 360px', (tester) async {
    for (final width in [320.0, 360.0]) {
      tester.view.physicalSize = Size(width, 700);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await _pump(
        tester,
        Success(
          SubActivityDetail(
            id: 34,
            title: 'A Genuinely Very Long Sub-Activity Title That Could Wrap Onto Several Lines',
            description: 'An overview of common business vocabulary used in meetings.',
            instructions: 'Read through each term and its usage before starting the exercises.',
            order: 2,
            activityId: 12,
            activityTitle: 'A Very Long Parent Activity Title That Could Also Wrap Across Multiple Lines Easily',
            status: SubActivityStatus.inProgress,
            allExercisesDone: false,
            exercises: [
              _exercise(),
              _exercise(id: 2, type: 'fill_blank', typeDisplay: 'Fill in the Blank'),
            ],
          ),
        ),
        activityDetailResult: Success(
          _activityDetail([
            _sibling(33, 'A Very Long Previous Sub-Activity Title That Gets Truncated', order: 1),
            _sibling(34, 'Current', order: 2),
            _sibling(35, 'A Very Long Next Sub-Activity Title That Gets Truncated', order: 3),
          ]),
        ),
      );
      await tester.pump();

      expect(tester.takeException(), isNull);
    }
  });
}
