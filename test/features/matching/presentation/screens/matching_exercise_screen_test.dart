import 'package:career_buddy_lms/core/errors/failures.dart';
import 'package:career_buddy_lms/core/utils/result.dart';
import 'package:career_buddy_lms/features/matching/domain/entities/matching_exercise.dart';
import 'package:career_buddy_lms/features/matching/domain/entities/matching_pair.dart';
import 'package:career_buddy_lms/features/matching/domain/entities/matching_submission_result.dart';
import 'package:career_buddy_lms/features/matching/domain/repositories/matching_exercise_repository.dart';
import 'package:career_buddy_lms/features/matching/presentation/matching_route_args.dart';
import 'package:career_buddy_lms/features/matching/presentation/providers/matching_providers.dart';
import 'package:career_buddy_lms/features/matching/presentation/screens/matching_exercise_screen.dart';
import 'package:career_buddy_lms/features/matching/presentation/widgets/matching_item_tile.dart';
import 'package:career_buddy_lms/features/auth/domain/entities/auth_user.dart';
import 'package:career_buddy_lms/features/auth/domain/repositories/auth_repository.dart';
import 'package:career_buddy_lms/features/auth/domain/entities/student_registration_data.dart';
import 'package:career_buddy_lms/features/auth/presentation/providers/auth_providers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

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

class _FakeMatchingExerciseRepository implements MatchingExerciseRepository {
  _FakeMatchingExerciseRepository({this.getResult, this.submitResult});

  Result<MatchingExercise>? getResult;
  Result<MatchingSubmissionResult>? submitResult;

  @override
  Future<Result<MatchingExercise>> getMatchingExercise(int exerciseId, {required String title, required int order}) async =>
      getResult!;

  @override
  Future<Result<MatchingSubmissionResult>> submitMatchingExercise(
    int exerciseId, {
    required int score,
    required int maxScore,
    required Map<int, int> matches,
  }) async => submitResult!;
}

MatchingExercise _exercise({int pairCount = 2}) => MatchingExercise(
  id: 7,
  title: 'Abbreviations',
  order: 1,
  pairs: List.generate(
    pairCount,
    (i) => MatchingPair(position: i + 1, leftText: 'Left ${i + 1}', rightText: 'Right ${i + 1}'),
  ),
);

Future<void> _pump(WidgetTester tester, MatchingExerciseRepository repo, {MatchingRouteArgs? args}) async {
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        authRepositoryProvider.overrideWithValue(_FakeAuthRepository()),
        matchingExerciseRepositoryProvider.overrideWithValue(repo),
      ],
      child: MaterialApp(
        home: MatchingExerciseScreen(
          exerciseId: 7,
          args: args ?? const MatchingRouteArgs(title: 'Abbreviations', order: 1, activityId: 12, subActivityId: 34),
        ),
      ),
    ),
  );
  for (var i = 0; i < 5; i++) {
    await tester.pump();
  }
}

void main() {
  testWidgets('shows both columns of the loaded exercise, Check Matches disabled until every pair is matched', (
    tester,
  ) async {
    await _pump(tester, _FakeMatchingExerciseRepository(getResult: Success(_exercise())));

    expect(find.text('Left 1'), findsOneWidget);
    expect(find.text('Left 2'), findsOneWidget);
    expect(find.text('Right 1'), findsOneWidget);
    expect(find.text('Right 2'), findsOneWidget);

    final checkButton = tester.widget<ElevatedButton>(find.widgetWithText(ElevatedButton, 'Check Matches'));
    expect(checkButton.onPressed, isNull);
    expect(tester.takeException(), isNull);
  });

  testWidgets('tapping a left item then its matching right item pairs them and enables submit once complete', (
    tester,
  ) async {
    await _pump(tester, _FakeMatchingExerciseRepository(getResult: Success(_exercise())));

    await tester.tap(find.text('Left 1'));
    await tester.pump();
    await tester.tap(find.text('Right 1'));
    await tester.pump();
    await tester.tap(find.text('Left 2'));
    await tester.pump();
    await tester.tap(find.text('Right 2'));
    await tester.pump();

    final checkButton = tester.widget<ElevatedButton>(find.widgetWithText(ElevatedButton, 'Check Matches'));
    expect(checkButton.onPressed, isNotNull);
  });

  testWidgets('submitting shows the recolored review grid and the server-computed score', (tester) async {
    const result = MatchingSubmissionResult(exerciseId: 7, score: 2, maxScore: 2, percentage: 100, attemptNumber: 1);
    await _pump(
      tester,
      _FakeMatchingExerciseRepository(getResult: Success(_exercise()), submitResult: const Success(result)),
    );

    await tester.tap(find.text('Left 1'));
    await tester.pump();
    await tester.tap(find.text('Right 1'));
    await tester.pump();
    await tester.tap(find.text('Left 2'));
    await tester.pump();
    await tester.tap(find.text('Right 2'));
    await tester.pump();
    await tester.tap(find.text('Check Matches'));
    for (var i = 0; i < 5; i++) {
      await tester.pump();
    }

    expect(find.text('2 / 2'), findsOneWidget);
    expect(find.text('100%'), findsOneWidget);
    // Both pairs were correct — every review tile should be in the
    // "correct" visual state, not "wrong".
    final tiles = tester.widgetList<MatchingItemTile>(find.byType(MatchingItemTile));
    expect(tiles.every((t) => t.state == MatchItemVisualState.correct), isTrue);
    expect(tester.takeException(), isNull);
  });

  testWidgets('shows a retryable error view for a load failure', (tester) async {
    await _pump(tester, _FakeMatchingExerciseRepository(getResult: const Failed(NotFoundFailure())));

    expect(find.text(const NotFoundFailure().message), findsOneWidget);
    expect(find.text('Retry'), findsOneWidget);
  });

  testWidgets(
    "'Back to Sub-Activity' pops back onto the already-loaded sub-activity screen underneath, rather than "
    'navigating via a route that would require an activityId this screen never has',
    (tester) async {
      const result = MatchingSubmissionResult(exerciseId: 7, score: 2, maxScore: 2, percentage: 100, attemptNumber: 1);
      final repo = _FakeMatchingExerciseRepository(getResult: Success(_exercise()), submitResult: const Success(result));
      final navigatorKey = GlobalKey<NavigatorState>();

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            authRepositoryProvider.overrideWithValue(_FakeAuthRepository()),
            matchingExerciseRepositoryProvider.overrideWithValue(repo),
          ],
          child: MaterialApp(
            navigatorKey: navigatorKey,
            home: Builder(
              builder: (context) => Scaffold(
                body: Center(
                  child: ElevatedButton(
                    onPressed: () => Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => const MatchingExerciseScreen(
                          exerciseId: 7,
                          args: MatchingRouteArgs(title: 'Abbreviations', order: 1, activityId: 12, subActivityId: 34),
                        ),
                      ),
                    ),
                    child: const Text('Open Exercise'),
                  ),
                ),
              ),
            ),
          ),
        ),
      );

      await tester.tap(find.text('Open Exercise'));
      await tester.pump();
      // Lets the push route's transition animation finish before interacting
      // — the default MaterialPageRoute transition runs ~300ms.
      await tester.pump(const Duration(milliseconds: 350));
      for (var i = 0; i < 5; i++) {
        await tester.pump();
      }

      await tester.tap(find.text('Left 1'));
      await tester.pump();
      await tester.tap(find.text('Right 1'));
      await tester.pump();
      await tester.tap(find.text('Left 2'));
      await tester.pump();
      await tester.tap(find.text('Right 2'));
      await tester.pump();
      await tester.tap(find.text('Check Matches'));
      for (var i = 0; i < 5; i++) {
        await tester.pump();
      }

      // The result view is a ListView — "Back to Sub-Activity" sits below
      // the review cards and may not be built/on-screen yet at this height.
      await tester.dragUntilVisible(
        find.text('Back to Sub-Activity'),
        find.byType(ListView),
        const Offset(0, -200),
      );
      await tester.tap(find.text('Back to Sub-Activity'));
      // The pop's reverse transition plus the scroll view's post-drag
      // ballistic settle both need real time to finish before the popped
      // route is actually removed from the tree — a short fixed pump isn't
      // enough here (confirmed empirically), so this pumps generously
      // rather than using `pumpAndSettle`, which never completes against
      // `BuddyChatbotOverlay`'s own perpetual float animation.
      for (var i = 0; i < 40; i++) {
        await tester.pump(const Duration(milliseconds: 50));
      }

      expect(find.text('Open Exercise'), findsOneWidget);
      expect(find.byType(MatchingExerciseScreen), findsNothing);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('renders without overflow at 320/375/430px and tablet width', (tester) async {
    for (final size in [const Size(320, 800), const Size(375, 800), const Size(430, 900), const Size(1024, 1366)]) {
      tester.view.physicalSize = size;
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await _pump(
        tester,
        _FakeMatchingExerciseRepository(
          getResult: Success(
            MatchingExercise(
              id: 7,
              title: 'A Genuinely Long Matching Exercise Title',
              order: 1,
              pairs: const [
                MatchingPair(position: 1, leftText: 'A fairly long left-column term here', rightText: 'A fairly long matching right-column definition here'),
                MatchingPair(position: 2, leftText: 'FYI', rightText: 'For your information, a longer definition'),
                MatchingPair(position: 3, leftText: 'ASAP', rightText: 'As soon as possible'),
              ],
            ),
          ),
        ),
      );

      expect(tester.takeException(), isNull);
    }
  });
}
