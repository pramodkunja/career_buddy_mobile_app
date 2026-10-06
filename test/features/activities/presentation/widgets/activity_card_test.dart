import 'package:career_buddy_lms/app/theme/app_colors.dart';
import 'package:career_buddy_lms/features/activities/domain/entities/activity_summary.dart';
import 'package:career_buddy_lms/features/activities/presentation/widgets/activity_card.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

ActivitySummary _summary({
  bool isLocked = false,
  int completionRate = 0,
  bool isCompleted = false,
  String title = 'Business Vocabulary Building Games and a Very Long Title That Should Not Overflow',
}) => ActivitySummary(
  id: 1,
  title: title,
  description: 'desc',
  category: 'vocabulary',
  categoryDisplay: 'Vocabulary & Idioms',
  level: 'Intermediate',
  duration: '30 min',
  isLocked: isLocked,
  completionRate: completionRate,
  isCompleted: isCompleted,
);

void main() {
  Widget wrap(Widget child) => MaterialApp(home: Scaffold(body: SizedBox(width: 320, child: child)));

  testWidgets('shows "Start Activity" for an unstarted, unlocked activity', (tester) async {
    await tester.pumpWidget(wrap(ActivityCard(activity: _summary(), onTap: () {})));

    expect(find.text('Start Activity'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('shows "Continue" once progress exists, and a progress bar', (tester) async {
    await tester.pumpWidget(wrap(ActivityCard(activity: _summary(completionRate: 40), onTap: () {})));

    expect(find.text('Continue'), findsOneWidget);
    expect(find.text('40%'), findsOneWidget);
    expect(find.byType(LinearProgressIndicator), findsOneWidget);
  });

  testWidgets('shows "Review Activity" and a check icon once completed', (tester) async {
    await tester.pumpWidget(
      wrap(ActivityCard(activity: _summary(completionRate: 100, isCompleted: true), onTap: () {})),
    );

    expect(find.text('Review Activity'), findsOneWidget);
    expect(find.byIcon(Icons.check_circle), findsOneWidget);
  });

  testWidgets(
    'shows a real, full-width, navy "Locked 🔒" button (not muted text) for an inaccessible activity, no overflow',
    (tester) async {
      // `list.html:135-139`: `<button class="btn btn-secondary w-100" ...
      // style="opacity:.65">`, with a lock icon — a real, dimmed navy
      // button, not plain muted text.
      await tester.pumpWidget(wrap(ActivityCard(activity: _summary(isLocked: true), onTap: () {})));

      expect(find.text('Locked 🔒'), findsOneWidget);
      // One lock icon in the card's title row, one inside the CTA button.
      expect(find.byIcon(Icons.lock_outline), findsNWidgets(2));
      final button = tester.widget<ElevatedButton>(find.byType(ElevatedButton));
      expect(button.style?.backgroundColor?.resolve({}), AppColors.primary);
      final opacity = tester.widget<Opacity>(find.byType(Opacity));
      expect(opacity.opacity, 0.65);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('tapping invokes onTap, including on the CTA button itself when locked', (tester) async {
    var tapped = false;
    await tester.pumpWidget(wrap(ActivityCard(activity: _summary(), onTap: () => tapped = true)));

    await tester.tap(find.byType(ActivityCard));
    expect(tapped, isTrue);

    tapped = false;
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pumpWidget(wrap(ActivityCard(activity: _summary(isLocked: true), onTap: () => tapped = true)));
    // `pointer-events:auto` (`list.html:137`) — the locked CTA button
    // itself still registers taps on the web, unlike a truly disabled
    // button.
    await tester.tap(find.byType(ElevatedButton));
    expect(tapped, isTrue);
  });

  testWidgets('the unlocked CTA is a real, full-width navy button matching .btn-primary\'s final color', (tester) async {
    await tester.pumpWidget(wrap(ActivityCard(activity: _summary(), onTap: () {})));

    expect(find.text('Start Activity'), findsOneWidget);
    expect(find.byIcon(Icons.arrow_forward), findsOneWidget);
    final button = tester.widget<ElevatedButton>(find.byType(ElevatedButton));
    // No explicit backgroundColor override here — this button relies on
    // `elevatedButtonTheme`'s own default, which must itself be navy
    // (`AppColors.primary`) for this to be correct; `style` is therefore
    // expected to be null (using the theme default), not a bespoke color.
    expect(button.style, isNull);
  });

  testWidgets('the level badge uses the web\'s exact purple pastel colors', (tester) async {
    await tester.pumpWidget(wrap(ActivityCard(activity: _summary(), onTap: () {})));

    final container = tester.widget<Container>(
      find.ancestor(of: find.text('Intermediate'), matching: find.byType(Container)).first,
    );
    final decoration = container.decoration! as BoxDecoration;
    expect(decoration.color, const Color(0xFFEDE9FE));
  });

  testWidgets('the category badge uses the web\'s exact slate pastel colors', (tester) async {
    await tester.pumpWidget(wrap(ActivityCard(activity: _summary(), onTap: () {})));

    final container = tester.widget<Container>(
      find.ancestor(of: find.text('Vocabulary & Idioms'), matching: find.byType(Container)).first,
    );
    final decoration = container.decoration! as BoxDecoration;
    expect(decoration.color, const Color(0xFFF1F5F9));
  });
}
