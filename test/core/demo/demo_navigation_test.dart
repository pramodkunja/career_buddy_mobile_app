import 'package:career_buddy_lms/app/router/route_paths.dart';
import 'package:career_buddy_lms/core/demo/demo_activities_repository.dart';
import 'package:career_buddy_lms/core/demo/demo_bingo_exercise_repository.dart';
import 'package:career_buddy_lms/core/demo/demo_matching_exercise_repository.dart';
import 'package:career_buddy_lms/core/demo/demo_mcq_exercise_repository.dart';
import 'package:career_buddy_lms/core/demo/demo_progress_store.dart';
import 'package:career_buddy_lms/core/utils/result.dart';
import 'package:career_buddy_lms/features/activities/presentation/providers/activities_providers.dart';
import 'package:career_buddy_lms/features/activities/presentation/screens/activity_detail_screen.dart';
import 'package:career_buddy_lms/features/activities/presentation/screens/activity_list_screen.dart';
import 'package:career_buddy_lms/features/activities/presentation/screens/sub_activity_detail_screen.dart';
import 'package:career_buddy_lms/features/auth/domain/entities/auth_user.dart';
import 'package:career_buddy_lms/features/auth/domain/repositories/auth_repository.dart';
import 'package:career_buddy_lms/features/auth/domain/entities/student_registration_data.dart';
import 'package:career_buddy_lms/features/auth/presentation/providers/auth_providers.dart';
import 'package:career_buddy_lms/features/bingo/presentation/providers/bingo_providers.dart';
import 'package:career_buddy_lms/core/demo/demo_fill_blank_exercise_repository.dart';
import 'package:career_buddy_lms/core/demo/demo_generic_writing_repository.dart';
import 'package:career_buddy_lms/features/fill_blank/presentation/providers/fill_blank_exercise_providers.dart';
import 'package:career_buddy_lms/features/generic_writing/presentation/providers/generic_writing_providers.dart';
import 'package:career_buddy_lms/features/matching/presentation/providers/matching_providers.dart';
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

/// Exercises real `ActivityListScreen`/`ActivityDetailScreen`/
/// `SubActivityDetailScreen` navigation end to end against the demo
/// repositories — proving the "demo activity/sub-activity/exercise
/// navigation" path required by the Demo Mode task actually reaches the
/// intended destination route, with no real database rows involved. The
/// four AI screens and `McqExerciseScreen` are stood in for by lightweight
/// placeholder routes here (their own dedicated screen tests already cover
/// their internals; this file only proves the routing chain is reachable
/// from demo data).
Future<void> _pumpAt(WidgetTester tester, String location) async {
  // A tall viewport keeps every demo activity/sub-activity/exercise card
  // realized and on-screen at once — the Activities list has 12 demo
  // cards by design (one per required category, §Part 1, plus W008's
  // Vocabulary Matching, W009's Vocabulary Bingo, W010's Vocabulary Fill
  // in the Blank, and W013's Business Negotiation Simulation), which sit
  // below the fold at the default 800x600 test window.
  tester.view.physicalSize = const Size(800, 3600);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);

  final router = GoRouter(
    initialLocation: location,
    routes: [
      GoRoute(path: RoutePaths.activities, builder: (context, state) => const ActivityListScreen()),
      GoRoute(
        path: RoutePaths.activityDetailPattern,
        builder: (context, state) {
          final id = int.tryParse(state.pathParameters['id'] ?? '') ?? -1;
          return ActivityDetailScreen(activityId: id);
        },
      ),
      GoRoute(
        path: RoutePaths.subActivityDetailPattern,
        builder: (context, state) {
          final activityId = int.tryParse(state.pathParameters['activityId'] ?? '') ?? -1;
          final subId = int.tryParse(state.pathParameters['subId'] ?? '') ?? -1;
          return SubActivityDetailScreen(activityId: activityId, subActivityId: subId);
        },
      ),
      GoRoute(
        path: RoutePaths.mcqExercisePattern,
        builder: (context, state) => const Scaffold(body: Text('MCQ Exercise Screen reached')),
      ),
      GoRoute(
        path: RoutePaths.matchingExercisePattern,
        builder: (context, state) => const Scaffold(body: Text('Matching Exercise Screen reached')),
      ),
      GoRoute(
        path: RoutePaths.bingoExercisePattern,
        builder: (context, state) => const Scaffold(body: Text('Bingo Exercise Screen reached')),
      ),
      GoRoute(
        path: RoutePaths.fillBlankExercisePattern,
        builder: (context, state) => const Scaffold(body: Text('Fill Blank Exercise Screen reached')),
      ),
      GoRoute(
        path: RoutePaths.genericWritingExercisePattern,
        builder: (context, state) => const Scaffold(body: Text('Generic Writing Exercise Screen reached')),
      ),
      GoRoute(
        path: RoutePaths.aiSpeakingPattern,
        builder: (context, state) => const Scaffold(body: Text('AI Speaking Screen reached')),
      ),
      GoRoute(
        path: RoutePaths.aiWritingPattern,
        builder: (context, state) => const Scaffold(body: Text('AI Writing Screen reached')),
      ),
      GoRoute(
        path: RoutePaths.aiListeningPattern,
        builder: (context, state) => const Scaffold(body: Text('AI Listening Screen reached')),
      ),
      GoRoute(
        path: RoutePaths.aiReadingPattern,
        builder: (context, state) => const Scaffold(body: Text('AI Reading Screen reached')),
      ),
      GoRoute(path: RoutePaths.pro, builder: (context, state) => const Scaffold(body: Text('Upgrade Plan Screen'))),
    ],
  );

  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        authRepositoryProvider.overrideWithValue(_FakeAuthRepository()),
        activitiesRepositoryProvider.overrideWithValue(DemoActivitiesRepository()),
        mcqExerciseRepositoryProvider.overrideWithValue(DemoMcqExerciseRepository()),
        matchingExerciseRepositoryProvider.overrideWithValue(DemoMatchingExerciseRepository()),
        bingoExerciseRepositoryProvider.overrideWithValue(DemoBingoExerciseRepository()),
        fillBlankExerciseRepositoryProvider.overrideWithValue(DemoFillBlankExerciseRepository()),
        genericWritingRepositoryProvider.overrideWithValue(DemoGenericWritingRepository()),
      ],
      child: MaterialApp.router(routerConfig: router),
    ),
  );
  for (var i = 0; i < 6; i++) {
    await tester.pump(const Duration(milliseconds: 250));
  }
}

void main() {
  setUp(DemoProgressStore.instance.reset);

  group('AI-module demo navigation', () {
    testWidgets(
      'Activities -> Professional Speaking -> Speaking Practice -> AI Speaking Exercise reaches AiSpeakingScreen',
      (tester) async {
        await _pumpAt(tester, RoutePaths.activities);
        expect(find.text('Professional Speaking'), findsOneWidget);

        await tester.tap(find.text('Professional Speaking'));
        for (var i = 0; i < 6; i++) {
          await tester.pump(const Duration(milliseconds: 250));
        }
        expect(find.text('Speaking Practice'), findsOneWidget);

        await tester.tap(find.text('Speaking Practice'));
        for (var i = 0; i < 6; i++) {
          await tester.pump(const Duration(milliseconds: 250));
        }
        expect(find.text('AI Speaking Exercise'), findsOneWidget);

        await tester.tap(find.text('AI Speaking Exercise'));
        await tester.pumpAndSettle();

        expect(find.text('AI Speaking Screen reached'), findsOneWidget);
      },
    );

    testWidgets('Activities -> Professional Passage Writing -> Writing Practice -> AI Writing Exercise reaches AiWritingScreen', (
      tester,
    ) async {
      await _pumpAt(tester, RoutePaths.activities);
      await tester.tap(find.text('Professional Passage Writing'));
      for (var i = 0; i < 6; i++) {
        await tester.pump(const Duration(milliseconds: 250));
      }
      await tester.tap(find.text('Writing Practice'));
      for (var i = 0; i < 6; i++) {
        await tester.pump(const Duration(milliseconds: 250));
      }
      await tester.tap(find.text('AI Writing Exercise'));
      await tester.pumpAndSettle();

      expect(find.text('AI Writing Screen reached'), findsOneWidget);
    });

    testWidgets(
      'Activities -> Listen & Write -> Listening Practice -> AI Listening Exercise reaches AiListeningScreen',
      (tester) async {
        await _pumpAt(tester, RoutePaths.activities);
        await tester.tap(find.text('Listen & Write'));
        for (var i = 0; i < 6; i++) {
          await tester.pump(const Duration(milliseconds: 250));
        }
        await tester.tap(find.text('Listening Practice'));
        for (var i = 0; i < 6; i++) {
          await tester.pump(const Duration(milliseconds: 250));
        }
        await tester.tap(find.text('AI Listening Exercise'));
        await tester.pumpAndSettle();

        expect(find.text('AI Listening Screen reached'), findsOneWidget);
      },
    );

    testWidgets('Activities -> Professional Reading -> Reading Practice -> AI Reading Exercise reaches AiReadingScreen', (
      tester,
    ) async {
      await _pumpAt(tester, RoutePaths.activities);
      await tester.tap(find.text('Professional Reading'));
      for (var i = 0; i < 6; i++) {
        await tester.pump(const Duration(milliseconds: 250));
      }
      await tester.tap(find.text('Reading Practice'));
      for (var i = 0; i < 6; i++) {
        await tester.pump(const Duration(milliseconds: 250));
      }
      await tester.tap(find.text('AI Reading Exercise'));
      await tester.pumpAndSettle();

      expect(find.text('AI Reading Screen reached'), findsOneWidget);
    });
  });

  testWidgets('Activities -> Vocabulary Quiz -> Vocabulary Practice -> Vocabulary Quiz Exercise reaches McqExerciseScreen', (
    tester,
  ) async {
    await _pumpAt(tester, RoutePaths.activities);
    await tester.tap(find.text('Vocabulary Quiz'));
    for (var i = 0; i < 6; i++) {
      await tester.pump(const Duration(milliseconds: 250));
    }
    await tester.tap(find.text('Vocabulary Practice'));
    for (var i = 0; i < 6; i++) {
      await tester.pump(const Duration(milliseconds: 250));
    }
    await tester.tap(find.text('Vocabulary Quiz Exercise'));
    await tester.pumpAndSettle();

    expect(find.text('MCQ Exercise Screen reached'), findsOneWidget);
  });

  testWidgets(
    'Activities -> Vocabulary Matching -> Matching Practice -> Workplace Abbreviations Matching reaches MatchingExerciseScreen',
    (tester) async {
      await _pumpAt(tester, RoutePaths.activities);
      await tester.tap(find.text('Vocabulary Matching'));
      for (var i = 0; i < 6; i++) {
        await tester.pump(const Duration(milliseconds: 250));
      }
      await tester.tap(find.text('Matching Practice'));
      for (var i = 0; i < 6; i++) {
        await tester.pump(const Duration(milliseconds: 250));
      }
      await tester.tap(find.text('Workplace Abbreviations Matching'));
      await tester.pumpAndSettle();

      expect(find.text('Matching Exercise Screen reached'), findsOneWidget);
    },
  );

  testWidgets(
    'Activities -> Vocabulary Bingo -> Bingo Practice -> Workplace Vocabulary Bingo reaches BingoExerciseScreen',
    (tester) async {
      await _pumpAt(tester, RoutePaths.activities);
      await tester.tap(find.text('Vocabulary Bingo'));
      for (var i = 0; i < 6; i++) {
        await tester.pump(const Duration(milliseconds: 250));
      }
      await tester.tap(find.text('Bingo Practice'));
      for (var i = 0; i < 6; i++) {
        await tester.pump(const Duration(milliseconds: 250));
      }
      await tester.tap(find.text('Workplace Vocabulary Bingo'));
      await tester.pumpAndSettle();

      expect(find.text('Bingo Exercise Screen reached'), findsOneWidget);
    },
  );

  testWidgets(
    'Activities -> Vocabulary Fill in the Blank -> Fill in the Blank Practice -> Workplace Vocabulary Fill in the Blank reaches FillBlankExerciseScreen',
    (tester) async {
      await _pumpAt(tester, RoutePaths.activities);
      await tester.tap(find.text('Vocabulary Fill in the Blank'));
      for (var i = 0; i < 6; i++) {
        await tester.pump(const Duration(milliseconds: 250));
      }
      await tester.tap(find.text('Fill in the Blank Practice'));
      for (var i = 0; i < 6; i++) {
        await tester.pump(const Duration(milliseconds: 250));
      }
      await tester.tap(find.text('Workplace Vocabulary Fill in the Blank'));
      await tester.pumpAndSettle();

      expect(find.text('Fill Blank Exercise Screen reached'), findsOneWidget);
    },
  );

  testWidgets(
    'Activities -> Business Negotiation Simulation -> Live Negotiation and Debrief -> Negotiation Outcome Reflection reaches GenericWritingScreen',
    (tester) async {
      await _pumpAt(tester, RoutePaths.activities);
      await tester.tap(find.text('Business Negotiation Simulation'));
      for (var i = 0; i < 6; i++) {
        await tester.pump(const Duration(milliseconds: 250));
      }
      await tester.tap(find.text('Live Negotiation and Debrief'));
      for (var i = 0; i < 6; i++) {
        await tester.pump(const Duration(milliseconds: 250));
      }
      await tester.tap(find.text('Negotiation Outcome Reflection'));
      await tester.pumpAndSettle();

      expect(find.text('Generic Writing Exercise Screen reached'), findsOneWidget);
    },
  );

  testWidgets('Activities -> Group Discussion opens Activity Detail with no working exercises (workshop entry)', (
    tester,
  ) async {
    await _pumpAt(tester, RoutePaths.activities);
    await tester.tap(find.text('Group Discussion'));
    for (var i = 0; i < 6; i++) {
      await tester.pump(const Duration(milliseconds: 250));
    }

    expect(find.text('Group Discussion'), findsWidgets);
    expect(find.text('AI Speaking Screen reached'), findsNothing);
  });
}
