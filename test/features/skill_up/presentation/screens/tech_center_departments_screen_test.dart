import 'package:career_buddy_lms/app/router/route_paths.dart';
import 'package:career_buddy_lms/features/skill_up/data/tech_center_catalog.g.dart';
import 'package:career_buddy_lms/features/skill_up/domain/entities/tech_center_catalog.dart';
import 'package:career_buddy_lms/features/skill_up/presentation/screens/tech_center_departments_screen.dart';
import 'package:career_buddy_lms/features/skill_up/presentation/screens/tech_center_roles_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

GoRouter _router() => GoRouter(
  initialLocation: RoutePaths.techCenterDepartments,
  routes: [
    GoRoute(
      path: RoutePaths.techCenterDepartments,
      builder: (context, state) => const TechCenterDepartmentsScreen(),
    ),
    GoRoute(
      path: RoutePaths.techCenterRoles,
      builder: (context, state) => TechCenterRolesScreen(department: state.extra! as TechCenterDepartment),
    ),
  ],
);

Future<void> _pump(WidgetTester tester) async {
  // All 10 real departments (plus the Development/QA roles screens' own up
  // to 11 roles) don't fit `flutter test`'s own default, far-shorter-than-
  // any-real-phone window — a tall surface avoids `ListView`'s lazy
  // virtualization skipping items this test needs to find off the default
  // viewport, the same reasoning used elsewhere in this app's own tests.
  await tester.binding.setSurfaceSize(const Size(400, 2000));
  addTearDown(() => tester.binding.setSurfaceSize(null));
  await tester.pumpWidget(MaterialApp.router(routerConfig: _router()));
  await tester.pumpAndSettle();
}

void main() {
  group('TechCenterDepartmentsScreen', () {
    testWidgets('lists every real department with its role count, and the department/role count copy', (
      tester,
    ) async {
      await _pump(tester);

      for (final department in kTechCenterDepartments) {
        expect(find.text(department.title), findsOneWidget, reason: '"${department.title}" should be listed');
        expect(find.text('${department.roles.length} roles'), findsWidgets);
      }
      expect(
        find.textContaining('${kTechCenterDepartments.length} departments'),
        findsOneWidget,
      );
    });

    testWidgets('tapping a department navigates to its own roles screen', (tester) async {
      await _pump(tester);
      final development = kTechCenterDepartments.firstWhere((d) => d.slug == 'development');

      await tester.tap(find.text(development.title));
      await tester.pumpAndSettle();

      expect(find.text(development.title), findsOneWidget);
      for (final role in development.roles) {
        expect(find.text(role.title), findsOneWidget, reason: '"${role.title}" should be listed under Development');
      }
    });

    testWidgets('each distinct department navigates to a screen listing only its own roles, not another '
        'department\'s (catches a mismatched extra/department reference)', (tester) async {
      await _pump(tester);
      final qa = kTechCenterDepartments.firstWhere((d) => d.slug == 'quality-assurance-qa-testing');
      final development = kTechCenterDepartments.firstWhere((d) => d.slug == 'development');

      await tester.tap(find.text(qa.title));
      await tester.pumpAndSettle();

      for (final role in qa.roles) {
        expect(find.text(role.title), findsOneWidget);
      }
      // "Software Developer" (a Development-only role) must not leak in.
      expect(find.text(development.roles.first.title), findsNothing);
    });

    testWidgets('system back from a roles screen returns to the departments list', (tester) async {
      await _pump(tester);
      final development = kTechCenterDepartments.firstWhere((d) => d.slug == 'development');

      await tester.tap(find.text(development.title));
      await tester.pumpAndSettle();
      expect(find.text(development.roles.first.title), findsOneWidget);

      await tester.tap(find.byTooltip('Back'));
      await tester.pumpAndSettle();

      expect(find.text('Tech Center'), findsOneWidget);
      for (final department in kTechCenterDepartments) {
        expect(find.text(department.title), findsOneWidget);
      }
    });
  });
}
