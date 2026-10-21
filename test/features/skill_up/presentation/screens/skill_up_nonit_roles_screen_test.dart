import 'package:career_buddy_lms/app/router/route_paths.dart';
import 'package:career_buddy_lms/features/resume/domain/entities/career_department.dart';
import 'package:career_buddy_lms/features/skill_up/domain/skill_up_lesson_url.dart';
import 'package:career_buddy_lms/features/skill_up/presentation/screens/skill_up_nonit_roles_screen.dart';
import 'package:career_buddy_lms/features/skill_up/presentation/skill_up_lesson_route_args.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

const _roleWithCourse = CareerRole(
  name: 'Lead Technical Recruiter (Engineering)',
  skillGroups: [
    CareerRoleSkillGroup(label: 'Role skills', skills: ['Full-cycle technical sourcing', 'Boolean search']),
  ],
  coursePath: 'NonITCenter/technical/engineering-recruitment-technical-staffing/01_lead_technical_recruiter_engineering.html',
);

const _roleWithoutSkillsOrCourse = CareerRole(name: 'Placeholder Role', skillGroups: []);

const _department = CareerDepartment(
  category: 'tech',
  icon: 'search',
  name: 'Engineering Recruitment & Technical Staffing',
  roles: [_roleWithCourse, _roleWithoutSkillsOrCourse],
);

GoRouter _router() => GoRouter(
  initialLocation: RoutePaths.skillUpNonItRoles,
  routes: [
    GoRoute(
      path: RoutePaths.skillUpNonItRoles,
      builder: (context, state) => const SkillUpNonItRolesScreen(department: _department),
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

Future<void> _pump(WidgetTester tester) async {
  await tester.pumpWidget(MaterialApp.router(routerConfig: _router()));
  await tester.pumpAndSettle();
}

void main() {
  group('SkillUpNonItRolesScreen', () {
    testWidgets('lists every role with its skill count and a "1 course" badge when linked', (tester) async {
      await _pump(tester);

      expect(find.text('Lead Technical Recruiter (Engineering)'), findsOneWidget);
      expect(find.text('2 skills'), findsOneWidget);
      expect(find.text('1 course'), findsOneWidget);
      expect(find.text('Placeholder Role'), findsOneWidget);
      expect(find.text('Skills coming soon'), findsOneWidget);
    });

    testWidgets('tapping a role opens its skill-chip sheet with a "Start course" action', (tester) async {
      await _pump(tester);

      await tester.tap(find.text('Lead Technical Recruiter (Engineering)'));
      await tester.pumpAndSettle();

      expect(find.text('Full-cycle technical sourcing'), findsOneWidget);
      expect(find.text('Boolean search'), findsOneWidget);
      expect(find.text('Start course'), findsOneWidget);
    });

    testWidgets('a role with no coursePath shows its sheet without a "Start course" action', (tester) async {
      await _pump(tester);

      await tester.tap(find.text('Placeholder Role'));
      await tester.pumpAndSettle();

      // "Skills coming soon" also appears on the role card behind the sheet
      // (same subtitle the list screen shows), so at least one, not exactly
      // one.
      expect(find.text('Skills coming soon'), findsWidgets);
      expect(find.text('Start course'), findsNothing);
    });

    testWidgets('"Start course" navigates to the real lesson route built from the role\'s coursePath', (tester) async {
      await _pump(tester);

      await tester.tap(find.text('Lead Technical Recruiter (Engineering)'));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('skillup-nonit-start-course-button')));
      await tester.pumpAndSettle();

      expect(
        find.text('LESSON: Lead Technical Recruiter (Engineering) | ${buildSkillUpLessonUrl(_roleWithCourse.coursePath!)}'),
        findsOneWidget,
      );
    });
  });
}
