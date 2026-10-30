import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../app/router/route_paths.dart';
import '../../../../shared/widgets/app_error_view.dart';
import '../../../../shared/widgets/app_loader.dart';
import '../../../resume/domain/entities/career_department.dart';
import '../../domain/skill_up_deep_link.dart';
import '../providers/skill_up_nonit_role_open_request_provider.dart';
import '../providers/skill_up_providers.dart';

/// Phase 79 — resolves a `grp-nonit-*`/`role-nonit-*` `?section=` deep link
/// (`RoutePaths.skillUpSectionsFor`) against the Non-IT catalog.
///
/// Unlike Tech Center's `kTechCenterDepartments` (a `const`, generated at
/// build time), the Non-IT catalog is only available once
/// [skillUpNonItDepartmentsProvider]'s bundled-asset fetch resolves — the
/// exact same `FutureProvider` [SkillUpNonItDepartmentsScreen] already
/// watches, reused here rather than fetched again. This screen's only job
/// is to wait for that same data and then hand off to the real destination
/// screen (via the existing `extra`-based route contract, unchanged) — it
/// never renders any Non-IT content of its own.
class SkillUpNonItDeepLinkScreen extends ConsumerWidget {
  const SkillUpNonItDeepLinkScreen({required this.deepLinkId, super.key});

  /// Always a [NonItDepartmentId] or [NonItRoleId] — enforced by this
  /// screen's one call site in `app_router.dart`.
  final SkillUpDeepLinkId deepLinkId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final groupsAsync = ref.watch(skillUpNonItDepartmentsProvider);
    return switch (groupsAsync) {
      AsyncData(:final value) => _Resolver(
        deepLinkId: deepLinkId,
        groups: value,
      ),
      AsyncError(:final error) => Scaffold(
        appBar: AppBar(title: const Text('Non-IT Center')),
        body: AppErrorView(
          message: 'Departments could not be loaded: $error',
          onRetry: () => ref.invalidate(skillUpNonItDepartmentsProvider),
        ),
      ),
      _ => const Scaffold(body: AppLoader(message: 'Loading departments…')),
    };
  }
}

class _Resolver extends ConsumerStatefulWidget {
  const _Resolver({required this.deepLinkId, required this.groups});

  final SkillUpDeepLinkId deepLinkId;
  final List<CareerDepartmentGroup> groups;

  @override
  ConsumerState<_Resolver> createState() => _ResolverState();
}

class _ResolverState extends ConsumerState<_Resolver> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _navigate());
  }

  void _navigate() {
    if (!mounted) return;
    final id = widget.deepLinkId;

    CareerDepartment? department;
    CareerRole? role;
    if (id is NonItDepartmentId) {
      department = findNonItDepartment(widget.groups, id.departmentSlug);
    } else if (id is NonItRoleId) {
      final found = findNonItRole(
        widget.groups,
        id.departmentSlug,
        id.roleSlug,
      );
      department = found?.department;
      role = found?.role;
    }

    if (department == null) {
      // Graceful fallback for an unresolvable (but well-formed) id — the
      // same safe behavior an unrecognized `depth-*` id already gets
      // elsewhere: land on the plain, un-filtered browsing screen rather
      // than failing.
      context.pushReplacement(RoutePaths.skillUpNonIt);
      return;
    }
    if (role != null) {
      ref.read(skillUpNonItRoleOpenRequestProvider.notifier).request(role.name);
    }
    context.pushReplacement(RoutePaths.skillUpNonItRoles, extra: department);
  }

  @override
  Widget build(BuildContext context) =>
      const Scaffold(body: AppLoader(message: 'Loading…'));
}
