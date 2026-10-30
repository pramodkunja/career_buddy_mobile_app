import 'package:career_buddy_lms/app/router/route_paths.dart';
import 'package:career_buddy_lms/features/skill_up/domain/entities/tech_center_catalog.dart';
import 'package:career_buddy_lms/features/skill_up/domain/skill_up_lesson_url.dart';
import 'package:career_buddy_lms/features/skill_up/presentation/screens/tech_center_roles_screen.dart';
import 'package:career_buddy_lms/features/skill_up/presentation/skill_up_lesson_route_args.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

const _multiCourseRole = TechCenterRole(
  slug: 'software-developer',
  title: 'Software Developer',
  category: 'Product and Engineering',
  courses: [
    TechCenterCourse(
      title: 'Core Languages',
      relativePath:
          'TechCenter/development/software-developer/software_developer_core_languages.html',
    ),
    TechCenterCourse(
      title: 'Databases',
      relativePath:
          'TechCenter/development/software-developer/software_developer_databases.html',
    ),
  ],
);

const _singleCourseRole = TechCenterRole(
  slug: 'qa-lead-test-lead',
  title: 'QA Lead / Test Lead',
  category: 'Product and Engineering',
  courses: [
    TechCenterCourse(
      title: 'QA Lead / Test Lead',
      relativePath:
          'TechCenter/quality-assurance-qa-testing/qa-lead-test-lead/QA_Lead_Test_Lead.html',
    ),
  ],
);

const _department = TechCenterDepartment(
  slug: 'development',
  title: 'Development',
  roles: [_multiCourseRole, _singleCourseRole],
);

const _emptyDepartment = TechCenterDepartment(
  slug: 'empty-dept',
  title: 'Empty Department',
  roles: [],
);

/// Phase 77 — the real max case (confirmed against `kTechCenterDepartments`:
/// several roles have exactly 5 courses) combined with a long title, used to
/// reproduce a real overflow this phase found and fixed in
/// `TechCenterRoleSheet` on a short/landscape viewport.
const _fiveCourseRole = TechCenterRole(
  slug: 'vp-of-sales-marketing-chief-commercial-officer-cco',
  title: 'VP Sales & Marketing / Chief Commercial Officer (CCO)',
  category: 'Business and Support',
  courses: [
    TechCenterCourse(
      title: 'Revenue Strategy & GTM Ownership',
      relativePath: 'a/b/1.html',
    ),
    TechCenterCourse(
      title: 'Executive Leadership & Team Architecture',
      relativePath: 'a/b/2.html',
    ),
    TechCenterCourse(
      title: 'P&L & Financial Acumen',
      relativePath: 'a/b/3.html',
    ),
    TechCenterCourse(
      title: 'Commercial Deal Strategy',
      relativePath: 'a/b/4.html',
    ),
    TechCenterCourse(
      title: 'Board & Stakeholder Reporting',
      relativePath: 'a/b/5.html',
    ),
  ],
);

const _departmentWithFiveCourseRole = TechCenterDepartment(
  slug: 'sales-and-marketing',
  title: 'Sales and Marketing',
  roles: [_fiveCourseRole],
);

/// Phase 79 — 11 roles matches the real `devops-infrastructure`
/// department's own count (the largest of any real department, confirmed
/// in the generated catalog) — enough that the last role would sit well
/// below a typical phone-sized viewport if the list were lazily
/// virtualized (the exact `ListView`-virtualization gotcha this phase's
/// own `TechCenterRolesScreen` doc comment cites).
const _manyRolesDepartment = TechCenterDepartment(
  slug: 'many-roles',
  title: 'Many Roles Department',
  roles: [
    TechCenterRole(
      slug: 'role-1',
      title: 'Role 1',
      category: 'Product and Engineering',
      courses: [TechCenterCourse(title: 'Course', relativePath: 'a/b/1.html')],
    ),
    TechCenterRole(
      slug: 'role-2',
      title: 'Role 2',
      category: 'Product and Engineering',
      courses: [TechCenterCourse(title: 'Course', relativePath: 'a/b/2.html')],
    ),
    TechCenterRole(
      slug: 'role-3',
      title: 'Role 3',
      category: 'Product and Engineering',
      courses: [TechCenterCourse(title: 'Course', relativePath: 'a/b/3.html')],
    ),
    TechCenterRole(
      slug: 'role-4',
      title: 'Role 4',
      category: 'Product and Engineering',
      courses: [TechCenterCourse(title: 'Course', relativePath: 'a/b/4.html')],
    ),
    TechCenterRole(
      slug: 'role-5',
      title: 'Role 5',
      category: 'Product and Engineering',
      courses: [TechCenterCourse(title: 'Course', relativePath: 'a/b/5.html')],
    ),
    TechCenterRole(
      slug: 'role-6',
      title: 'Role 6',
      category: 'Product and Engineering',
      courses: [TechCenterCourse(title: 'Course', relativePath: 'a/b/6.html')],
    ),
    TechCenterRole(
      slug: 'role-7',
      title: 'Role 7',
      category: 'Product and Engineering',
      courses: [TechCenterCourse(title: 'Course', relativePath: 'a/b/7.html')],
    ),
    TechCenterRole(
      slug: 'role-8',
      title: 'Role 8',
      category: 'Product and Engineering',
      courses: [TechCenterCourse(title: 'Course', relativePath: 'a/b/8.html')],
    ),
    TechCenterRole(
      slug: 'role-9',
      title: 'Role 9',
      category: 'Product and Engineering',
      courses: [TechCenterCourse(title: 'Course', relativePath: 'a/b/9.html')],
    ),
    TechCenterRole(
      slug: 'role-10',
      title: 'Role 10',
      category: 'Product and Engineering',
      courses: [TechCenterCourse(title: 'Course', relativePath: 'a/b/10.html')],
    ),
    TechCenterRole(
      slug: 'role-11',
      title: 'Role 11',
      category: 'Product and Engineering',
      courses: [TechCenterCourse(title: 'Course', relativePath: 'a/b/11.html')],
    ),
  ],
);

GoRouter _router(
  TechCenterDepartment department, {
  String? highlightRoleSlug,
}) => GoRouter(
  initialLocation: RoutePaths.techCenterRoles,
  routes: [
    GoRoute(
      path: RoutePaths.techCenterRoles,
      builder: (context, state) => TechCenterRolesScreen(
        department: department,
        highlightRoleSlug: highlightRoleSlug,
      ),
    ),
    GoRoute(
      path: RoutePaths.skillUpLesson,
      builder: (context, state) {
        final args = state.extra! as SkillUpLessonRouteArgs;
        return Scaffold(body: Text('LESSON: ${args.title} | ${args.url}'));
      },
    ),
  ],
);

Future<void> _pump(
  WidgetTester tester, {
  TechCenterDepartment department = _department,
  String? highlightRoleSlug,
  Size surfaceSize = const Size(400, 700),
}) async {
  tester.view.physicalSize = surfaceSize;
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    MaterialApp.router(
      routerConfig: _router(department, highlightRoleSlug: highlightRoleSlug),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  group('TechCenterRolesScreen', () {
    testWidgets('lists every role with its category and course count', (
      tester,
    ) async {
      await _pump(tester);

      expect(find.text('Software Developer'), findsOneWidget);
      expect(find.text('2 courses'), findsOneWidget);
      expect(find.text('QA Lead / Test Lead'), findsWidgets);
      expect(find.text('1 course'), findsOneWidget);
    });

    testWidgets('shows a safe empty state for a department with no roles', (
      tester,
    ) async {
      await _pump(tester, department: _emptyDepartment);

      expect(
        find.text('No roles are listed for this department yet.'),
        findsOneWidget,
      );
      expect(tester.takeException(), isNull);
    });

    testWidgets('tapping a role opens its course sheet', (tester) async {
      await _pump(tester);

      await tester.tap(find.text('Software Developer'));
      await tester.pumpAndSettle();

      expect(find.text('Core Languages'), findsOneWidget);
      expect(find.text('Databases'), findsOneWidget);
    });

    testWidgets(
      'tapping a course navigates to the real lesson route built from its relativePath',
      (tester) async {
        await _pump(tester);

        await tester.tap(find.text('Software Developer'));
        await tester.pumpAndSettle();
        await tester.tap(find.text('Core Languages'));
        await tester.pumpAndSettle();

        expect(
          find.text(
            'LESSON: Core Languages | '
            '${buildSkillUpLessonUrl('TechCenter/development/software-developer/software_developer_core_languages.html')}',
          ),
          findsOneWidget,
        );
      },
    );

    testWidgets(
      'a single-course role\'s sheet still opens, and its one course navigates correctly',
      (tester) async {
        await _pump(tester);

        await tester.tap(find.text('QA Lead / Test Lead').last);
        await tester.pumpAndSettle();
        await tester.tap(find.text('QA Lead / Test Lead').last);
        await tester.pumpAndSettle();

        expect(
          find.text(
            'LESSON: QA Lead / Test Lead | '
            '${buildSkillUpLessonUrl('TechCenter/quality-assurance-qa-testing/qa-lead-test-lead/QA_Lead_Test_Lead.html')}',
          ),
          findsOneWidget,
        );
      },
    );

    testWidgets(
      'system back from the course sheet returns to the roles list, not the lesson screen',
      (tester) async {
        await _pump(tester);

        await tester.tap(find.text('Software Developer'));
        await tester.pumpAndSettle();
        // No explicit close button on this sheet — tapping the barrier above
        // it is how a real user dismisses it without picking a course.
        await tester.tapAt(const Offset(10, 10));
        await tester.pumpAndSettle();

        expect(find.text('Software Developer'), findsOneWidget);
        expect(find.textContaining('LESSON:'), findsNothing);
      },
    );

    testWidgets(
      'Phase 77 — a role with 5 courses and a long title does not overflow its sheet on a short '
      '(e.g. landscape) viewport',
      (tester) async {
        await _pump(
          tester,
          department: _departmentWithFiveCourseRole,
          surfaceSize: const Size(800, 320),
        );

        await tester.tap(find.text(_fiveCourseRole.title));
        await tester.pumpAndSettle();

        expect(tester.takeException(), isNull);
        for (final course in _fiveCourseRole.courses) {
          expect(find.text(course.title), findsOneWidget);
        }
      },
    );

    group('Phase 79 — role deep-link highlighting', () {
      testWidgets(
        'with no highlightRoleSlug, normal navigation is unchanged — nothing auto-scrolls',
        (tester) async {
          await _pump(tester, department: _manyRolesDepartment);

          expect(find.text('Role 1'), findsOneWidget);
          expect(tester.takeException(), isNull);
        },
      );

      testWidgets(
        'scrolls a role near the end of an 11-role department into view when highlighted — the '
        'exact "off-screen until scrolled" case a lazily-virtualized ListView could silently fail for',
        (tester) async {
          await _pump(
            tester,
            department: _manyRolesDepartment,
            highlightRoleSlug: 'role-11',
          );

          // Every role is still in the tree (eager Column, not a lazy
          // ListView — see this screen's own doc comment) ...
          expect(find.text('Role 11'), findsOneWidget);
          // ... and, specifically, scrolled to within the visible viewport,
          // not sitting far below it unscrolled.
          final topLeft = tester.getTopLeft(find.text('Role 11'));
          expect(
            topLeft.dy,
            lessThan(700),
            reason:
                'Role 11 should have been scrolled into the 700-tall viewport',
          );
          expect(topLeft.dy, greaterThanOrEqualTo(0));
        },
      );

      testWidgets(
        'an unknown highlightRoleSlug does not crash — the role list still renders normally',
        (tester) async {
          await _pump(
            tester,
            department: _department,
            highlightRoleSlug: 'this-role-does-not-exist',
          );

          expect(tester.takeException(), isNull);
          expect(find.text('Software Developer'), findsOneWidget);
        },
      );
    });
  });
}
