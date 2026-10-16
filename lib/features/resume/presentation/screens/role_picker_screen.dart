import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../app/router/route_paths.dart';
import '../../../../app/theme/app_colors.dart';
import '../../../../app/theme/app_radius.dart';
import '../../../../app/theme/app_spacing.dart';
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
              subtitle: 'Coming soon',
              enabled: false,
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
