import 'package:career_buddy_lms/features/dashboard/domain/entities/dashboard_stats.dart';
import 'package:career_buddy_lms/features/dashboard/presentation/widgets/dashboard_stats_row.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  Widget wrap(Widget child) => MaterialApp(home: Scaffold(body: child));

  const stats = DashboardStats(completedCount: 3, inProgressCount: 2, totalActivities: 20, totalScore: 145);

  // `isTablet()` reads the ambient `MediaQuery` size, not any local
  // `SizedBox` constraint — so the test window itself must be set to a
  // phone width for the phone (2-column) layout to actually apply,
  // matching how `DashboardScreen` always sizes this widget consistently
  // with the real device width in production.
  void setPhoneWindow(WidgetTester tester) {
    tester.view.physicalSize = const Size(400, 800);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
  }

  testWidgets('every stat tile renders the same navy gradient, not 4 different colors', (tester) async {
    setPhoneWindow(tester);
    await tester.pumpWidget(wrap(const DashboardStatsRow(stats: stats)));

    final decorations = tester
        .widgetList<Container>(find.byType(Container))
        .map((c) => c.decoration)
        .whereType<BoxDecoration>()
        .where((d) => d.gradient is LinearGradient)
        .toList();

    expect(decorations, hasLength(4));
    for (final decoration in decorations) {
      final gradient = decoration.gradient! as LinearGradient;
      expect(gradient.colors, [const Color(0xFF14213D), const Color(0xFF0B1526)]);
    }
  });

  testWidgets('every tile\'s icon is gold, matching the web\'s overridden .stat-card-icon', (tester) async {
    setPhoneWindow(tester);
    await tester.pumpWidget(wrap(const DashboardStatsRow(stats: stats)));

    final icons = tester.widgetList<Icon>(find.byType(Icon));
    expect(icons, hasLength(4));
    for (final icon in icons) {
      expect(icon.color, const Color(0xFFFCA311));
    }
  });

  testWidgets('shows every stat value and label', (tester) async {
    setPhoneWindow(tester);
    await tester.pumpWidget(wrap(const DashboardStatsRow(stats: stats)));

    expect(find.text('20'), findsOneWidget);
    expect(find.text('3'), findsOneWidget);
    expect(find.text('2'), findsOneWidget);
    expect(find.text('145'), findsOneWidget);
    expect(find.text('Total Activities'), findsOneWidget);
    expect(find.text('Completed'), findsOneWidget);
    expect(find.text('In Progress'), findsOneWidget);
    expect(find.text('Total Score'), findsOneWidget);
  });
}
