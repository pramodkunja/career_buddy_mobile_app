import 'package:career_buddy_lms/app/router/route_paths.dart';
import 'package:career_buddy_lms/features/resume/data/career_departments_asset_datasource.dart';
import 'package:career_buddy_lms/features/resume/domain/entities/career_department.dart';
import 'package:career_buddy_lms/features/resume/presentation/providers/resume_providers.dart';
import 'package:career_buddy_lms/features/resume/presentation/screens/career_departments_screen.dart';
import 'package:career_buddy_lms/features/resume/presentation/screens/career_roles_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

const _softwareDeveloper = CareerRole(
  name: 'Software Developer',
  skillGroups: [
    CareerRoleSkillGroup(label: 'Core Languages', skills: ['Python', 'Java']),
  ],
);

const _itGroups = [
  CareerDepartmentGroup(
    label: 'Product and Engineering',
    departments: [
      CareerDepartment(
        category: 'it',
        icon: 'code',
        name: 'Development',
        roles: [_softwareDeveloper],
      ),
    ],
  ),
  CareerDepartmentGroup(label: 'Business and Support', departments: []),
];

class _FakeCareerDepartmentsDataSource extends CareerDepartmentsAssetDataSource {
  _FakeCareerDepartmentsDataSource({this.error});

  final Object? error;

  @override
  Future<List<CareerDepartmentGroup>> load(String track) async {
    if (error != null) throw error!;
    return track == 'it' ? _itGroups : const [];
  }
}

Future<void> _pump(
  WidgetTester tester, {
  String track = 'it',
  Object? error,
}) async {
  final container = ProviderContainer(
    overrides: [
      careerDepartmentsAssetDataSourceProvider.overrideWithValue(
        _FakeCareerDepartmentsDataSource(error: error),
      ),
    ],
  );
  addTearDown(container.dispose);
  final router = GoRouter(
    initialLocation: RoutePaths.careerDepartments,
    routes: [
      GoRoute(
        path: RoutePaths.careerDepartments,
        builder: (context, state) => CareerDepartmentsScreen(track: track),
      ),
      GoRoute(
        path: RoutePaths.careerRoles,
        builder: (context, state) =>
            CareerRolesScreen(department: state.extra! as CareerDepartment),
      ),
    ],
  );
  await tester.pumpWidget(
    UncontrolledProviderScope(
      container: container,
      child: MaterialApp.router(routerConfig: router),
    ),
  );
  // No infinite animation on this screen (unlike `BuddyChatbotOverlay`
  // elsewhere), so `pumpAndSettle` is safe and reliably lets the
  // `FutureProvider` resolve before assertions run.
  await tester.pumpAndSettle();
}

void main() {
  group('CareerDepartmentsScreen', () {
    testWidgets('shows a loading indicator, then the real groups and department cards', (tester) async {
      await _pump(tester);

      expect(find.text('Product and Engineering'), findsOneWidget);
      expect(find.text('Development'), findsOneWidget);
      expect(find.text('1 roles'), findsOneWidget);
      // The empty "Business and Support" group's heading is skipped —
      // there is nothing useful to show under it.
      expect(find.text('Business and Support'), findsNothing);
    });

    testWidgets('shows a retryable error view when loading fails', (tester) async {
      await _pump(tester, error: Exception('boom'));

      expect(find.textContaining('could not be loaded'), findsOneWidget);
      expect(find.text('Retry'), findsOneWidget);
    });

    testWidgets('shows an empty state when the track genuinely has no departments', (tester) async {
      await _pump(tester, track: 'non-it');

      expect(
        find.text('No departments are available right now.'),
        findsOneWidget,
      );
    });

    testWidgets('tapping a department navigates to its roles screen', (tester) async {
      await _pump(tester);

      await tester.tap(find.text('Development'));
      await tester.pumpAndSettle();

      expect(find.text('Software Developer'), findsOneWidget);
    });

    testWidgets('system/app-bar Back from the roles screen returns to the departments list', (tester) async {
      await _pump(tester);

      await tester.tap(find.text('Development'));
      await tester.pumpAndSettle();
      expect(find.text('Software Developer'), findsOneWidget);

      await tester.tap(find.byTooltip('Back'));
      await tester.pumpAndSettle();

      expect(find.text('Development'), findsOneWidget);
      expect(find.text('Software Developer'), findsNothing);
    });
  });
}
