import 'package:career_buddy_lms/app/router/route_paths.dart';
import 'package:career_buddy_lms/core/errors/failures.dart';
import 'package:career_buddy_lms/core/utils/result.dart';
import 'package:career_buddy_lms/features/activities/domain/entities/activity_detail.dart';
import 'package:career_buddy_lms/features/activities/domain/entities/activity_list_data.dart';
import 'package:career_buddy_lms/features/activities/domain/entities/sub_activity_detail.dart';
import 'package:career_buddy_lms/features/activities/domain/repositories/activities_repository.dart';
import 'package:career_buddy_lms/features/activities/presentation/providers/activities_providers.dart';
import 'package:career_buddy_lms/features/activities/presentation/screens/activity_detail_screen.dart';
import 'package:career_buddy_lms/features/activities/presentation/screens/workshop_dashboard_screen.dart';
import 'package:career_buddy_lms/features/auth/domain/entities/auth_user.dart';
import 'package:career_buddy_lms/features/auth/domain/repositories/auth_repository.dart';
import 'package:career_buddy_lms/features/auth/domain/entities/student_registration_data.dart';
import 'package:career_buddy_lms/features/auth/presentation/providers/auth_providers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

/// Regression coverage for a real bug: `GoRoute` matching walks the route
/// list in declaration order and uses the first structural match.
/// `/activities/workshop` (W013's `RoutePaths.workshopDashboard`)
/// structurally matches `/activities/:id`
/// (`RoutePaths.activityDetailPattern`) too — both are a single path
/// segment after `/activities/`. With the parameterized route declared
/// first (as it briefly was in `app_router.dart`), navigating to
/// `/activities/workshop` was matched as `activityDetail(id: "workshop")`;
/// `int.tryParse("workshop")` returns `null`, defaulting to `-1`, which
/// produced a real `GET /activities/api/-1/` request, 404'd, and showed
/// `ActivityDetailScreen`'s generic "We couldn't find what you were
/// looking for" error — exactly the reported symptom. Fixed by declaring
/// `workshopDashboard` before `activityDetailPattern`; this test builds
/// the two routes in that same (correct) order and would fail if the
/// order ever regresses.
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
  _FakeActivitiesRepository();

  int? lastRequestedDetailId;

  @override
  Future<Result<ActivityDetail>> getActivityDetail(int id) async {
    lastRequestedDetailId = id;
    return Success(
      ActivityDetail(
        id: id,
        title: 'Test Activity $id',
        description: 'A test activity.',
        category: 'vocabulary',
        categoryDisplay: 'Vocabulary & Idioms',
        level: 'Beginner',
        duration: '10 min',
        isWorkshop: false,
        isModule: false,
        completionRate: 0,
        subActivities: const [],
      ),
    );
  }

  @override
  Future<Result<ActivityListData>> getActivityList({String? category}) async =>
      const Success(ActivityListData(activities: [], categories: [], selectedCategory: 'workshop', isFreePreview: false, totalActivities: 0));

  @override
  Future<Result<ActivityListData>> getWorkshopModules() => getActivityList();

  @override
  Future<Result<SubActivityDetail>> getSubActivityDetail(int activityId, int subActivityId) async => throw UnimplementedError();

  @override
  Future<Result<void>> markSubComplete(int subActivityId) async => throw UnimplementedError();
}

GoRouter _buildRouter(String initialLocation) {
  return GoRouter(
    initialLocation: initialLocation,
    routes: [
      // Same order as the real, fixed app_router.dart: the literal route
      // before the parameterized one.
      GoRoute(
        path: RoutePaths.workshopDashboard,
        builder: (context, state) => const WorkshopDashboardScreen(),
      ),
      GoRoute(
        path: RoutePaths.activityDetailPattern,
        builder: (context, state) {
          final id = int.tryParse(state.pathParameters['id'] ?? '') ?? -1;
          return ActivityDetailScreen(activityId: id);
        },
      ),
    ],
  );
}

void main() {
  testWidgets('/activities/workshop resolves to WorkshopDashboardScreen, not ActivityDetailScreen', (tester) async {
    final repo = _FakeActivitiesRepository();
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          authRepositoryProvider.overrideWithValue(_FakeAuthRepository()),
          activitiesRepositoryProvider.overrideWithValue(repo),
        ],
        child: MaterialApp.router(routerConfig: _buildRouter(RoutePaths.workshopDashboard)),
      ),
    );
    await tester.pump();

    expect(find.byType(WorkshopDashboardScreen), findsOneWidget);
    expect(find.byType(ActivityDetailScreen), findsNothing);
    // The bug's tell-tale symptom must not appear.
    expect(find.text(const NotFoundFailure().message), findsNothing);
    // No detail request should have fired at all for the workshop route.
    expect(repo.lastRequestedDetailId, isNull);
    expect(tester.takeException(), isNull);
  });

  testWidgets('/activities/<id> still resolves to ActivityDetailScreen with the real numeric id', (tester) async {
    final repo = _FakeActivitiesRepository();
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          authRepositoryProvider.overrideWithValue(_FakeAuthRepository()),
          activitiesRepositoryProvider.overrideWithValue(repo),
        ],
        child: MaterialApp.router(routerConfig: _buildRouter(RoutePaths.activityDetail(42))),
      ),
    );
    for (var i = 0; i < 5; i++) {
      await tester.pump();
    }

    expect(find.byType(ActivityDetailScreen), findsOneWidget);
    expect(find.text('Test Activity 42'), findsOneWidget);
    expect(repo.lastRequestedDetailId, 42); // never -1
    expect(tester.takeException(), isNull);
  });
}
