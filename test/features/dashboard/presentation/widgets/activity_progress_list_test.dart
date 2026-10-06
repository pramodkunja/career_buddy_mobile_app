import 'package:career_buddy_lms/features/dashboard/domain/entities/activity_progress.dart';
import 'package:career_buddy_lms/features/dashboard/presentation/widgets/activity_progress_list.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  Widget wrap(Widget child) => MaterialApp(home: Scaffold(body: child));

  testWidgets('shows the web dashboard\'s empty-state copy when there are no activities', (tester) async {
    await tester.pumpWidget(wrap(const ActivityProgressList(activities: [])));

    expect(find.text('No activities started yet.'), findsOneWidget);
  });

  testWidgets('the empty state\'s Start Learning button fires onStartLearning, matching the web\'s CTA', (
    tester,
  ) async {
    var tapped = false;
    await tester.pumpWidget(
      wrap(ActivityProgressList(activities: const [], onStartLearning: () => tapped = true)),
    );

    await tester.tap(find.text('Start Learning'));
    expect(tapped, isTrue);
  });

  testWidgets('renders a tile with title and completion percentage for each activity', (tester) async {
    await tester.pumpWidget(
      wrap(
        const ActivityProgressList(
          activities: [
            ActivityProgress(
              activityId: 1,
              title: 'Business Vocabulary',
              completionRate: 60,
              completedSubActivities: 3,
              totalSubActivities: 5,
            ),
          ],
        ),
      ),
    );

    expect(find.text('Business Vocabulary'), findsOneWidget);
    expect(find.textContaining('60%'), findsOneWidget);
    expect(find.byType(LinearProgressIndicator), findsOneWidget);
    // No startedAt on this activity, so the web's conditional "Started ..."
    // badge (`{% if item.started_at %}`) must not render.
    expect(find.textContaining('Started'), findsNothing);
  });

  testWidgets('shows a "Started {date}" badge only when startedAt is present, matching the web\'s conditional', (
    tester,
  ) async {
    await tester.pumpWidget(
      wrap(
        ActivityProgressList(
          activities: [
            ActivityProgress(
              activityId: 1,
              title: 'Business Vocabulary',
              completionRate: 60,
              completedSubActivities: 3,
              totalSubActivities: 5,
              startedAt: DateTime(2026, 1, 15),
            ),
          ],
        ),
      ),
    );

    expect(find.text('Started Jan 15, 2026'), findsOneWidget);
  });
}
