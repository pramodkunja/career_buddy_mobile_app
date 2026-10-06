import 'package:career_buddy_lms/features/activities/domain/entities/exercise_attempt.dart';
import 'package:career_buddy_lms/features/activities/domain/entities/exercise_summary.dart';
import 'package:career_buddy_lms/features/activities/presentation/widgets/exercise_tile.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

ExerciseSummary _exercise({
  String type = 'mcq',
  String typeDisplay = 'Multiple Choice',
  ExerciseAttempt? lastAttempt,
}) => ExerciseSummary(
  id: 1,
  title: 'Vocabulary Quiz',
  exerciseType: type,
  exerciseTypeDisplay: typeDisplay,
  order: 1,
  lastAttempt: lastAttempt,
);

void main() {
  Widget wrap(Widget child) => MaterialApp(home: Scaffold(body: child));

  testWidgets('an mcq tile shows "Start" and is tappable', (tester) async {
    var tapped = false;
    await tester.pumpWidget(wrap(ExerciseTile(exercise: _exercise(), onTap: () => tapped = true)));

    expect(find.text('Start'), findsOneWidget);
    expect(find.text('Not available in the app yet.'), findsNothing);

    await tester.tap(find.byType(InkWell));
    expect(tapped, isTrue);
  });

  testWidgets('W008 — a matching tile shows "Start" and is tappable, with no module flag needed', (tester) async {
    var tapped = false;
    await tester.pumpWidget(
      wrap(
        ExerciseTile(
          exercise: _exercise(type: 'matching', typeDisplay: 'Matching'),
          onTap: () => tapped = true,
        ),
      ),
    );

    expect(find.text('Start'), findsOneWidget);
    expect(find.text('Not available in the app yet.'), findsNothing);

    await tester.tap(find.byType(InkWell));
    expect(tapped, isTrue);
  });

  testWidgets('W009 — a bingo tile shows "Start" and is tappable, with no module flag needed', (tester) async {
    var tapped = false;
    await tester.pumpWidget(
      wrap(
        ExerciseTile(
          exercise: _exercise(type: 'bingo', typeDisplay: 'Vocabulary Bingo'),
          onTap: () => tapped = true,
        ),
      ),
    );

    expect(find.text('Start'), findsOneWidget);
    expect(find.text('Not available in the app yet.'), findsNothing);

    await tester.tap(find.byType(InkWell));
    expect(tapped, isTrue);
  });

  testWidgets('W010 — a fill_blank tile shows "Start" and is tappable, with no module flag needed', (tester) async {
    var tapped = false;
    await tester.pumpWidget(
      wrap(
        ExerciseTile(
          exercise: _exercise(type: 'fill_blank', typeDisplay: 'Fill in the Blank'),
          onTap: () => tapped = true,
        ),
      ),
    );

    expect(find.text('Start'), findsOneWidget);
    expect(find.text('Not available in the app yet.'), findsNothing);

    await tester.tap(find.byType(InkWell));
    expect(tapped, isTrue);
  });

  testWidgets('a timer tile shows "Start" and is tappable, with no module flag needed (Timer)', (tester) async {
    var tapped = false;
    await tester.pumpWidget(
      wrap(
        ExerciseTile(
          exercise: _exercise(type: 'timer', typeDisplay: 'Timed Activity'),
          onTap: () => tapped = true,
        ),
      ),
    );

    expect(find.text('Start'), findsOneWidget);
    expect(find.text('Not available in the app yet.'), findsNothing);

    await tester.tap(find.byType(InkWell));
    expect(tapped, isTrue);
  });

  testWidgets('a non-mcq exercise type genuinely unimplemented (e.g. Ordering) shows "Not available" but is STILL tappable', (
    tester,
  ) async {
    var tapped = false;
    await tester.pumpWidget(
      wrap(
        ExerciseTile(
          exercise: _exercise(type: 'ordering', typeDisplay: 'Ordering'),
          onTap: () => tapped = true,
        ),
      ),
    );

    expect(find.text('Not available in the app yet.'), findsOneWidget);
    expect(find.text('Start'), findsNothing);

    // Tappable so the caller can explain *why* (see
    // SubActivityDetailScreen), not a dead end.
    await tester.tap(find.byType(InkWell));
    expect(tapped, isTrue);
  });

  testWidgets('W014 — a non-mcq exercise under a Speaking-module Activity still shows "Start" via isSpeakingModule', (
    tester,
  ) async {
    var tapped = false;
    await tester.pumpWidget(
      wrap(
        ExerciseTile(
          exercise: _exercise(type: 'speaking', typeDisplay: 'Speaking Practice'),
          isSpeakingModule: true,
          onTap: () => tapped = true,
        ),
      ),
    );

    expect(find.text('Start'), findsOneWidget);
    expect(find.text('Not available in the app yet.'), findsNothing);

    await tester.tap(find.byType(InkWell));
    expect(tapped, isTrue);
  });

  testWidgets('the same non-mcq exercise type shows "Not available" when isSpeakingModule is false (default)', (
    tester,
  ) async {
    await tester.pumpWidget(
      wrap(ExerciseTile(exercise: _exercise(type: 'speaking', typeDisplay: 'Speaking Practice'), onTap: () {})),
    );

    expect(find.text('Not available in the app yet.'), findsOneWidget);
    expect(find.text('Start'), findsNothing);
  });

  testWidgets('W017 — a non-mcq exercise under a Reading-module Activity still shows "Start" via isReadingModule', (
    tester,
  ) async {
    var tapped = false;
    await tester.pumpWidget(
      wrap(
        ExerciseTile(
          exercise: _exercise(type: 'reading', typeDisplay: 'Reading Practice'),
          isReadingModule: true,
          onTap: () => tapped = true,
        ),
      ),
    );

    expect(find.text('Start'), findsOneWidget);
    expect(find.text('Not available in the app yet.'), findsNothing);

    await tester.tap(find.byType(InkWell));
    expect(tapped, isTrue);
  });

  testWidgets('the same non-mcq exercise type shows "Not available" when isReadingModule is false (default)', (
    tester,
  ) async {
    await tester.pumpWidget(
      wrap(ExerciseTile(exercise: _exercise(type: 'reading', typeDisplay: 'Reading Practice'), onTap: () {})),
    );

    expect(find.text('Not available in the app yet.'), findsOneWidget);
    expect(find.text('Start'), findsNothing);
  });

  testWidgets('W016 — a non-mcq exercise under a Listening-module Activity still shows "Start" via isListeningModule', (
    tester,
  ) async {
    var tapped = false;
    await tester.pumpWidget(
      wrap(
        ExerciseTile(
          exercise: _exercise(type: 'listening', typeDisplay: 'Listening Practice'),
          isListeningModule: true,
          onTap: () => tapped = true,
        ),
      ),
    );

    expect(find.text('Start'), findsOneWidget);
    expect(find.text('Not available in the app yet.'), findsNothing);

    await tester.tap(find.byType(InkWell));
    expect(tapped, isTrue);
  });

  testWidgets('the same non-mcq exercise type shows "Not available" when isListeningModule is false (default)', (
    tester,
  ) async {
    await tester.pumpWidget(
      wrap(ExerciseTile(exercise: _exercise(type: 'listening', typeDisplay: 'Listening Practice'), onTap: () {})),
    );

    expect(find.text('Not available in the app yet.'), findsOneWidget);
    expect(find.text('Start'), findsNothing);
  });

  testWidgets('W015 — a non-mcq exercise under a Writing-module Activity still shows "Start" via isWritingModule', (
    tester,
  ) async {
    var tapped = false;
    await tester.pumpWidget(
      wrap(
        ExerciseTile(
          exercise: _exercise(type: 'writing', typeDisplay: 'Writing Practice'),
          isWritingModule: true,
          onTap: () => tapped = true,
        ),
      ),
    );

    expect(find.text('Start'), findsOneWidget);
    expect(find.text('Not available in the app yet.'), findsNothing);

    await tester.tap(find.byType(InkWell));
    expect(tapped, isTrue);
  });

  testWidgets('a non-mcq exercise under a non-Writing-module Activity shows "Not available" when isWritingModule is false (default)', (
    tester,
  ) async {
    // `type: 'ordering'` here, not `'writing'`/`'timer'` — as of W013,
    // `exercise_type == 'writing'` always has a working screen
    // (`GenericWritingScreen`) regardless of `isWritingModule`, and as of
    // Timer, `exercise_type == 'timer'` always has a working screen
    // (`TimerExerciseScreen`) too, so neither still demonstrates this case.
    // `ordering` remains genuinely unimplemented.
    await tester.pumpWidget(
      wrap(ExerciseTile(exercise: _exercise(type: 'ordering', typeDisplay: 'Ordering'), onTap: () {})),
    );

    expect(find.text('Not available in the app yet.'), findsOneWidget);
    expect(find.text('Start'), findsNothing);
  });

  testWidgets('a "writing" exercise_type exercise always shows "Start", independent of isWritingModule (W013 — Generic Writing)', (
    tester,
  ) async {
    await tester.pumpWidget(
      wrap(ExerciseTile(exercise: _exercise(type: 'writing', typeDisplay: 'Writing Submission'), onTap: () {})),
    );

    expect(find.text('Start'), findsOneWidget);
    expect(find.text('Not available in the app yet.'), findsNothing);
  });

  testWidgets('shows the last attempt\'s score and percentage when one exists', (tester) async {
    await tester.pumpWidget(
      wrap(
        ExerciseTile(
          exercise: _exercise(
            lastAttempt: ExerciseAttempt(
              score: 7,
              maxScore: 10,
              percentage: 70,
              attemptNumber: 1,
              completedAt: DateTime(2026, 1, 15),
            ),
          ),
          onTap: () {},
        ),
      ),
    );

    expect(find.text('Last score: 7/10'), findsOneWidget);
    expect(find.text('70%'), findsOneWidget);
  });
}
