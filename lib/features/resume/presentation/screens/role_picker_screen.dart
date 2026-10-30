import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../app/router/route_paths.dart';
import '../../../../app/theme/app_colors.dart';
import '../../../../app/theme/app_radius.dart';
import '../../../../app/theme/app_spacing.dart';
import '../../../../core/errors/failures.dart';
import '../../../../core/utils/result.dart';
import '../../../../shared/widgets/app_error_view.dart';
import '../../../../shared/widgets/app_loader.dart';
import '../../domain/entities/resume_role.dart';
import '../../domain/repositories/resume_repository.dart'
    show ResumeRoleSelection;
import '../controllers/role_picker_controller.dart';
import '../providers/resume_providers.dart';

/// Phase 22/23's role-fit picker — the mobile equivalent of the real
/// landing page's "Choose Your Path" role cards (`landing.html:6729-6778`)
/// plus the 3-option `roleAct` modal every card opens
/// (`landing.html:7589-7622`), reached instead from inside
/// `ResumeBuilderScreen` (see `docs/PHASE_22_ROLE_FIT_PICKER_AUDIT.md` §6
/// for why — the Phase 21 home hero is explicitly out of scope as an entry
/// point). Role selection is always optional: backing out of this screen
/// without confirming a role leaves `ResumeBuilderScreen`'s own upload flow
/// completely unaffected, exactly like skipping the web's own picker does
/// (`_remember_target_role`, confirmed inert with no `role`/`dept` params).
class RolePickerScreen extends ConsumerStatefulWidget {
  const RolePickerScreen({super.key});

  @override
  ConsumerState<RolePickerScreen> createState() => _RolePickerScreenState();
}

class _RolePickerScreenState extends ConsumerState<RolePickerScreen> {
  @override
  void initState() {
    super.initState();
    // `load()` writes to `state` synchronously on its very first line
    // (resetting to `RolePickerLoading`, which matters for a retry, not
    // just the first load) — calling it directly from `initState` would
    // mutate a provider while the widget tree is still building, which
    // Riverpod forbids. Deferring to a post-frame callback (same pattern
    // `MockInterviewScreen` already uses) runs it just after this screen
    // finishes mounting instead.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        unawaited(ref.read(rolePickerControllerProvider.notifier).load());
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(rolePickerControllerProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Choose Target Role')),
      body: switch (state) {
        RolePickerLoading() => const AppLoader(message: 'Loading roles…'),
        RolePickerLoadFailed(failure: final failure) => AppErrorView(
          message: failure.message,
          onRetry: () =>
              ref.read(rolePickerControllerProvider.notifier).retryLoad(),
        ),
        RolePickerLoaded() => const _RoleListView(),
      },
    );
  }
}

class _RoleListView extends ConsumerWidget {
  const _RoleListView();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(rolePickerControllerProvider) as RolePickerLoaded;
    final controller = ref.read(rolePickerControllerProvider.notifier);
    final roles = state.filtered;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.md,
            AppSpacing.md,
            AppSpacing.md,
            AppSpacing.sm,
          ),
          child: Text(
            'Picking a target role is optional — it personalizes your ATS score and interview questions for that '
            'role. You can skip this and analyze your resume as-is.',
            style: TextStyle(color: AppColors.textMuted, fontSize: 13),
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
          child: TextField(
            key: const Key('role-search-field'),
            onChanged: controller.setQuery,
            decoration: const InputDecoration(
              hintText: 'Search roles…',
              prefixIcon: Icon(Icons.search),
              border: OutlineInputBorder(),
              isDense: true,
            ),
          ),
        ),
        const SizedBox(height: AppSpacing.sm),
        SizedBox(
          height: 40,
          child: ListView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
            children: [
              _CategoryChip(
                label: 'All',
                selected: state.category == null,
                onTap: () => controller.setCategory(null),
              ),
              const SizedBox(width: AppSpacing.sm),
              _CategoryChip(
                label: 'IT',
                selected: state.category == 'it',
                onTap: () => controller.setCategory('it'),
              ),
              const SizedBox(width: AppSpacing.sm),
              _CategoryChip(
                label: 'Non-IT · Technical',
                selected: state.category == 'tech',
                onTap: () => controller.setCategory('tech'),
              ),
              const SizedBox(width: AppSpacing.sm),
              _CategoryChip(
                label: 'Non-IT · Non-Technical',
                selected: state.category == 'nt',
                onTap: () => controller.setCategory('nt'),
              ),
            ],
          ),
        ),
        const SizedBox(height: AppSpacing.sm),
        Expanded(
          child: roles.isEmpty
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(AppSpacing.lg),
                    child: Text(
                      state.roles.isEmpty
                          ? 'No roles are available right now.'
                          : 'No roles match your search.',
                      textAlign: TextAlign.center,
                      style: const TextStyle(color: AppColors.textMuted),
                    ),
                  ),
                )
              : ListView.builder(
                  padding: const EdgeInsets.fromLTRB(
                    AppSpacing.md,
                    0,
                    AppSpacing.md,
                    AppSpacing.lg,
                  ),
                  itemCount: roles.length,
                  itemBuilder: (context, index) {
                    final role = roles[index];
                    return Card(
                      margin: const EdgeInsets.only(bottom: AppSpacing.sm),
                      child: ListTile(
                        title: Text(
                          role.title,
                          style: const TextStyle(fontWeight: FontWeight.w700),
                        ),
                        subtitle: Text(
                          '${role.categoryLabel} · ${role.subtitle}',
                        ),
                        trailing: const Icon(Icons.chevron_right),
                        onTap: () async {
                          final selection =
                              await showModalBottomSheet<ResumeRoleSelection>(
                                context: context,
                                isScrollControlled: true,
                                builder: (_) => _RoleActionSheet(role: role),
                              );
                          if (selection != null && context.mounted) {
                            Navigator.of(context).pop(selection);
                          }
                        },
                      ),
                    );
                  },
                ),
        ),
      ],
    );
  }
}

class _CategoryChip extends StatelessWidget {
  const _CategoryChip({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return ChoiceChip(
      label: Text(label),
      selected: selected,
      onSelected: (_) => onTap(),
      selectedColor: AppColors.action,
      labelStyle: TextStyle(
        color: selected ? AppColors.textOnDark : AppColors.textPrimary,
      ),
      backgroundColor: AppColors.surface,
      side: BorderSide(color: selected ? AppColors.action : AppColors.border),
    );
  }
}

/// The real web's `roleAct` modal (`landing.html:7589-7622`), reproduced
/// as a bottom sheet: 3 actions. "Resume Parsing & Interview" has been
/// functional since Phase 23; "Build Resume" now opens Phase 25's Manual
/// Resume Builder foundation (navigating straight into it, not popping a
/// result back to `ResumeBuilderScreen` — that screen has nothing to do
/// with manually-built resumes). "Skills" remains honestly disabled with
/// "Coming soon" — never a fake, tappable placeholder — since an in-app
/// skills summary doesn't exist in this app yet.
class _RoleActionSheet extends ConsumerStatefulWidget {
  const _RoleActionSheet({required this.role});

  final ResumeRole role;

  @override
  ConsumerState<_RoleActionSheet> createState() => _RoleActionSheetState();
}

class _RoleActionSheetState extends ConsumerState<_RoleActionSheet> {
  bool _isSaving = false;
  String? _error;

  /// Phase 67 (UI-R-002): the real `#roleAct` dialog's "Skills" card
  /// (`landing.html:7596-7603`) is a real, always-enabled action for every
  /// role shown through it — `pickRole()`'s own comment states this
  /// explicitly ("Skills uses the role modal when the role has skills
  /// data, otherwise Skill Up"), and for a catalog role (this sheet's own
  /// kind — `raIdx != null`, `landing.html:8744-8749`) it always opens the
  /// real role modal (`openRole()`), never a "coming soon" state. This
  /// sheet was the one place in the app that still hardcoded Skills as
  /// permanently disabled, even though the data it needs
  /// (`ResumeRole.fields` — this role's own skill-group checkboxes) was
  /// already being parsed and used elsewhere (`manual_resume_career_step
  /// .dart`). Mirrors `CareerRoleActionSheet._openSkills()`'s already-
  /// correct pattern for the department-tree sibling sheet.
  void _openSkills() {
    Navigator.of(context).pop();
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (_) => _RoleSkillsView(role: widget.role),
    );
  }

  Future<void> _confirm() async {
    if (_isSaving) {
      return; // prevents a duplicate submission while one is in flight
    }
    setState(() {
      _isSaving = true;
      _error = null;
    });
    final role = widget.role;
    final result = await ref
        .read(resumeRepositoryProvider)
        .selectTargetRole(
          role: role.title,
          dept: role.subtitle,
          track: role.track,
        );
    if (!mounted) return;
    switch (result) {
      case Success(value: final selection):
        Navigator.of(context).pop(selection);
      case Failed(failure: final failure) when failure is ResumeBuilderSignInRequiredFailure:
        // Matches live production (confirmed directly): a guest here is
        // redirected straight to the login page, with no error message of
        // any kind — the same clean redirect "Build Resume" already gives
        // a logged-out user, not a "session expired" text.
        Navigator.of(context).pop();
        context.push(RoutePaths.login);
      case Failed(failure: final failure):
        setState(() {
          _isSaving = false;
          _error = failure.message;
        });
    }
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              widget.role.categoryLabel,
              style: const TextStyle(color: AppColors.textMuted, fontSize: 12),
            ),
            const SizedBox(height: 4),
            Text(
              widget.role.title,
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: AppSpacing.sm),
            const Text(
              'What would you like to do next?',
              style: TextStyle(color: AppColors.textMuted),
            ),
            const SizedBox(height: AppSpacing.lg),
            _ActionTile(
              icon: Icons.checklist_outlined,
              title: 'Skills',
              subtitle: 'See the skills this role needs.',
              enabled: true,
              onTap: _openSkills,
            ),
            const SizedBox(height: AppSpacing.sm),
            _ActionTile(
              icon: Icons.description_outlined,
              title: 'Build Resume',
              subtitle: 'Create a resume from scratch for this role.',
              enabled: true,
              onTap: () {
                Navigator.of(context).pop();
                context.push(
                  RoutePaths.manualResumeBuilder,
                  extra: widget.role,
                );
              },
            ),
            const SizedBox(height: AppSpacing.sm),
            _ActionTile(
              icon: Icons.fact_check_outlined,
              title: 'Resume Parsing & Interview',
              subtitle:
                  'Upload your resume for AI parsing and ATS scoring for this role.',
              enabled: !_isSaving,
              isLoading: _isSaving,
              onTap: _confirm,
            ),
            if (_error != null) ...[
              const SizedBox(height: AppSpacing.sm),
              Text(
                _error!,
                style: const TextStyle(color: AppColors.danger, fontSize: 13),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _ActionTile extends StatelessWidget {
  const _ActionTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.enabled,
    this.isLoading = false,
    this.onTap,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final bool enabled;
  final bool isLoading;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: enabled ? onTap : null,
      borderRadius: AppRadius.mdRadius,
      child: Container(
        padding: const EdgeInsets.all(AppSpacing.md),
        decoration: BoxDecoration(
          border: Border.all(color: AppColors.border),
          borderRadius: AppRadius.mdRadius,
          color: enabled ? AppColors.surface : AppColors.background,
        ),
        child: Row(
          children: [
            Icon(
              icon,
              color: enabled ? AppColors.primary : AppColors.textMuted,
            ),
            const SizedBox(width: AppSpacing.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      fontWeight: FontWeight.w700,
                      color: enabled
                          ? AppColors.textPrimary
                          : AppColors.textMuted,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: const TextStyle(
                      color: AppColors.textMuted,
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),
            if (isLoading)
              const SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(strokeWidth: 2),
              )
            else if (enabled)
              const Icon(Icons.chevron_right, color: AppColors.textMuted),
          ],
        ),
      ),
    );
  }
}

/// Phase 67 (UI-R-002) — the catalog-role equivalent of
/// `CareerRoleSkillsView`, same visual structure ("Skills this role
/// requires." + one card per skill group + "Explore Skill Up" CTA), fed by
/// [ResumeRole.fields] instead of `CareerRole.skillGroups` — the real
/// `openRole()` role modal's own skill data for a catalog role
/// (`landing.html:7596-7603`'s "Skills" action).
class _RoleSkillsView extends StatelessWidget {
  const _RoleSkillsView({required this.role});

  final ResumeRole role;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: DraggableScrollableSheet(
        initialChildSize: 0.75,
        minChildSize: 0.4,
        maxChildSize: 0.95,
        expand: false,
        builder: (context, scrollController) {
          return Padding(
            padding: const EdgeInsets.all(AppSpacing.lg),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  role.categoryLabel,
                  style: const TextStyle(color: AppColors.textMuted, fontSize: 12),
                ),
                const SizedBox(height: 4),
                Text(
                  role.title,
                  style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
                ),
                const SizedBox(height: 4),
                const Text(
                  'Skills this role requires.',
                  style: TextStyle(color: AppColors.textMuted),
                ),
                const SizedBox(height: AppSpacing.md),
                Expanded(
                  child: ListView(
                    controller: scrollController,
                    children: [
                      for (final field in role.fields)
                        Padding(
                          padding: const EdgeInsets.only(bottom: AppSpacing.md),
                          child: _RoleSkillFieldCard(field: field),
                        ),
                      if (role.fields.isEmpty)
                        const Text(
                          'Skills coming soon.',
                          style: TextStyle(color: AppColors.textMuted),
                        ),
                    ],
                  ),
                ),
                SizedBox(
                  width: double.infinity,
                  height: 50,
                  child: FilledButton.icon(
                    onPressed: () {
                      Navigator.of(context).pop();
                      context.push(RoutePaths.skillUpSections);
                    },
                    icon: const Icon(Icons.arrow_forward, size: 17),
                    label: const Text('Explore Skill Up'),
                    style: FilledButton.styleFrom(
                      backgroundColor: AppColors.action,
                      foregroundColor: Colors.white,
                      textStyle: const TextStyle(fontWeight: FontWeight.w700),
                      shape: const StadiumBorder(),
                    ),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}

class _RoleSkillFieldCard extends StatelessWidget {
  const _RoleSkillFieldCard({required this.field});

  final ResumeRoleSkillField field;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: AppRadius.mdRadius,
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            field.label,
            style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13.5),
          ),
          const SizedBox(height: AppSpacing.sm),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: [
              for (final skill in field.options)
                Chip(
                  label: Text(skill, style: const TextStyle(fontSize: 12)),
                  backgroundColor: AppColors.background,
                  side: const BorderSide(color: AppColors.border),
                  padding: EdgeInsets.zero,
                  materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
              if (field.options.isEmpty)
                const Text(
                  'Skills coming soon',
                  style: TextStyle(color: AppColors.textMuted, fontSize: 12),
                ),
            ],
          ),
        ],
      ),
    );
  }
}
