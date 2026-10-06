import 'package:career_buddy_lms/app/router/route_paths.dart';
import 'package:career_buddy_lms/core/errors/failures.dart';
import 'package:career_buddy_lms/core/utils/result.dart';
import 'package:career_buddy_lms/features/activities/domain/entities/activity_detail.dart';
import 'package:career_buddy_lms/features/activities/domain/entities/activity_list_data.dart';
import 'package:career_buddy_lms/features/activities/domain/entities/activity_summary.dart';
import 'package:career_buddy_lms/features/activities/domain/entities/sub_activity_detail.dart';
import 'package:career_buddy_lms/features/activities/domain/entities/sub_activity_status.dart';
import 'package:career_buddy_lms/features/activities/domain/entities/sub_activity_summary.dart';
import 'package:career_buddy_lms/features/activities/domain/repositories/activities_repository.dart';
import 'package:career_buddy_lms/features/activities/presentation/providers/activities_providers.dart';
import 'package:career_buddy_lms/features/activities/presentation/screens/activity_detail_screen.dart';
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

class _FakeActivitiesRepository implements ActivitiesRepository {
  _FakeActivitiesRepository(this.detailResult, {this.listResult});
  final Result<ActivityDetail> detailResult;

  /// Backs the Previous/Next feature (`AdjacentActivitiesController`),
  /// which calls the same `getActivityList()` the Activities List screen
  /// uses. Defaults to a failure the controller swallows gracefully, so
  /// tests that don't care about Previous/Next don't need to supply one.
  final Result<ActivityListData>? listResult;

  @override
  Future<Result<ActivityDetail>> getActivityDetail(int id) async {
    // Echoes back the requested id, matching the real API (which always
    // returns the entity for the id actually asked for) — needed so
    // Previous/Next navigation tests, which load a second id after
    // tapping, don't keep resolving to the first screen's fixed payload.
    final result = detailResult;
    if (result is Success<ActivityDetail>) {
      final d = result.value;
      return Success(
        ActivityDetail(
          id: id,
          title: d.title,
          description: d.description,
          category: d.category,
          categoryDisplay: d.categoryDisplay,
          level: d.level,
          duration: d.duration,
          isWorkshop: d.isWorkshop,
          isModule: d.isModule,
          completionRate: d.completionRate,
          subActivities: d.subActivities,
        ),
      );
    }
    return result;
  }

  @override
  Future<Result<ActivityListData>> getActivityList({String? category}) async =>
      listResult ?? const Failed(NotFoundFailure());

  @override
  Future<Result<ActivityListData>> getWorkshopModules() async => throw UnimplementedError();

  @override
  Future<Result<SubActivityDetail>> getSubActivityDetail(int activityId, int subActivityId) async => throw UnimplementedError();

  @override
  Future<Result<void>> markSubComplete(int subActivityId) async => throw UnimplementedError();
}

ActivitySummary _listActivity(int id, String title) => ActivitySummary(
  id: id,
  title: title,
  description: 'desc',
  category: 'vocabulary',
  categoryDisplay: 'Vocabulary & Idioms',
  level: 'Intermediate',
  duration: '30 min',
  isLocked: false,
  completionRate: 0,
  isCompleted: false,
);

Future<void> _pump(
  WidgetTester tester,
  Result<ActivityDetail> result, {
  Result<ActivityListData>? listResult,
}) async {
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        authRepositoryProvider.overrideWithValue(_FakeAuthRepository()),
        activitiesRepositoryProvider.overrideWithValue(_FakeActivitiesRepository(result, listResult: listResult)),
      ],
      child: const MaterialApp(home: ActivityDetailScreen(activityId: 12)),
    ),
  );
  for (var i = 0; i < 5; i++) {
    await tester.pump();
  }
}

/// Wraps [ActivityDetailScreen] in a real `GoRouter` for tests that
/// exercise actual navigation (Previous/Next, locked-state buttons).
Future<void> _pumpWithRouter(
  WidgetTester tester,
  Result<ActivityDetail> result, {
  Result<ActivityListData>? listResult,
}) async {
  final router = GoRouter(
    initialLocation: RoutePaths.activityDetail(12),
    routes: [
      GoRoute(
        path: RoutePaths.activityDetailPattern,
        builder: (context, state) {
          final id = int.tryParse(state.pathParameters['id'] ?? '') ?? -1;
          return ActivityDetailScreen(activityId: id);
        },
      ),
      GoRoute(path: RoutePaths.activities, builder: (context, state) => const Scaffold(body: Text('Activities'))),
      GoRoute(path: RoutePaths.pro, builder: (context, state) => const Scaffold(body: Text('Upgrade Plan Screen'))),
    ],
  );
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        authRepositoryProvider.overrideWithValue(_FakeAuthRepository()),
        activitiesRepositoryProvider.overrideWithValue(
          _FakeActivitiesRepository(result, listResult: listResult),
        ),
      ],
      child: MaterialApp.router(routerConfig: router),
    ),
  );
  for (var i = 0; i < 5; i++) {
    await tester.pump();
  }
}

void main() {
  testWidgets('renders activity title, description, and sub-activities on success', (tester) async {
    await _pump(
      tester,
      Success(
        const ActivityDetail(
          id: 12,
          title: 'Business Vocabulary Building Games',
          description: 'Learn essential business vocabulary.',
          category: 'vocabulary',
          categoryDisplay: 'Vocabulary & Idioms',
          level: 'Intermediate',
          duration: '30 min',
          isWorkshop: false,
          isModule: false,
          completionRate: 40,
          subActivities: [],
        ),
      ),
    );

    expect(find.text('Business Vocabulary Building Games'), findsOneWidget);
    expect(find.text('No sub-activities yet.'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('shows a locked message (not a generic error) for a ForbiddenFailure', (tester) async {
    const failure = ForbiddenFailure();
    await _pump(tester, const Failed(failure));

    expect(find.text(failure.message), findsOneWidget);
    expect(find.byIcon(Icons.lock_outline), findsOneWidget);
    // The locked state has no Retry button — retrying a plan restriction
    // makes no sense without upgrading, so this isn't offered here.
    expect(find.text('Retry'), findsNothing);
  });

  testWidgets('shows a retryable error view for a not-found failure', (tester) async {
    await _pump(tester, const Failed(NotFoundFailure()));

    expect(find.text(const NotFoundFailure().message), findsOneWidget);
    expect(find.text('Retry'), findsOneWidget);
  });

  testWidgets('renders metadata and progress exactly as the web hero does', (tester) async {
    await _pump(
      tester,
      Success(
        const ActivityDetail(
          id: 12,
          title: 'Business Vocabulary Building Games',
          description: 'Learn essential business vocabulary.',
          category: 'vocabulary',
          categoryDisplay: 'Vocabulary & Idioms',
          level: 'Intermediate',
          duration: '30 min',
          isWorkshop: false,
          isModule: false,
          completionRate: 40,
          subActivities: [],
        ),
      ),
    );

    expect(find.text('Intermediate'), findsOneWidget);
    expect(find.text('30 min'), findsOneWidget);
    expect(find.text('0 Sub-Activities'), findsOneWidget);
    // `.ring-value`/`.ring-label` (`style.css:1543-1544`) are two separate
    // text elements, not one combined string.
    expect(find.text('40%'), findsOneWidget);
    expect(find.text('Complete'), findsOneWidget);
  });

  testWidgets('the hero banner is a navy gradient, matching .activity-hero — color_class is not invented', (
    tester,
  ) async {
    await _pump(
      tester,
      Success(
        const ActivityDetail(
          id: 12,
          title: 'Business Vocabulary Building Games',
          description: 'Learn essential business vocabulary.',
          category: 'vocabulary',
          categoryDisplay: 'Vocabulary & Idioms',
          level: 'Intermediate',
          duration: '30 min',
          isWorkshop: false,
          isModule: false,
          completionRate: 40,
          subActivities: [],
        ),
      ),
    );

    final gradientContainer = tester
        .widgetList<Container>(find.byType(Container))
        .firstWhere((c) => (c.decoration as BoxDecoration?)?.gradient != null);
    final gradient = (gradientContainer.decoration! as BoxDecoration).gradient! as LinearGradient;
    expect(gradient.colors, [const Color(0xFF14213D), const Color(0xFF0B1526)]);
  });

  testWidgets('renders the static Assessment card exactly as the web template has it', (tester) async {
    await _pump(
      tester,
      Success(
        const ActivityDetail(
          id: 12,
          title: 'Business Vocabulary Building Games',
          description: 'Learn essential business vocabulary.',
          category: 'vocabulary',
          categoryDisplay: 'Vocabulary & Idioms',
          level: 'Intermediate',
          duration: '30 min',
          isWorkshop: false,
          isModule: false,
          completionRate: 0,
          subActivities: [],
        ),
      ),
    );

    expect(find.text('Assessment'), findsOneWidget);
    expect(find.text('Peer evaluation rubrics'), findsOneWidget);
    expect(find.text('Instructor observation'), findsOneWidget);
    expect(find.text('Interactive exercises'), findsOneWidget);
    expect(find.text('Self-reflection'), findsOneWidget);
  });

  group('sub-activity cards', () {
    ActivityDetail detailWith(List<SubActivitySummary> subs) => ActivityDetail(
      id: 12,
      title: 'Business Vocabulary Building Games',
      description: 'Learn essential business vocabulary.',
      category: 'vocabulary',
      categoryDisplay: 'Vocabulary & Idioms',
      level: 'Intermediate',
      duration: '30 min',
      isWorkshop: false,
      isModule: false,
      completionRate: 0,
      subActivities: subs,
    );

    testWidgets('a not-started sub-activity shows its number, "Not Started", exercise count, and "Start"', (
      tester,
    ) async {
      await _pump(
        tester,
        Success(
          detailWith(const [
            SubActivitySummary(
              id: 1,
              title: 'Greetings & Introductions',
              description: 'Learn how to greet colleagues professionally.',
              order: 1,
              status: SubActivityStatus.notStarted,
              exerciseCount: 3,
            ),
          ]),
        ),
      );

      expect(find.text('Greetings & Introductions'), findsOneWidget);
      expect(find.text('Learn how to greet colleagues professionally.'), findsOneWidget);
      expect(find.text('Not Started'), findsOneWidget);
      expect(find.text('3 Exercises'), findsOneWidget);
      expect(find.text('Start'), findsOneWidget);
      expect(find.text('1'), findsOneWidget); // the number badge
    });

    testWidgets('an in-progress sub-activity shows "In Progress", "Continue", and its Started timestamp', (
      tester,
    ) async {
      await _pump(
        tester,
        Success(
          detailWith([
            SubActivitySummary(
              id: 1,
              title: 'Greetings & Introductions',
              description: 'Learn how to greet colleagues professionally.',
              order: 1,
              status: SubActivityStatus.inProgress,
              exerciseCount: 1,
              startedAt: DateTime(2026, 1, 15, 14, 30),
            ),
          ]),
        ),
      );

      expect(find.text('In Progress'), findsOneWidget);
      expect(find.text('Continue'), findsOneWidget);
      expect(find.text('Started Jan 15 2026 02:30 PM'), findsOneWidget);
    });

    testWidgets(
      'a completed sub-activity shows a checkmark badge (not a number), "Completed", "Review", '
      'and its Completed timestamp',
      (tester) async {
        await _pump(
          tester,
          Success(
            detailWith([
              SubActivitySummary(
                id: 1,
                title: 'Greetings & Introductions',
                description: 'Learn how to greet colleagues professionally.',
                order: 1,
                status: SubActivityStatus.completed,
                exerciseCount: 1,
                startedAt: DateTime(2026, 1, 15, 14, 30),
                completedAt: DateTime(2026, 1, 15, 15, 0),
              ),
            ]),
          ),
        );

        expect(find.text('Completed'), findsOneWidget); // the status badge
        expect(find.text('Review'), findsOneWidget);
        expect(find.text('Completed Jan 15 2026 03:00 PM'), findsOneWidget);
        expect(find.text('1'), findsNothing); // replaced by a checkmark icon, matching the web
        expect(find.byIcon(Icons.check), findsOneWidget);
      },
    );

    testWidgets('numbers cards by position, matching the web\'s forloop.counter', (tester) async {
      await _pump(
        tester,
        Success(
          detailWith(const [
            SubActivitySummary(
              id: 1,
              title: 'First',
              description: 'd',
              order: 1,
              status: SubActivityStatus.notStarted,
              exerciseCount: 1,
            ),
            SubActivitySummary(
              id: 2,
              title: 'Second',
              description: 'd',
              order: 2,
              status: SubActivityStatus.notStarted,
              exerciseCount: 1,
            ),
          ]),
        ),
      );

      expect(find.text('1'), findsOneWidget);
      expect(find.text('2'), findsOneWidget);
    });

    testWidgets('tapping a sub-activity navigates to its Sub-Activity Detail screen', (tester) async {
      final router = GoRouter(
        initialLocation: RoutePaths.activityDetail(12),
        routes: [
          GoRoute(
            path: RoutePaths.activityDetailPattern,
            builder: (context, state) => const ActivityDetailScreen(activityId: 12),
          ),
          GoRoute(
            path: RoutePaths.subActivityDetailPattern,
            builder: (context, state) => const Scaffold(body: Text('Sub-Activity Detail Screen')),
          ),
        ],
      );
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            authRepositoryProvider.overrideWithValue(_FakeAuthRepository()),
            activitiesRepositoryProvider.overrideWithValue(
              _FakeActivitiesRepository(
                Success(
                  detailWith(const [
                    SubActivitySummary(
                      id: 7,
                      title: 'Greetings & Introductions',
                      description: 'd',
                      order: 1,
                      status: SubActivityStatus.notStarted,
                      exerciseCount: 1,
                    ),
                  ]),
                ),
              ),
            ),
          ],
          child: MaterialApp.router(routerConfig: router),
        ),
      );
      for (var i = 0; i < 5; i++) {
        await tester.pump();
      }

      await tester.tap(find.text('Greetings & Introductions'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));

      expect(find.text('Sub-Activity Detail Screen'), findsOneWidget);
    });
  });

  group('W014 — AI module banner', () {
    const notAvailableText = 'This activity uses a guided AI module. It isn\'t available in the app yet.';

    testWidgets(
      'W017 note: Speaking/Writing/Listening/Reading are now all implemented, so every real '
      'get_module_template() branch is covered — this defensive case proves the banner still shows for '
      'a hypothetical future AI module whose title matches none of the four known detectors',
      (tester) async {
        await _pump(
          tester,
          Success(
            const ActivityDetail(
              id: 12,
              title: 'Professional Vocabulary Drills',
              description: 'd',
              category: 'vocabulary',
              categoryDisplay: 'Vocabulary',
              level: 'Beginner',
              duration: '20 min',
              isWorkshop: false,
              isModule: true,
              completionRate: 0,
              subActivities: [],
            ),
          ),
        );

        expect(find.text(notAvailableText), findsOneWidget);
      },
    );

    testWidgets(
      'the Speaking AI module (title matches isSpeakingModuleActivity) does NOT show the "not available" banner, '
      'since W014 made it real — and its sub-activities remain tappable',
      (tester) async {
        await _pump(
          tester,
          Success(
            const ActivityDetail(
              id: 12,
              title: 'Professional Speaking',
              description: 'd',
              category: 'speaking',
              categoryDisplay: 'Speaking',
              level: 'Intermediate',
              duration: '60 min',
              isWorkshop: false,
              isModule: true,
              completionRate: 0,
              subActivities: [
                SubActivitySummary(
                  id: 99,
                  title: 'AI-Powered Practice',
                  description: 'd',
                  order: 1,
                  status: SubActivityStatus.notStarted,
                  exerciseCount: 1,
                ),
              ],
            ),
          ),
        );

        expect(find.text(notAvailableText), findsNothing);
        // The sub-activity card is still a real, tappable entry point —
        // this banner was the only thing standing between the user and the
        // (already working) exercise below it.
        expect(find.text('AI-Powered Practice'), findsOneWidget);
        expect(find.text('Start'), findsOneWidget);
      },
    );

    testWidgets(
      'W016 — the Listening AI module (title matches isListeningModuleActivity, no "professional" keyword) does NOT '
      'show the "not available" banner',
      (tester) async {
        await _pump(
          tester,
          Success(
            const ActivityDetail(
              id: 12,
              title: 'Listen & Write',
              description: 'd',
              category: 'listening',
              categoryDisplay: 'Listening',
              level: 'Intermediate',
              duration: '30 min',
              isWorkshop: false,
              isModule: true,
              completionRate: 0,
              subActivities: [
                SubActivitySummary(
                  id: 99,
                  title: 'AI-Powered Practice',
                  description: 'd',
                  order: 1,
                  status: SubActivityStatus.notStarted,
                  exerciseCount: 1,
                ),
              ],
            ),
          ),
        );

        expect(find.text(notAvailableText), findsNothing);
        expect(find.text('AI-Powered Practice'), findsOneWidget);
        expect(find.text('Start'), findsOneWidget);
      },
    );

    testWidgets(
      'W017 — the Reading AI module (title matches isReadingModuleActivity) does NOT show the "not available" banner',
      (tester) async {
        await _pump(
          tester,
          Success(
            const ActivityDetail(
              id: 12,
              title: 'Professional Reading',
              description: 'd',
              category: 'reading',
              categoryDisplay: 'Reading',
              level: 'Beginner',
              duration: '20 min',
              isWorkshop: false,
              isModule: true,
              completionRate: 0,
              subActivities: [
                SubActivitySummary(
                  id: 99,
                  title: 'AI-Powered Practice',
                  description: 'd',
                  order: 1,
                  status: SubActivityStatus.notStarted,
                  exerciseCount: 1,
                ),
              ],
            ),
          ),
        );

        expect(find.text(notAvailableText), findsNothing);
        expect(find.text('AI-Powered Practice'), findsOneWidget);
        expect(find.text('Start'), findsOneWidget);
      },
    );

    testWidgets(
      'a hypothetical future workshop type (matching none of the 3 known detectors) still shows the "not available" banner',
      (tester) async {
        // Batch 9 implemented all 3 real workshop types (Roleplay/JAM/GD),
        // so there is no genuinely-still-unimplemented real workshop title
        // left to test against — this proves the fallback banner still
        // covers whatever a future 4th workshop type would be, the same
        // defensive-coverage reasoning already used for the AI-module
        // banner's own "hypothetical future module" case above.
        await _pump(
          tester,
          Success(
            const ActivityDetail(
              id: 12,
              title: 'Hypothetical Future Workshop',
              description: 'd',
              category: 'workshop',
              categoryDisplay: 'Interactive Workshop',
              level: 'Intermediate',
              duration: '30 min',
              isWorkshop: true,
              isModule: false,
              completionRate: 0,
              subActivities: [],
            ),
          ),
        );

        expect(find.text('This is an interactive workshop activity. It isn\'t available in the app yet.'), findsOneWidget);
        expect(find.text(notAvailableText), findsNothing);
      },
    );

    testWidgets(
      'Batch 9 — a Group Discussion workshop activity (title matches isGdModuleActivity) shows a Start Group Discussion CTA instead of the "not available" banner',
      (tester) async {
        await _pump(
          tester,
          Success(
            const ActivityDetail(
              id: 12,
              title: 'Group Discussion',
              description: 'd',
              category: 'workshop',
              categoryDisplay: 'Interactive Workshop',
              level: 'Intermediate',
              duration: '30 min',
              isWorkshop: true,
              isModule: false,
              completionRate: 0,
              subActivities: [],
            ),
          ),
        );

        expect(
          find.text('This is an interactive workshop activity. It isn\'t available in the app yet.'),
          findsNothing,
        );
        expect(find.text('Start Group Discussion'), findsOneWidget);
      },
    );

    testWidgets(
      'Batch 8 — a Roleplay workshop activity (title matches isRoleplayModuleActivity) shows a Start Roleplay Practice CTA instead of the "not available" banner',
      (tester) async {
        await _pump(
          tester,
          Success(
            const ActivityDetail(
              id: 12,
              title: 'Role Play Workshop',
              description: 'd',
              category: 'workshop',
              categoryDisplay: 'Interactive Workshop',
              level: 'Intermediate',
              duration: '30 min',
              isWorkshop: true,
              isModule: false,
              completionRate: 0,
              subActivities: [],
            ),
          ),
        );

        expect(
          find.text('This is an interactive workshop activity. It isn\'t available in the app yet.'),
          findsNothing,
        );
        expect(find.text('Start Roleplay Practice'), findsOneWidget);
      },
    );

    testWidgets(
      'Batch 8 — a JAM workshop activity (title matches isJamModuleActivity) shows a Start JAM Session CTA instead of the "not available" banner',
      (tester) async {
        await _pump(
          tester,
          Success(
            const ActivityDetail(
              id: 12,
              title: 'JAM Practice',
              description: 'd',
              category: 'workshop',
              categoryDisplay: 'Interactive Workshop',
              level: 'Intermediate',
              duration: '30 min',
              isWorkshop: true,
              isModule: false,
              completionRate: 0,
              subActivities: [],
            ),
          ),
        );

        expect(
          find.text('This is an interactive workshop activity. It isn\'t available in the app yet.'),
          findsNothing,
        );
        expect(find.text('Start JAM Session'), findsOneWidget);
      },
    );
  });

  group('locked state', () {
    testWidgets('View Plans navigates to the Pro/Membership placeholder', (tester) async {
      await _pumpWithRouter(tester, const Failed(ForbiddenFailure()));

      await tester.tap(find.text('View Plans'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));

      expect(find.text('Upgrade Plan Screen'), findsOneWidget);
    });

    testWidgets('Back to Activities returns to the Activities list', (tester) async {
      await _pumpWithRouter(tester, const Failed(ForbiddenFailure()));

      await tester.tap(find.text('Back to Activities'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));

      expect(find.text('Activities'), findsOneWidget);
    });
  });

  group('Previous/Next navigation', () {
    ActivityDetail detail({int id = 12}) => ActivityDetail(
      id: id,
      title: 'Middle Activity',
      description: 'd',
      category: 'vocabulary',
      categoryDisplay: 'Vocabulary & Idioms',
      level: 'Intermediate',
      duration: '30 min',
      isWorkshop: false,
      isModule: false,
      completionRate: 0,
      subActivities: const [],
    );

    testWidgets('shows both Previous and Next when the activity has neighbors on both sides', (tester) async {
      await _pump(
        tester,
        Success(detail()),
        listResult: Success(
          ActivityListData(
            activities: [_listActivity(11, 'First Activity'), _listActivity(12, 'Middle Activity'), _listActivity(13, 'Last Activity')],
            categories: const [],
            selectedCategory: '',
            isFreePreview: false,
            totalActivities: 3,
          ),
        ),
      );
      await tester.pump();

      expect(find.text('First Activity'), findsOneWidget);
      expect(find.text('Last Activity'), findsOneWidget);
    });

    testWidgets('omits Previous at the first activity (boundary)', (tester) async {
      await _pump(
        tester,
        Success(detail()),
        listResult: Success(
          ActivityListData(
            activities: [_listActivity(12, 'Middle Activity'), _listActivity(13, 'Last Activity')],
            categories: const [],
            selectedCategory: '',
            isFreePreview: false,
            totalActivities: 2,
          ),
        ),
      );
      await tester.pump();

      expect(find.byIcon(Icons.arrow_back), findsNothing);
      expect(find.text('Last Activity'), findsOneWidget);
    });

    testWidgets('omits Next at the last activity (boundary)', (tester) async {
      await _pump(
        tester,
        Success(detail()),
        listResult: Success(
          ActivityListData(
            activities: [_listActivity(11, 'First Activity'), _listActivity(12, 'Middle Activity')],
            categories: const [],
            selectedCategory: '',
            isFreePreview: false,
            totalActivities: 2,
          ),
        ),
      );
      await tester.pump();

      expect(find.text('First Activity'), findsOneWidget);
      expect(find.byIcon(Icons.arrow_forward), findsNothing);
    });

    testWidgets('is omitted entirely for a Free-Plan preview (can\'t be derived correctly)', (tester) async {
      await _pump(
        tester,
        Success(detail()),
        listResult: Success(
          ActivityListData(
            activities: [_listActivity(12, 'Middle Activity')],
            categories: const [],
            selectedCategory: '',
            isFreePreview: true,
            totalActivities: 4,
          ),
        ),
      );
      await tester.pump();

      expect(find.byIcon(Icons.arrow_back), findsNothing);
      expect(find.byIcon(Icons.arrow_forward), findsNothing);
    });

    testWidgets('tapping Next navigates to that activity\'s Detail screen', (tester) async {
      await _pumpWithRouter(
        tester,
        Success(detail()),
        listResult: Success(
          ActivityListData(
            activities: [_listActivity(12, 'Middle Activity'), _listActivity(13, 'Last Activity')],
            categories: const [],
            selectedCategory: '',
            isFreePreview: false,
            totalActivities: 2,
          ),
        ),
      );
      await tester.pump();

      await tester.tap(find.text('Last Activity'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));

      // Navigated to id 13's detail screen, which (with no listResult
      // override there) simply shows no Previous/Next bar — confirmed by
      // the absence of a second "Last Activity" navigation button.
      expect(find.byIcon(Icons.arrow_forward), findsNothing);
    });
  });

  testWidgets('renders a rich activity with long titles without overflow at 320px', (tester) async {
    tester.view.physicalSize = const Size(320, 640);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await _pump(
      tester,
      Success(
        ActivityDetail(
          id: 12,
          title: 'A Genuinely Very Long Activity Title That Could Wrap Across Several Lines',
          description: 'A longer description of what this activity teaches, spanning enough text to wrap.',
          category: 'vocabulary',
          categoryDisplay: 'Vocabulary & Idioms',
          level: 'Intermediate',
          duration: '30 min',
          isWorkshop: false,
          isModule: false,
          completionRate: 40,
          subActivities: [
            SubActivitySummary(
              id: 1,
              title: 'A Sub-Activity With A Genuinely Long Title That Could Wrap Onto Multiple Lines',
              description: 'A longer sub-activity description that spans enough text to wrap across lines.',
              order: 1,
              status: SubActivityStatus.inProgress,
              exerciseCount: 3,
              startedAt: DateTime(2026, 1, 15, 14, 30),
            ),
          ],
        ),
      ),
      listResult: Success(
        ActivityListData(
          activities: [
            _listActivity(11, 'A Very Long Previous Activity Title That Gets Truncated'),
            _listActivity(12, 'Current'),
            _listActivity(13, 'A Very Long Next Activity Title That Also Gets Truncated'),
          ],
          categories: const [],
          selectedCategory: '',
          isFreePreview: false,
          totalActivities: 3,
        ),
      ),
    );
    await tester.pump();

    expect(tester.takeException(), isNull);
  });
}
