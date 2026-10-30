import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Phase 79 — a `role-nonit-*` deep link (`SkillUpNonItDeepLinkScreen`)
/// resolves its target only after `skillUpNonItDepartmentsProvider`'s async
/// fetch completes, then navigates to [SkillUpNonItRolesScreen] with the
/// resolved `CareerDepartment` via the route's own existing `extra`
/// contract (unchanged). The *role* to auto-open once that screen mounts
/// has nowhere to travel through that same `extra` without changing the
/// existing `CareerDepartment`-typed contract every other caller
/// (`SkillUpNonItDepartmentsScreen`'s own department cards) already relies
/// on.
///
/// Mirrors [HomeScrollRequestController]'s own established pattern in this
/// codebase exactly (`home_scroll_request_provider.dart`): a tiny
/// `Notifier` the requester writes to and the one consumer reads once (and
/// clears) in `initState`, rather than widening an existing route's `extra`
/// type for one new caller.
class SkillUpNonItRoleOpenRequestController extends Notifier<String?> {
  @override
  String? build() => null;

  /// [roleName] is the role's own `CareerRole.name` — already this
  /// screen's de facto identity (its role cards are already keyed by
  /// `role.name`, confirmed in `skill_up_nonit_roles_screen.dart`), so no
  /// new identifier is introduced.
  void request(String roleName) => state = roleName;

  void clear() => state = null;
}

final skillUpNonItRoleOpenRequestProvider =
    NotifierProvider<SkillUpNonItRoleOpenRequestController, String?>(
      SkillUpNonItRoleOpenRequestController.new,
    );
