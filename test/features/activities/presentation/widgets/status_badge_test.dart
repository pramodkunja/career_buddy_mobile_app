import 'package:career_buddy_lms/features/activities/domain/entities/sub_activity_status.dart';
import 'package:career_buddy_lms/features/activities/presentation/widgets/status_badge.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  Widget wrap(Widget child) => MaterialApp(home: Scaffold(body: child));

  Container containerFor(WidgetTester tester) =>
      tester.widget<Container>(find.descendant(of: find.byType(StatusBadge), matching: find.byType(Container)));

  testWidgets('shows "Completed" with the web\'s exact green pastel colors', (tester) async {
    await tester.pumpWidget(wrap(const StatusBadge(status: SubActivityStatus.completed)));

    expect(find.text('Completed'), findsOneWidget);
    final decoration = containerFor(tester).decoration! as BoxDecoration;
    expect(decoration.color, const Color(0xFFDCFCE7));
    final text = tester.widget<Text>(find.text('Completed'));
    expect(text.style?.color, const Color(0xFF166534));
  });

  testWidgets('shows "In Progress" with the web\'s exact blue pastel colors', (tester) async {
    await tester.pumpWidget(wrap(const StatusBadge(status: SubActivityStatus.inProgress)));

    expect(find.text('In Progress'), findsOneWidget);
    final decoration = containerFor(tester).decoration! as BoxDecoration;
    expect(decoration.color, const Color(0xFFDBEAFE));
    final text = tester.widget<Text>(find.text('In Progress'));
    expect(text.style?.color, const Color(0xFF1E40AF));
  });

  testWidgets('shows "Not Started" with the web\'s exact slate pastel colors', (tester) async {
    await tester.pumpWidget(wrap(const StatusBadge(status: SubActivityStatus.notStarted)));

    expect(find.text('Not Started'), findsOneWidget);
    final decoration = containerFor(tester).decoration! as BoxDecoration;
    expect(decoration.color, const Color(0xFFF1F5F9));
    final text = tester.widget<Text>(find.text('Not Started'));
    expect(text.style?.color, const Color(0xFF64748B));
  });

  testWidgets('renders as a fully-rounded pill, matching the web\'s 999px badge radius', (tester) async {
    await tester.pumpWidget(wrap(const StatusBadge(status: SubActivityStatus.completed)));

    final decoration = containerFor(tester).decoration! as BoxDecoration;
    expect(decoration.borderRadius, BorderRadius.circular(999));
  });
}
