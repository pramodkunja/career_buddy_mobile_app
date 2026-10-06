import 'package:career_buddy_lms/features/mock_tests/presentation/widgets/mock_exam_colors.dart';
import 'package:career_buddy_lms/features/mock_tests/presentation/widgets/mock_test_timer_badge.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  Widget wrap(Widget child) => MaterialApp(home: Scaffold(body: child));

  Container containerFor(WidgetTester tester) =>
      tester.widget<Container>(find.descendant(of: find.byType(MockTestTimerBadge), matching: find.byType(Container)));

  testWidgets('shows MM:SS and a translucent white/gold-border pill above the warning threshold', (tester) async {
    await tester.pumpWidget(wrap(const MockTestTimerBadge(remainingSeconds: 600)));

    expect(find.text('10:00'), findsOneWidget);
    final decoration = containerFor(tester).decoration! as BoxDecoration;
    expect(decoration.color, isNot(MockExamColors.danger));
    expect(decoration.border, isNotNull);
  });

  testWidgets('switches to a solid red fill at the 300-second warning threshold', (tester) async {
    await tester.pumpWidget(wrap(const MockTestTimerBadge(remainingSeconds: 300)));

    final decoration = containerFor(tester).decoration! as BoxDecoration;
    expect(decoration.color, MockExamColors.danger);
    expect(decoration.border, isNull);
  });

  testWidgets('clamps negative remaining time to 00:00', (tester) async {
    await tester.pumpWidget(wrap(const MockTestTimerBadge(remainingSeconds: -5)));

    expect(find.text('00:00'), findsOneWidget);
  });
}
