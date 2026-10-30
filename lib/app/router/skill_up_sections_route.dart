import 'package:flutter/widgets.dart';

import '../../features/skill_up/data/tech_center_catalog.g.dart';
import '../../features/skill_up/domain/skill_up_deep_link.dart';
import '../../features/skill_up/presentation/screens/skill_up_nonit_deep_link_screen.dart';
import '../../features/skill_up/presentation/screens/skill_up_screen.dart';
import '../../features/skill_up/presentation/screens/tech_center_roles_screen.dart';

/// The pure logic behind `RoutePaths.skillUpSections`'s `GoRoute` builder,
/// kept separate from `GoRouter`/`GoRouterState` wiring so it can be
/// widget-tested directly — the same reasoning `route_guards.dart`'s own
/// doc comment already gives for [computeRedirect].
///
/// `?section=` carries both the pre-existing `depth-*` ids
/// ([SkillUpScreen]'s own "Sections in depth" tab, Phase 72) and, since
/// Phase 79, a Tech Center/Non-IT department or role id
/// ([parseSkillUpDeepLinkId]). A well-formed, resolvable id of one of
/// those 4 new kinds hands off directly to the real existing destination
/// screen; anything else (a `depth-*` id, missing, unrecognized, or a
/// well-formed-but-unresolvable Tech Center/Non-IT id) falls through to the
/// unchanged `SkillUpScreen(initialSectionId: ...)` path, which already
/// handles an unrecognized id safely (no scroll, lands on the tab's own
/// top) — the exact same fallback a resolution failure gets here, not a
/// new one invented for this phase.
Widget buildSkillUpSectionsScreen(String? sectionId) {
  final deepLinkId = parseSkillUpDeepLinkId(sectionId);
  if (deepLinkId is TechCenterDepartmentId) {
    final department = findTechCenterDepartment(
      kTechCenterDepartments,
      deepLinkId.departmentSlug,
    );
    if (department != null) {
      return TechCenterRolesScreen(department: department);
    }
  } else if (deepLinkId is TechCenterRoleId) {
    final found = findTechCenterRole(
      kTechCenterDepartments,
      deepLinkId.departmentSlug,
      deepLinkId.roleSlug,
    );
    if (found != null) {
      return TechCenterRolesScreen(
        department: found.department,
        highlightRoleSlug: found.role.slug,
      );
    }
  } else if (deepLinkId is NonItDepartmentId || deepLinkId is NonItRoleId) {
    return SkillUpNonItDeepLinkScreen(deepLinkId: deepLinkId!);
  }
  return SkillUpScreen(initialTabIndex: 1, initialSectionId: sectionId);
}
