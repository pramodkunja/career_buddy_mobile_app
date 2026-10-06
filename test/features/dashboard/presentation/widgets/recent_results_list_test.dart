import 'package:career_buddy_lms/app/theme/app_colors.dart';
import 'package:career_buddy_lms/features/dashboard/domain/entities/recent_result.dart';
import 'package:career_buddy_lms/features/dashboard/presentation/widgets/recent_results_list.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  Widget wrap(Widget child) => MaterialApp(home: Scaffold(body: child));

  testWidgets('shows the web dashboard\'s empty-state copy when there are no results', (tester) async {
    await tester.pumpWidget(wrap(const RecentResultsList(results: [])));

    expect(find.text('No exercises completed yet.'), findsOneWidget);
  });

  testWidgets('renders each result\'s title and score', (tester) async {
    await tester.pumpWidget(
      wrap(
        RecentResultsList(
          results: [
            RecentResult(
              title: 'Negotiation Quiz',
              activityName: 'Negotiation',
              score: 8,
              maxScore: 10,
              percentage: 80,
              date: DateTime(2026, 9, 15),
            ),
          ],
        ),
      ),
    );

    expect(find.text('Negotiation Quiz'), findsOneWidget);
    expect(find.text('8/10'), findsOneWidget);
  });

  Color scoreBadgeColor(WidgetTester tester, String scoreLabel) {
    final container = tester.widget<Container>(
      find.ancestor(of: find.text(scoreLabel), matching: find.byType(Container)).first,
    );
    return (container.decoration as BoxDecoration).color!;
  }

  testWidgets('color-codes the score badge by percentage tier, matching the web\'s score-high/mid/low', (
    tester,
  ) async {
    RecentResult result({required num percentage}) => RecentResult(
      title: 'Result',
      activityName: 'Activity',
      score: 1,
      maxScore: 1,
      percentage: percentage.toDouble(),
      date: DateTime(2026, 9, 15),
    );

    await tester.pumpWidget(wrap(RecentResultsList(results: [result(percentage: 80)])));
    final high = scoreBadgeColor(tester, '1/1');

    await tester.pumpWidget(wrap(RecentResultsList(results: [result(percentage: 50)])));
    final mid = scoreBadgeColor(tester, '1/1');

    await tester.pumpWidget(wrap(RecentResultsList(results: [result(percentage: 49)])));
    final low = scoreBadgeColor(tester, '1/1');

    // `.score-mid{background:var(--warning)}` — the web's post-rebrand
    // `--warning` is gold `#FCA311`, not the app's own (pre-rebrand,
    // amber) `AppColors.warning` token — confirmed by reading the
    // override block directly rather than assumed.
    expect(high.withValues(alpha: 1), AppColors.success.withValues(alpha: 1));
    expect(mid.withValues(alpha: 1), const Color(0xFFFCA311));
    expect(low.withValues(alpha: 1), AppColors.danger.withValues(alpha: 1));
  });

  testWidgets('truncates a long title and activity name to one line instead of wrapping/overflowing', (
    tester,
  ) async {
    await tester.pumpWidget(
      wrap(
        RecentResultsList(
          results: [
            RecentResult(
              title: 'A genuinely very long exercise result title that would otherwise wrap onto multiple lines',
              activityName: 'A similarly long activity name that would also wrap without truncation',
              score: 1,
              maxScore: 1,
              percentage: 100,
              date: DateTime(2026, 9, 15),
            ),
          ],
        ),
      ),
    );

    expect(tester.takeException(), isNull);
  });
}
