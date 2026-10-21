import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../app/router/route_paths.dart';
import '../../../../app/theme/app_colors.dart';
import '../../../../app/theme/app_radius.dart';
import '../../../../app/theme/app_spacing.dart';
import '../../../../core/utils/result.dart';
import '../../domain/entities/career_department.dart';
import '../../domain/entities/resume_role.dart';
import '../providers/resume_providers.dart';
import 'career_role_skills_view.dart';

/// The real `roleAct` dialog (`landing.html:7589-7622`), reproduced as a
/// bottom sheet — the same 3 actions the existing `RolePickerScreen`'s own
/// `_RoleActionSheet` already shows, adapted here for a department-tree
/// [CareerRole] (raw name + skill groups) rather than a full, pre-cataloged
/// `ResumeRole`. "Skills" is real here (unlike that other sheet's honest
/// "Coming soon") because the department/role JSON genuinely carries the
/// skill data needed to show it — see `CareerRoleSkillsView`.
class CareerRoleActionSheet extends ConsumerStatefulWidget {
  const CareerRoleActionSheet({
    required this.role,
    required this.department,
    super.key,
  });

  final CareerRole role;
  final CareerDepartment department;

  @override
  ConsumerState<CareerRoleActionSheet> createState() => _CareerRoleActionSheetState();
}

class _CareerRoleActionSheetState extends ConsumerState<CareerRoleActionSheet> {
  bool _isSaving = false;
  String? _error;

  /// `track: r.c === 'it' ? 'tech' : 'nonit'` (`pickRole()`,
  /// `landing.html:8738`) — confirmed directly: an `'it'`-category role
  /// maps to `'tech'`; both Non-IT categories (`'tech'`/`'nt'`) map to
  /// `'nonit'`.
  String get _trackParam => widget.department.category == 'it' ? 'tech' : 'nonit';

  void _openSkills() {
    Navigator.of(context).pop();
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (_) => CareerRoleSkillsView(role: widget.role, department: widget.department),
    );
  }

  /// `customRole()` (`landing.html:8755-8763`): a synthetic resume role
  /// built on the fly from this role's own skill groups, the same thing
  /// the real `raBuild` handler does for every department-tree role (none
  /// of them exist in the predefined `manual_resume_roles` catalog).
  void _openBuildResume() {
    final slug = 'custom-${widget.role.name.toLowerCase().replaceAll('&', 'and').replaceAll(RegExp(r'[^a-z0-9]+'), '-').replaceAll(RegExp(r'^-|-$'), '')}';
    final synthetic = ResumeRole(
      slug: slug.length > 80 ? slug.substring(0, 80) : slug,
      title: widget.role.name,
      category: widget.department.category,
      categoryLabel: switch (widget.department.category) {
        'it' => 'IT Role',
        'tech' => 'Non-IT · Technical',
        _ => 'Non-IT · Non-Technical',
      },
      subtitle: widget.department.name,
      fields: [
        for (final group in widget.role.skillGroups)
          ResumeRoleSkillField(
            key: group.label.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]+'), '-'),
            label: group.label,
            options: group.skills,
          ),
      ],
    );
    Navigator.of(context).pop();
    context.push(RoutePaths.manualResumeBuilder, extra: synthetic);
  }

  Future<void> _confirmResumeParsing() async {
    if (_isSaving) return;
    setState(() {
      _isSaving = true;
      _error = null;
    });
    final result = await ref
        .read(resumeRepositoryProvider)
        .selectTargetRole(
          role: widget.role.name,
          dept: widget.department.name,
          track: _trackParam,
        );
    if (!mounted) return;
    switch (result) {
      case Success(value: final selection):
        ref.read(resumeBuilderControllerProvider.notifier).setTargetRole(selection);
        Navigator.of(context).pop();
        context.push(RoutePaths.resumeBuilder);
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
              widget.department.name,
              style: const TextStyle(color: AppColors.textMuted, fontSize: 12),
            ),
            const SizedBox(height: 4),
            Text(
              widget.role.name,
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: AppSpacing.sm),
            const Text(
              'What would you like to do next?',
              style: TextStyle(color: AppColors.textMuted),
            ),
            const SizedBox(height: AppSpacing.lg),
            _ActionTile(
              key: const Key('career-role-action-skills'),
              icon: Icons.checklist_outlined,
              title: 'Skills',
              subtitle: 'See the skills this role needs.',
              enabled: true,
              onTap: _openSkills,
            ),
            const SizedBox(height: AppSpacing.sm),
            _ActionTile(
              key: const Key('career-role-action-build-resume'),
              icon: Icons.description_outlined,
              title: 'Build Resume',
              subtitle: 'Build a resume for this role: pick your skills, add your details and download the PDF.',
              enabled: true,
              onTap: _openBuildResume,
            ),
            const SizedBox(height: AppSpacing.sm),
            _ActionTile(
              key: const Key('career-role-action-resume-parsing'),
              icon: Icons.fact_check_outlined,
              title: 'Resume Parsing & Interview',
              subtitle: 'Upload your resume for AI parsing and ATS scoring, then practise a mock interview.',
              enabled: !_isSaving,
              isLoading: _isSaving,
              onTap: _confirmResumeParsing,
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
    super.key,
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
            Icon(icon, color: enabled ? AppColors.primary : AppColors.textMuted),
            const SizedBox(width: AppSpacing.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      fontWeight: FontWeight.w700,
                      color: enabled ? AppColors.textPrimary : AppColors.textMuted,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: const TextStyle(color: AppColors.textMuted, fontSize: 12),
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
