import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../app/theme/app_colors.dart';
import '../../../../app/theme/app_spacing.dart';
import '../../domain/entities/level_common_suggestions.dart';
import '../../domain/entities/manual_resume_draft.dart';
import '../../domain/entities/resume_role.dart';
import '../../domain/validation/manual_resume_validation.dart';
import '../controllers/manual_resume_builder_controller.dart';
import '../providers/resume_providers.dart';
import 'manual_resume_form_widgets.dart';

/// Step 2 — Career & Skills (verified, `landing.html:8572-8587`): role is
/// already fixed (chosen via the Role Picker before entering this wizard —
/// the real builder doesn't let it change mid-wizard either); experience
/// level; target title; industry/domain + years (only once [EXP] applies,
/// i.e. any level but fresher); the role's own skill-group chips (each with
/// a free-text add); suggested skills; professional (soft) skills; a
/// bottom free-text "Other skills" field.
class ManualResumeCareerStep extends ConsumerStatefulWidget {
  const ManualResumeCareerStep({
    required this.draft,
    required this.role,
    required this.levelCommon,
    required this.visibleErrors,
    super.key,
  });

  final ManualResumeDraft draft;
  final ResumeRole? role;
  final Map<String, LevelCommonSuggestions> levelCommon;
  final List<ManualResumeValidationError> visibleErrors;

  @override
  ConsumerState<ManualResumeCareerStep> createState() => _ManualResumeCareerStepState();
}

class _ManualResumeCareerStepState extends ConsumerState<ManualResumeCareerStep> {
  final Map<String, TextEditingController> _addSkillControllers = {};
  String? _addSkillError;

  TextEditingController _addControllerFor(String groupKey) =>
      _addSkillControllers.putIfAbsent(groupKey, TextEditingController.new);

  @override
  void dispose() {
    for (final c in _addSkillControllers.values) {
      c.dispose();
    }
    super.dispose();
  }

  String? _errorFor(String field) =>
      widget.visibleErrors.where((e) => e.field == field).map((e) => e.message).firstOrNull;

  @override
  Widget build(BuildContext context) {
    final controller = ref.read(manualResumeBuilderControllerProvider.notifier);
    final draft = widget.draft;
    final role = widget.role;
    final showExperienceFields = draft.level.isNotEmpty && draft.level != 'fresher';
    final levelInfo = widget.levelCommon[draft.level];

    final suggestedSkills = draft.level.isEmpty
        ? const <String>[]
        : {
            ...?role?.levels[draft.level]?.skills,
            ...?role?.recommendedSkills,
          }.toList();

    return ListView(
      padding: const EdgeInsets.all(AppSpacing.lg),
      children: [
        if (role != null) ...[
          Text(
            role.title,
            key: const Key('career-role-title'),
            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
          ),
          Text(role.categoryLabel, style: const TextStyle(color: AppColors.textMuted, fontSize: 12)),
          const SizedBox(height: AppSpacing.md),
        ],
        DropdownButtonFormField<String>(
          initialValue: draft.level.isEmpty ? null : draft.level,
          decoration: InputDecoration(
            labelText: 'Experience level *',
            border: const OutlineInputBorder(),
            errorText: _errorFor('level'),
          ),
          items: [
            for (final key in kManualResumeLevelKeys)
              DropdownMenuItem(value: key, child: Text(kManualResumeLevelLabels[key]!)),
          ],
          onChanged: (level) {
            if (level != null) controller.setLevel(level);
            controller.markTouched('level');
          },
        ),
        if (levelInfo != null && levelInfo.emphasis.isNotEmpty) ...[
          const SizedBox(height: AppSpacing.sm),
          Container(
            padding: const EdgeInsets.all(AppSpacing.sm),
            decoration: BoxDecoration(
              color: AppColors.background,
              border: Border.all(color: AppColors.border),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(levelInfo.emphasis, style: const TextStyle(fontSize: 12, color: AppColors.textMuted)),
          ),
        ],
        const SizedBox(height: AppSpacing.md),
        ManualResumeTextField(
          label: 'Target job title',
          value: draft.targetTitle,
          hint: role?.title,
          errorText: _errorFor('target_title'),
          onChanged: controller.setTargetTitle,
          onBlur: () => controller.markTouched('target_title'),
        ),
        if (showExperienceFields) ...[
          const SizedBox(height: AppSpacing.md),
          ManualResumeTextField(
            label: 'Years of experience',
            value: draft.years,
            keyboardType: TextInputType.number,
            errorText: _errorFor('years'),
            onChanged: controller.setYears,
            onBlur: () => controller.markTouched('years'),
          ),
          const SizedBox(height: AppSpacing.md),
          ManualResumeTextField(
            label: 'Industry / domain',
            value: draft.domain,
            errorText: _errorFor('domain'),
            onChanged: controller.setDomain,
            onBlur: () => controller.markTouched('domain'),
          ),
        ],
        const SizedBox(height: AppSpacing.lg),
        if (_errorFor('skills') != null)
          Padding(
            padding: const EdgeInsets.only(bottom: AppSpacing.sm),
            child: Text(_errorFor('skills')!, style: const TextStyle(color: AppColors.danger, fontSize: 13)),
          ),
        for (final field in role?.fields ?? const <ResumeRoleSkillField>[]) ...[
          ManualResumeChipGroup(
            label: field.label,
            options: field.options,
            isSelected: (option) => (draft.skills.groups[field.key] ?? const []).any(
              (s) => s.toLowerCase() == option.toLowerCase(),
            ),
            onToggle: (option) => controller.toggleGroupSkill(field.key, option),
          ),
          Row(
            children: [
              Expanded(
                child: TextField(
                  key: Key('add-skill-field-${field.key}'),
                  controller: _addControllerFor(field.key),
                  decoration: const InputDecoration(
                    hintText: 'Add your own skill',
                    isDense: true,
                    border: OutlineInputBorder(),
                  ),
                  onSubmitted: (_) => _addSkill(controller, field.key),
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              OutlinedButton(onPressed: () => _addSkill(controller, field.key), child: const Text('Add')),
            ],
          ),
          if (_addSkillError != null)
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Text(_addSkillError!, style: const TextStyle(color: AppColors.danger, fontSize: 12)),
            ),
          const SizedBox(height: AppSpacing.md),
        ],
        if (draft.level.isNotEmpty) ...[
          ManualResumeChipGroup(
            label: 'Suggested for ${kManualResumeLevelLabels[draft.level]} & recommended for this role',
            options: suggestedSkills,
            isSelected: (option) =>
                draft.skills.suggested.any((s) => s.toLowerCase() == option.toLowerCase()),
            onToggle: controller.toggleSuggestedSkill,
          ),
          ManualResumeChipGroup(
            label: 'Professional skills',
            options: levelInfo?.softSkills ?? const [],
            isSelected: (option) => draft.skills.soft.any((s) => s.toLowerCase() == option.toLowerCase()),
            onToggle: controller.toggleSoftSkill,
          ),
        ],
        const SizedBox(height: AppSpacing.md),
        ManualResumeTextField(
          label: 'Other skills (comma separated)',
          value: draft.skills.other.join(', '),
          onChanged: controller.setOtherSkillsText,
        ),
      ],
    );
  }

  void _addSkill(ManualResumeBuilderController controller, String groupKey) {
    final textController = _addControllerFor(groupKey);
    final error = controller.addCustomGroupSkill(groupKey, textController.text);
    setState(() => _addSkillError = error);
    if (error == null) textController.clear();
  }
}

extension _FirstOrNull<T> on Iterable<T> {
  T? get firstOrNull => isEmpty ? null : first;
}
