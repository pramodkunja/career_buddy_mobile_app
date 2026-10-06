import 'package:career_buddy_lms/app/router/route_paths.dart';
import 'package:career_buddy_lms/core/errors/failures.dart';
import 'package:career_buddy_lms/core/utils/result.dart';
import 'package:career_buddy_lms/features/activities/domain/entities/activity_category.dart';
import 'package:career_buddy_lms/features/activities/domain/entities/activity_detail.dart';
import 'package:career_buddy_lms/features/activities/domain/entities/activity_list_data.dart';
import 'package:career_buddy_lms/features/activities/domain/entities/activity_summary.dart';
import 'package:career_buddy_lms/features/activities/domain/entities/sub_activity_detail.dart';
import 'package:career_buddy_lms/features/activities/domain/repositories/activities_repository.dart';
import 'package:career_buddy_lms/features/activities/presentation/providers/activities_providers.dart';
import 'package:career_buddy_lms/features/activities/presentation/screens/activity_list_screen.dart';
import 'package:career_buddy_lms/features/activities/presentation/widgets/activity_card.dart';
import 'package:career_buddy_lms/features/auth/domain/entities/auth_user.dart';
import 'package:career_buddy_lms/features/auth/domain/repositories/auth_repository.dart';
import 'package:career_buddy_lms/features/auth/domain/entities/student_registration_data.dart';
import 'package:career_buddy_lms/features/auth/presentation/providers/auth_providers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

class _FakeAuthRepository implements AuthRepository {
  _FakeAuthRepository();
  int logoutCallCount = 0;

  @override
  Future<AuthUser?> restoreSession() async => const AuthUser(username: 'jane');

  @override
  Future<Result<AuthUser>> login({required String usernameOrEmail, required String password}) async {
    throw UnimplementedError();
  }

  @override
  Future<Result<void>> logout() async {
    logoutCallCount++;
    return const Success(null);
  }

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
  final Result<ActivityListData> listResult;
  final List<String?> requestedCategories = [];

  @override
  Future<Result<ActivityListData>> getActivityList({String? category}) async {
    requestedCategories.add(category);
    return listResult;
  }

  @override
  Future<Result<ActivityListData>> getWorkshopModules() async => throw UnimplementedError();

  @override
  Future<Result<ActivityDetail>> getActivityDetail(int id) async => throw UnimplementedError();

  @override
  Future<Result<SubActivityDetail>> getSubActivityDetail(int activityId, int subActivityId) async => throw UnimplementedError();

  @override
  Future<Result<void>> markSubComplete(int subActivityId) async => throw UnimplementedError();
}

ActivitySummary _activity(int id, String title, {bool isLocked = false, int completionRate = 0}) => ActivitySummary(
  id: id,
  title: title,
  description: 'A longer description of what this activity teaches, spanning enough text to wrap.',
  category: 'vocabulary',
  categoryDisplay: 'Vocabulary & Idioms',
  level: 'Intermediate',
  duration: '30 min',
  isLocked: isLocked,
  completionRate: completionRate,
  isCompleted: completionRate == 100,
);

Future<void> _pump(WidgetTester tester, Result<ActivityListData> result) async {
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        authRepositoryProvider.overrideWithValue(_FakeAuthRepository()),
        activitiesRepositoryProvider.overrideWithValue(_FakeActivitiesRepository(result)),
      ],
      child: const MaterialApp(home: ActivityListScreen()),
    ),
  );
  for (var i = 0; i < 5; i++) {
    await tester.pump();
  }
}

/// Wraps [ActivityListScreen] in a real `GoRouter` (plus the Pro/Membership
/// and Activity Detail placeholders it can navigate to) for tests that
/// exercise actual navigation, not just dialog display.
Future<_FakeActivitiesRepository> _pumpWithRouter(WidgetTester tester, Result<ActivityListData> result) async {
  final repo = _FakeActivitiesRepository(result);
  final router = GoRouter(
    initialLocation: RoutePaths.activities,
    routes: [
      GoRoute(path: RoutePaths.activities, builder: (context, state) => const ActivityListScreen()),
      GoRoute(path: RoutePaths.pro, builder: (context, state) => const Scaffold(body: Text('Upgrade Plan Screen'))),
      GoRoute(
        path: RoutePaths.activityDetailPattern,
        builder: (context, state) => const Scaffold(body: Text('Activity Detail Screen')),
      ),
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
  testWidgets('renders activity cards once data loads', (tester) async {
    await _pump(
      tester,
      Success(
        ActivityListData(
          activities: [_activity(1, 'Business Vocabulary Building Games')],
          categories: const [ActivityCategory(value: 'vocabulary', label: 'Vocabulary & Idioms')],
          selectedCategory: '',
          isFreePreview: false,
          totalActivities: 1,
        ),
      ),
    );

    expect(find.text('Business Vocabulary Building Games'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('an initialCategory (e.g. from the dashboard\'s Quick Start) pre-filters the list', (tester) async {
    final repo = _FakeActivitiesRepository(
      Success(
        const ActivityListData(
          activities: [],
          categories: [ActivityCategory(value: 'speaking', label: 'Speaking & Presentation')],
          selectedCategory: 'speaking',
          isFreePreview: false,
          totalActivities: 0,
        ),
      ),
    );
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          authRepositoryProvider.overrideWithValue(_FakeAuthRepository()),
          activitiesRepositoryProvider.overrideWithValue(repo),
        ],
        child: const MaterialApp(home: ActivityListScreen(initialCategory: 'speaking')),
      ),
    );
    for (var i = 0; i < 5; i++) {
      await tester.pump();
    }

    expect(repo.requestedCategories, contains('speaking'));
  });

  testWidgets('with no initialCategory, opens on "All" exactly as before (no filter call)', (tester) async {
    final repo = _FakeActivitiesRepository(
      Success(
        ActivityListData(
          activities: [_activity(1, 'Business Vocabulary Building Games')],
          categories: const [ActivityCategory(value: 'vocabulary', label: 'Vocabulary & Idioms')],
          selectedCategory: '',
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
        ],
        child: const MaterialApp(home: ActivityListScreen()),
      ),
    );
    for (var i = 0; i < 5; i++) {
      await tester.pump();
    }

    expect(repo.requestedCategories, [null]);
  });

  testWidgets('shows the web list page\'s empty-state copy for an empty category', (tester) async {
    await _pump(
      tester,
      Success(
        const ActivityListData(
          activities: [],
          categories: [ActivityCategory(value: 'negotiation', label: 'Negotiation & Meetings')],
          selectedCategory: 'negotiation',
          isFreePreview: false,
          totalActivities: 0,
        ),
      ),
    );

    expect(find.text('No activities found for this category.'), findsOneWidget);
  });

  testWidgets('signs the user out on an unauthorized response', (tester) async {
    final authRepo = _FakeAuthRepository();
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          authRepositoryProvider.overrideWithValue(authRepo),
          activitiesRepositoryProvider.overrideWithValue(
            _FakeActivitiesRepository(const Failed(UnauthorizedFailure())),
          ),
        ],
        child: const MaterialApp(home: ActivityListScreen()),
      ),
    );
    for (var i = 0; i < 5; i++) {
      await tester.pump();
    }

    expect(authRepo.logoutCallCount, 1);
  });

  testWidgets('shows a retryable error view for a non-auth failure', (tester) async {
    await _pump(tester, const Failed(NotFoundFailure()));

    expect(find.text(const NotFoundFailure().message), findsOneWidget);
    expect(find.text('Retry'), findsOneWidget);
  });

  testWidgets('renders many long-titled cards without overflow at phone and tablet widths', (tester) async {
    final data = Success(
      ActivityListData(
        activities: List.generate(
          6,
          (i) => _activity(
            i,
            'A Genuinely Very Long Activity Title That Could Wrap Across Several Lines Number $i',
            completionRate: i.isEven ? 0 : 55,
          ),
        ),
        categories: const [ActivityCategory(value: 'vocabulary', label: 'Vocabulary & Idioms')],
        selectedCategory: '',
        isFreePreview: false,
        totalActivities: 6,
      ),
    );

    for (final size in [const Size(320, 640), const Size(1024, 1366)]) {
      tester.view.physicalSize = size;
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await _pump(tester, data);
      // Anchor on a card, not `find.byType(Scrollable).first` — the
      // horizontal category filter bar is also a Scrollable and would be
      // an ambiguous/wrong drag target for revealing the vertical list.
      await tester.fling(find.byType(ActivityCard).first, const Offset(0, -2000), 3000, warnIfMissed: false);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 1000));

      expect(tester.takeException(), isNull);
    }
  });

  group('page header', () {
    testWidgets('shows the total-activities subtitle for a full-access plan', (tester) async {
      await _pump(
        tester,
        Success(
          ActivityListData(
            activities: [_activity(1, 'Business Vocabulary Building Games')],
            categories: const [ActivityCategory(value: 'vocabulary', label: 'Vocabulary & Idioms')],
            selectedCategory: '',
            isFreePreview: false,
            totalActivities: 20,
          ),
        ),
      );

      expect(find.text('English Activities'), findsOneWidget);
      expect(find.text('20 comprehensive activities to master professional communication'), findsOneWidget);
    });

    testWidgets('shows the Free-Plan subtitle when isFreePreview, matching the web exactly', (tester) async {
      await _pump(
        tester,
        Success(
          ActivityListData(
            activities: [_activity(1, 'Business Vocabulary Building Games')],
            categories: const [],
            selectedCategory: '',
            isFreePreview: true,
            totalActivities: 4,
          ),
        ),
      );

      expect(
        find.text('Free Plan — choose any one of the 4 activities below. Once started, the rest will be locked.'),
        findsOneWidget,
      );
    });
  });

  group('Free-Plan banner', () {
    testWidgets('shows the "pick any one" copy when no Free-Plan activity has been claimed yet', (tester) async {
      await _pump(
        tester,
        Success(
          ActivityListData(
            activities: [
              _activity(1, 'Listen & Learn'),
              _activity(2, 'Professional Reading'),
              _activity(3, 'Business Vocabulary Building Games'),
              _activity(4, 'Data Presentation and Visualization'),
            ],
            categories: const [],
            selectedCategory: '',
            isFreePreview: true,
            totalActivities: 4,
          ),
        ),
      );

      expect(find.textContaining('pick any one'), findsOneWidget);
      expect(find.textContaining('You have used your one free activity'), findsNothing);
    });

    testWidgets('names the claimed activity once exactly one Free-Plan card is unlocked', (tester) async {
      await _pump(
        tester,
        Success(
          ActivityListData(
            activities: [
              _activity(1, 'Listen & Learn', isLocked: true),
              _activity(2, 'Professional Reading', isLocked: true),
              _activity(3, 'Business Vocabulary Building Games'),
              _activity(4, 'Data Presentation and Visualization', isLocked: true),
            ],
            categories: const [],
            selectedCategory: '',
            isFreePreview: true,
            totalActivities: 4,
          ),
        ),
      );

      expect(find.textContaining('Business Vocabulary Building Games'), findsWidgets);
      expect(find.textContaining('the other 3 are now locked'), findsOneWidget);
    });

    testWidgets('does not render for a full-access plan', (tester) async {
      await _pump(
        tester,
        Success(
          ActivityListData(
            activities: [_activity(1, 'Business Vocabulary Building Games')],
            categories: const [ActivityCategory(value: 'vocabulary', label: 'Vocabulary & Idioms')],
            selectedCategory: '',
            isFreePreview: false,
            totalActivities: 20,
          ),
        ),
      );

      expect(find.text('Free Trial Preview Active'), findsNothing);
    });
  });

  group('activity numbering', () {
    testWidgets('numbers cards by their position in the returned list (#1, #2, ...)', (tester) async {
      await _pump(
        tester,
        Success(
          ActivityListData(
            activities: [
              _activity(1, 'First Activity'),
              _activity(2, 'Second Activity'),
              _activity(3, 'Third Activity'),
            ],
            categories: const [ActivityCategory(value: 'vocabulary', label: 'Vocabulary & Idioms')],
            selectedCategory: '',
            isFreePreview: false,
            totalActivities: 3,
          ),
        ),
      );

      expect(find.text('#1'), findsOneWidget);
      expect(find.text('#2'), findsOneWidget);
      expect(find.text('#3'), findsOneWidget);
    });
  });

  group('locked activity interaction', () {
    testWidgets('tapping a locked card shows the web\'s Upgrade Required dialog instead of navigating', (
      tester,
    ) async {
      await _pump(
        tester,
        Success(
          ActivityListData(
            activities: [_activity(1, 'Data Presentation and Visualization', isLocked: true)],
            categories: const [],
            selectedCategory: '',
            isFreePreview: true,
            totalActivities: 4,
          ),
        ),
      );

      await tester.tap(find.text('Locked 🔒'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));

      expect(find.text('Upgrade Required'), findsOneWidget);
      expect(
        find.text(
          'You have already used your one free activity. Upgrade your plan to '
          'unlock and access all 3 remaining activities.',
        ),
        findsOneWidget,
      );
    });

    testWidgets('Cancel dismisses the dialog without navigating', (tester) async {
      final repo = await _pumpWithRouter(
        tester,
        Success(
          ActivityListData(
            activities: [_activity(1, 'Data Presentation and Visualization', isLocked: true)],
            categories: const [],
            selectedCategory: '',
            isFreePreview: true,
            totalActivities: 4,
          ),
        ),
      );
      repo.requestedCategories.clear();

      await tester.tap(find.text('Locked 🔒'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));
      await tester.tap(find.text('Cancel'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));

      expect(find.text('Upgrade Required'), findsNothing);
      expect(find.text('Upgrade Plan Screen'), findsNothing);
      expect(find.text('Activity Detail Screen'), findsNothing);
    });

    testWidgets('View Plans navigates to the Pro/Membership placeholder', (tester) async {
      await _pumpWithRouter(
        tester,
        Success(
          ActivityListData(
            activities: [_activity(1, 'Data Presentation and Visualization', isLocked: true)],
            categories: const [],
            selectedCategory: '',
            isFreePreview: true,
            totalActivities: 4,
          ),
        ),
      );

      await tester.tap(find.text('Locked 🔒'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));
      await tester.tap(find.text('View Plans'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));

      expect(find.text('Upgrade Plan Screen'), findsOneWidget);
    });
  });

  testWidgets('an unlocked card still navigates to Activity Detail (no regression)', (tester) async {
    await _pumpWithRouter(
      tester,
      Success(
        ActivityListData(
          activities: [_activity(1, 'Business Vocabulary Building Games')],
          categories: const [ActivityCategory(value: 'vocabulary', label: 'Vocabulary & Idioms')],
          selectedCategory: '',
          isFreePreview: false,
          totalActivities: 1,
        ),
      ),
    );

    await tester.tap(find.text('Start Activity'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));

    expect(find.text('Activity Detail Screen'), findsOneWidget);
  });

  testWidgets('empty state\'s "Show All" button clears the category filter, matching the web\'s CTA', (
    tester,
  ) async {
    final repo = await _pumpWithRouter(
      tester,
      Success(
        const ActivityListData(
          activities: [],
          categories: [ActivityCategory(value: 'negotiation', label: 'Negotiation & Meetings')],
          selectedCategory: 'negotiation',
          isFreePreview: false,
          totalActivities: 0,
        ),
      ),
    );

    await tester.tap(find.text('Show All'));
    await tester.pump();

    expect(repo.requestedCategories, contains(null));
  });

  testWidgets('renders the Free-Plan banner and locked cards without overflow at phone and tablet widths', (
    tester,
  ) async {
    final data = Success(
      ActivityListData(
        activities: [
          _activity(1, 'Listen & Learn And Practice Your Business English Comprehension Skills', isLocked: true),
          _activity(2, 'Professional Reading', isLocked: true),
          _activity(
            3,
            'Business Vocabulary Building Games With A Genuinely Long Title That Could Wrap',
            completionRate: 40,
          ),
          _activity(4, 'Data Presentation and Visualization', isLocked: true),
        ],
        categories: const [],
        selectedCategory: '',
        isFreePreview: true,
        totalActivities: 4,
      ),
    );

    for (final size in [const Size(320, 640), const Size(1024, 1366)]) {
      tester.view.physicalSize = size;
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await _pump(tester, data);
      // Anchor on RefreshIndicator, not an ActivityCard — with the page
      // header + Free-Plan banner's longer text, the first card may not be
      // laid out yet at 320px height (nothing to fling from), while the
      // indicator wrapping the whole scroll view always is.
      await tester.fling(find.byType(RefreshIndicator), const Offset(0, -2000), 3000, warnIfMissed: false);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 1000));

      expect(tester.takeException(), isNull);
    }
  });
}
