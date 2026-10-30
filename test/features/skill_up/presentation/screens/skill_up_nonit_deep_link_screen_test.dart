import 'dart:async';

import 'package:career_buddy_lms/app/router/route_paths.dart';
import 'package:career_buddy_lms/features/resume/domain/entities/career_department.dart';
import 'package:career_buddy_lms/features/skill_up/data/skill_up_nonit_asset_datasource.dart';
import 'package:career_buddy_lms/features/skill_up/domain/skill_up_deep_link.dart';
import 'package:career_buddy_lms/features/skill_up/presentation/providers/skill_up_providers.dart';
import 'package:career_buddy_lms/features/skill_up/presentation/screens/skill_up_nonit_deep_link_screen.dart';
import 'package:career_buddy_lms/features/skill_up/presentation/screens/skill_up_nonit_departments_screen.dart';
import 'package:career_buddy_lms/features/skill_up/presentation/screens/skill_up_nonit_roles_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

const _recruiterRole = CareerRole(
  name: 'Lead Technical Recruiter (Engineering)',
  skillGroups: [
    CareerRoleSkillGroup(
      label: 'Role skills',
      skills: ['Full-cycle technical sourcing'],
    ),
  ],
  coursePath: 'NonITCenter/technical/x/01.html',
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
];

class _FakeSkillUpNonItDataSource extends SkillUpNonItAssetDataSource {
  _FakeSkillUpNonItDataSource({this.error, this.gate});

  final Object? error;
  final Future<void>? gate;

  @override
  Future<List<CareerDepartmentGroup>> load() async {
    if (gate != null) await gate;
    if (error != null) throw error!;
    return _groups;
  }
}

GoRouter _router(SkillUpDeepLinkId deepLinkId) => GoRouter(
  initialLocation: RoutePaths.skillUpSections,
  routes: [
    GoRoute(
      path: RoutePaths.skillUpSections,
      builder: (context, state) =>
          SkillUpNonItDeepLinkScreen(deepLinkId: deepLinkId),
    ),
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

Future<ProviderContainer> _pump(
  WidgetTester tester,
  SkillUpDeepLinkId deepLinkId, {
  Object? error,
  Future<void>? gate,
}) async {
  final container = ProviderContainer(
    overrides: [
      skillUpNonItAssetDataSourceProvider.overrideWithValue(
        _FakeSkillUpNonItDataSource(error: error, gate: gate),
      ),
    ],
  );
  addTearDown(container.dispose);
  await tester.pumpWidget(
    UncontrolledProviderScope(
      container: container,
      child: MaterialApp.router(routerConfig: _router(deepLinkId)),
    ),
  );
  await tester.pumpAndSettle();
  return container;
}

void main() {
  group('SkillUpNonItDeepLinkScreen', () {
    testWidgets(
      'shows a loading indicator while the Non-IT catalog is still fetching',
      (tester) async {
        final gate = Completer<void>();
        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              skillUpNonItAssetDataSourceProvider.overrideWithValue(
                _FakeSkillUpNonItDataSource(gate: gate.future),
              ),
            ],
            child: MaterialApp.router(
              routerConfig: _router(
                const NonItDepartmentId(
                  'engineering-recruitment-technical-staffing',
                ),
              ),
            ),
          ),
        );
        await tester.pump();

        expect(find.byType(CircularProgressIndicator), findsOneWidget);
        gate.complete();
        await tester.pumpAndSettle();
      },
    );

    testWidgets(
      'a department id navigates to the correct department\'s roles screen once resolved',
      (tester) async {
        await _pump(
          tester,
          const NonItDepartmentId('engineering-recruitment-technical-staffing'),
        );

        expect(
          find.text('Engineering Recruitment & Technical Staffing'),
          findsOneWidget,
        );
        expect(
          find.text('Lead Technical Recruiter (Engineering)'),
          findsOneWidget,
        );
      },
    );

    testWidgets(
      'a role id navigates to the correct parent department and opens that role\'s sheet',
      (tester) async {
        await _pump(
          tester,
          const NonItRoleId(
            'engineering-recruitment-technical-staffing',
            'lead-technical-recruiter-engineering',
          ),
        );

        expect(
          find.text('Engineering Recruitment & Technical Staffing'),
          findsOneWidget,
        );
        expect(find.text('Full-cycle technical sourcing'), findsOneWidget);
        expect(find.text('Start course'), findsOneWidget);
      },
    );

    testWidgets(
      'an unresolvable department id falls back to the plain Non-IT departments list, not a crash',
      (tester) async {
        await _pump(
          tester,
          const NonItDepartmentId('this-department-does-not-exist'),
        );

        expect(tester.takeException(), isNull);
        expect(
          find.text('Engineering Recruitment & Technical Staffing'),
          findsOneWidget,
        );
        // Landed on the plain departments list, not a specific role screen.
        expect(
          find.text('Lead Technical Recruiter (Engineering)'),
          findsNothing,
        );
      },
    );

    testWidgets(
      'shows a retryable error view when the Non-IT catalog fails to load',
      (tester) async {
        await _pump(
          tester,
          const NonItDepartmentId('x'),
          error: Exception('boom'),
        );

        expect(find.textContaining('could not be loaded'), findsOneWidget);
        expect(find.text('Retry'), findsOneWidget);
      },
    );
  });
}
