import 'dart:async';

import 'package:career_buddy_lms/core/errors/failures.dart';
import 'package:career_buddy_lms/core/network/api_client.dart';
import 'package:career_buddy_lms/core/providers/core_providers.dart';
import 'package:career_buddy_lms/core/utils/result.dart';
import 'package:career_buddy_lms/features/activities/domain/entities/activity_detail.dart';
import 'package:career_buddy_lms/features/activities/domain/entities/activity_list_data.dart';
import 'package:career_buddy_lms/features/activities/domain/entities/activity_summary.dart';
import 'package:career_buddy_lms/features/activities/domain/entities/sub_activity_detail.dart';
import 'package:career_buddy_lms/features/activities/domain/repositories/activities_repository.dart';
import 'package:career_buddy_lms/features/activities/presentation/providers/activities_providers.dart';
import 'package:career_buddy_lms/features/activities/presentation/screens/workshop_dashboard_screen.dart';
import 'package:career_buddy_lms/features/auth/domain/entities/auth_user.dart';
import 'package:career_buddy_lms/features/auth/domain/repositories/auth_repository.dart';
import 'package:career_buddy_lms/features/auth/domain/entities/student_registration_data.dart';
import 'package:career_buddy_lms/features/auth/presentation/providers/auth_providers.dart';
import 'package:career_buddy_lms/features/group_discussion/presentation/providers/gd_providers.dart';
import 'package:career_buddy_lms/features/group_discussion/presentation/screens/gd_topic_screen.dart';
import 'package:career_buddy_lms/features/jam/domain/entities/jam_assessment.dart';
import 'package:career_buddy_lms/features/jam/domain/entities/jam_session_result.dart';
import 'package:career_buddy_lms/features/jam/domain/entities/jam_session_start.dart';
import 'package:career_buddy_lms/features/jam/domain/entities/jam_topic.dart';
import 'package:career_buddy_lms/features/jam/domain/repositories/jam_assessment_repository.dart';
import 'package:career_buddy_lms/features/jam/domain/repositories/jam_repository.dart';
import 'package:career_buddy_lms/features/jam/presentation/providers/jam_providers.dart';
import 'package:career_buddy_lms/features/jam/presentation/screens/jam_topics_screen.dart';
import 'package:career_buddy_lms/features/roleplay/presentation/screens/roleplay_home_screen.dart';
import 'package:career_buddy_lms/shared/widgets/coming_soon_screen.dart';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../group_discussion/gd_test_doubles.dart';

/// Never resolves `startSession` — only used to verify navigation
/// happened, same reasoning as `jam_topics_screen_test.dart`'s own
/// `_NeverJamRepository`.
class _StubJamRepository implements JamRepository {
  @override
  Future<Result<JamSessionStart>> startSession({int? topicId}) => Completer<Result<JamSessionStart>>().future;

  @override
  Future<Result<List<JamTopic>>> getTopics() async => const Success([]);

  @override
  Future<Result<void>> saveAudio({
    required int sessionId,
    String? audioFilePath,
    required int durationSeconds,
    required String language,
    String transcript = '',
  }) => throw UnimplementedError();

  @override
  Future<Result<JamSessionResult>> completeSession(int sessionId) => throw UnimplementedError();
}

class _StubJamAssessmentRepository implements JamAssessmentRepository {
  @override
  Future<Result<List<JamPracticeSessionSummary>>> getHistory() async => const Success([]);

  @override
  Future<Result<JamSessionStart>> startAssessment() => throw UnimplementedError();

  @override
  Future<Result<JamAssessmentStageOutcome>> completeAssessmentStage(int sessionId) => throw UnimplementedError();
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

class _FakeActivitiesRepository implements ActivitiesRepository {
  _FakeActivitiesRepository(this.listResult);

  Result<ActivityListData> listResult;

  @override
  Future<Result<ActivityListData>> getActivityList({String? category}) async => listResult;

  @override
  Future<Result<ActivityListData>> getWorkshopModules() async => listResult;

  @override
  Future<Result<ActivityDetail>> getActivityDetail(int id) async => throw UnimplementedError();

  @override
  Future<Result<SubActivityDetail>> getSubActivityDetail(int activityId, int subActivityId) async => throw UnimplementedError();

  @override
  Future<Result<void>> markSubComplete(int subActivityId) async => throw UnimplementedError();
}

ActivitySummary _summary({
  required int id,
  required String title,
  String description = 'A short objective.',
  String level = 'Beginner',
}) => ActivitySummary(
  id: id,
  title: title,
  description: description,
  category: 'workshop',
  categoryDisplay: 'Interactive Workshop',
  level: level,
  duration: '30 min',
  isLocked: false,
  completionRate: 0,
  isCompleted: false,
);

Future<void> _pump(WidgetTester tester, ActivitiesRepository repo) async {
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        authRepositoryProvider.overrideWithValue(_FakeAuthRepository()),
        activitiesRepositoryProvider.overrideWithValue(repo),
      ],
      child: const MaterialApp(home: WorkshopDashboardScreen()),
    ),
  );
  for (var i = 0; i < 5; i++) {
    await tester.pump();
  }
}

void main() {
  testWidgets('renders every workshop module numbered, with level, objective, and Enter Workshop action', (tester) async {
    final repo = _FakeActivitiesRepository(
      Success(
        ActivityListData(
          activities: [
            _summary(id: 1, title: 'Group Discussion Practice'),
            _summary(id: 2, title: 'JAM Session'),
          ],
          categories: const [],
          selectedCategory: 'workshop',
          isFreePreview: false,
          totalActivities: 2,
        ),
      ),
    );

    await _pump(tester, repo);

    expect(find.text('1'), findsOneWidget);
    expect(find.text('2'), findsOneWidget);
    expect(find.text('Group Discussion Practice'), findsOneWidget);
    expect(find.text('JAM Session'), findsOneWidget);
    expect(find.text('A short objective.'), findsWidgets);
    expect(find.text('Beginner'), findsWidgets);
    expect(find.text('Workshop'), findsWidgets);
    expect(find.text('Real-time Interaction'), findsWidgets);
    expect(find.text('Enter Workshop'), findsWidgets);
    expect(tester.takeException(), isNull);
  });

  testWidgets('level and Workshop badges use the reused .badge-level/.badge-category colors, not a generic gold accent', (
    tester,
  ) async {
    final repo = _FakeActivitiesRepository(
      Success(
        ActivityListData(
          activities: [_summary(id: 1, title: 'Group Discussion Practice')],
          categories: const [],
          selectedCategory: 'workshop',
          isFreePreview: false,
          totalActivities: 1,
        ),
      ),
    );
    await _pump(tester, repo);

    final levelContainer = tester
        .widgetList<Container>(find.ancestor(of: find.text('Beginner'), matching: find.byType(Container)))
        .first;
    expect((levelContainer.decoration! as BoxDecoration).color, const Color(0xFFEDE9FE));

    final workshopContainer = tester
        .widgetList<Container>(find.ancestor(of: find.text('Workshop'), matching: find.byType(Container)))
        .first;
    expect((workshopContainer.decoration! as BoxDecoration).color, const Color(0xFFF1F5F9));
  });

  testWidgets('truncates a long objective to 110 characters with an ellipsis, matching Django\'s truncatechars:110', (tester) async {
    final longObjective = 'A' * 200;
    final repo = _FakeActivitiesRepository(
      Success(
        ActivityListData(
          activities: [_summary(id: 1, title: 'Role Play Practice', description: longObjective)],
          categories: const [],
          selectedCategory: 'workshop',
          isFreePreview: false,
          totalActivities: 1,
        ),
      ),
    );

    await _pump(tester, repo);

    final expected = '${'A' * 109}…';
    expect(find.text(expected), findsOneWidget);
    expect(find.text(longObjective), findsNothing);
  });

  testWidgets('tapping Enter Workshop on a Group Discussion module opens the real GdTopicScreen', (tester) async {
    final repo = _FakeActivitiesRepository(
      Success(
        ActivityListData(
          activities: [_summary(id: 1, title: 'Group Discussion Practice')],
          categories: const [],
          selectedCategory: 'workshop',
          isFreePreview: false,
          totalActivities: 1,
        ),
      ),
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          authRepositoryProvider.overrideWithValue(_FakeAuthRepository()),
          activitiesRepositoryProvider.overrideWithValue(repo),
          gdRepositoryProvider.overrideWithValue(FakeGdRepository()),
          gdRealtimeServiceProvider.overrideWithValue(FakeGdRealtimeService()),
          gdSpeechServiceProvider.overrideWithValue(FakeGdSpeechService()),
          gdTtsServiceProvider.overrideWithValue(FakeGdTtsService()),
          apiClientProvider.overrideWithValue(ApiClient.forTesting(Dio())),
        ],
        child: const MaterialApp(home: WorkshopDashboardScreen()),
      ),
    );
    for (var i = 0; i < 5; i++) {
      await tester.pump();
    }

    await tester.tap(find.text('Enter Workshop'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));

    expect(find.byType(GdTopicScreen), findsOneWidget);
    expect(find.byType(ComingSoonScreen), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('tapping Enter Workshop on a JAM module opens the real JamTopicsScreen', (tester) async {
    final repo = _FakeActivitiesRepository(
      Success(
        ActivityListData(
          activities: [_summary(id: 1, title: 'JAM (Just A Minute)')],
          categories: const [],
          selectedCategory: 'workshop',
          isFreePreview: false,
          totalActivities: 1,
        ),
      ),
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          authRepositoryProvider.overrideWithValue(_FakeAuthRepository()),
          activitiesRepositoryProvider.overrideWithValue(repo),
          jamRepositoryProvider.overrideWithValue(_StubJamRepository()),
          jamAssessmentRepositoryProvider.overrideWithValue(_StubJamAssessmentRepository()),
        ],
        child: const MaterialApp(home: WorkshopDashboardScreen()),
      ),
    );
    for (var i = 0; i < 5; i++) {
      await tester.pump();
    }

    await tester.tap(find.text('Enter Workshop'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));

    expect(find.byType(JamTopicsScreen), findsOneWidget);
    expect(find.byType(ComingSoonScreen), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('tapping Enter Workshop on a Role Play module opens the real RoleplayHomeScreen', (tester) async {
    final repo = _FakeActivitiesRepository(
      Success(
        ActivityListData(
          activities: [_summary(id: 1, title: 'Role Play')],
          categories: const [],
          selectedCategory: 'workshop',
          isFreePreview: false,
          totalActivities: 1,
        ),
      ),
    );

    await _pump(tester, repo);
    await tester.tap(find.text('Enter Workshop'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));

    expect(find.byType(RoleplayHomeScreen), findsOneWidget);
    expect(find.byType(ComingSoonScreen), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('an unrecognized module title still gets a real, working ComingSoon destination, not a dead tap', (tester) async {
    final repo = _FakeActivitiesRepository(
      Success(
        ActivityListData(
          activities: [_summary(id: 1, title: 'Mystery Workshop')],
          categories: const [],
          selectedCategory: 'workshop',
          isFreePreview: false,
          totalActivities: 1,
        ),
      ),
    );

    await _pump(tester, repo);
    await tester.tap(find.text('Enter Workshop'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));

    expect(find.textContaining('This workshop isn\'t available'), findsOneWidget);
  });

  testWidgets('an empty workshop list shows a clear empty state, not a blank screen', (tester) async {
    final repo = _FakeActivitiesRepository(
      Success(
        const ActivityListData(activities: [], categories: [], selectedCategory: 'workshop', isFreePreview: false, totalActivities: 0),
      ),
    );

    await _pump(tester, repo);

    expect(find.text('No workshop activities available right now.'), findsOneWidget);
  });

  testWidgets('shows a retryable error view for a load failure', (tester) async {
    final repo = _FakeActivitiesRepository(const Failed(ServerFailure()));

    await _pump(tester, repo);

    expect(find.text(const ServerFailure().message), findsOneWidget);
    expect(find.text('Retry'), findsOneWidget);
  });

  testWidgets('renders without overflow at narrow phone and tablet widths', (tester) async {
    for (final size in [const Size(320, 640), const Size(1024, 1366)]) {
      tester.view.physicalSize = size;
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final repo = _FakeActivitiesRepository(
        Success(
          ActivityListData(
            activities: [
              _summary(
                id: 1,
                title: 'A Genuinely Long Interactive Workshop Title That Could Wrap Onto Multiple Lines',
                description: 'A' * 150,
              ),
            ],
            categories: const [],
            selectedCategory: 'workshop',
            isFreePreview: false,
            totalActivities: 1,
          ),
        ),
      );

      await _pump(tester, repo);

      expect(tester.takeException(), isNull);
    }
  });
}
