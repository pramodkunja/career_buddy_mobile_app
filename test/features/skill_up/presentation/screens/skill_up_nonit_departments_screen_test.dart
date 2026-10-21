import 'package:career_buddy_lms/app/router/route_paths.dart';
import 'package:career_buddy_lms/features/resume/domain/entities/career_department.dart';
import 'package:career_buddy_lms/features/skill_up/data/skill_up_nonit_asset_datasource.dart';
import 'package:career_buddy_lms/features/skill_up/presentation/providers/skill_up_providers.dart';
import 'package:career_buddy_lms/features/skill_up/presentation/screens/skill_up_nonit_departments_screen.dart';
import 'package:career_buddy_lms/features/skill_up/presentation/screens/skill_up_nonit_roles_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

const _recruiterRole = CareerRole(
  name: 'Lead Technical Recruiter (Engineering)',
  skillGroups: [
    CareerRoleSkillGroup(label: 'Role skills', skills: ['Full-cycle technical sourcing']),
  ],
  coursePath: 'NonITCenter/technical/engineering-recruitment-technical-staffing/01_lead_technical_recruiter_engineering.html',
);

const _groups = [
  CareerDepartmentGroup(
    label: 'Non-IT · Technical',
    departments: [
      CareerDepartment(
        category: 'tech',
        icon: 'search',
        name: 'Engineering Recruitment & Technical Staffing',
        roles: [_recruiterRole],
      ),
    ],
  ),
  CareerDepartmentGroup(label: 'Non-IT · Non-Technical', departments: []),
];

class _FakeSkillUpNonItDataSource extends SkillUpNonItAssetDataSource {
  _FakeSkillUpNonItDataSource({this.error});

  final Object? error;

  @override
  Future<List<CareerDepartmentGroup>> load() async {
    if (error != null) throw error!;
    return _groups;
  }
}

Future<void> _pump(WidgetTester tester, {Object? error}) async {
  final container = ProviderContainer(
    overrides: [
      skillUpNonItAssetDataSourceProvider.overrideWithValue(_FakeSkillUpNonItDataSource(error: error)),
    ],
  );
  addTearDown(container.dispose);
  final router = GoRouter(
    initialLocation: RoutePaths.skillUpNonIt,
    routes: [
      GoRoute(
        path: RoutePaths.skillUpNonIt,
        builder: (context, state) => const SkillUpNonItDepartmentsScreen(),
      ),
      GoRoute(
        path: RoutePaths.skillUpNonItRoles,
        builder: (context, state) =>
            SkillUpNonItRolesScreen(department: state.extra! as CareerDepartment),
      ),
    ],
  );
  await tester.pumpWidget(
    UncontrolledProviderScope(
      container: container,
      child: MaterialApp.router(routerConfig: router),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  group('SkillUpNonItDepartmentsScreen', () {
    testWidgets('shows the real departments and the department/role count copy', (tester) async {
      await _pump(tester);

      expect(find.text('Non-IT · Technical'), findsOneWidget);
      expect(find.text('Engineering Recruitment & Technical Staffing'), findsOneWidget);
      expect(find.text('1 roles'), findsOneWidget);
      expect(find.textContaining('departments'), findsWidgets);
      // The empty "Non-IT · Non-Technical" group's heading is skipped.
      expect(find.text('Non-IT · Non-Technical'), findsNothing);
    });

    testWidgets('shows a retryable error view when loading fails', (tester) async {
      await _pump(tester, error: Exception('boom'));

      expect(find.textContaining('could not be loaded'), findsOneWidget);
      expect(find.text('Retry'), findsOneWidget);
    });

    testWidgets('tapping a department navigates to its roles screen', (tester) async {
      await _pump(tester);

      await tester.tap(find.text('Engineering Recruitment & Technical Staffing'));
      await tester.pumpAndSettle();

      expect(find.text('Lead Technical Recruiter (Engineering)'), findsOneWidget);
    });

    testWidgets('system/app-bar Back from the roles screen returns to the departments list', (tester) async {
      await _pump(tester);

      await tester.tap(find.text('Engineering Recruitment & Technical Staffing'));
      await tester.pumpAndSettle();
      expect(find.text('Lead Technical Recruiter (Engineering)'), findsOneWidget);

      await tester.tap(find.byTooltip('Back'));
      await tester.pumpAndSettle();

      expect(find.text('Engineering Recruitment & Technical Staffing'), findsOneWidget);
      expect(find.text('Lead Technical Recruiter (Engineering)'), findsNothing);
    });
  });
}
